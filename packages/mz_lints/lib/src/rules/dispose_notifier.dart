import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:analyzer/error/error.dart';

import 'package:mz_lints/src/utils/ignore_info.dart';

/// A lint rule that ensures ChangeNotifier subclasses created in StatefulWidget
/// State classes are properly disposed when they are actually used.
///
/// This rule only warns when:
/// 1. A ChangeNotifier is created as a field in a State class
/// 2. The notifier is actually referenced/used in the class
/// 3. The notifier is NOT disposed in the dispose() method
///
/// If a notifier is created but never used, no warning is shown since unused
/// objects will be garbage collected anyway.
///
/// This rule detects any class that extends `ChangeNotifier`, including:
/// - `TextEditingController`
/// - `ScrollController`
/// - `AnimationController`
/// - `TabController`
/// - `PageController`
/// - `FocusNode`
/// - `ValueNotifier`
/// - Any custom `ChangeNotifier` subclass
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   final _controller = TextEditingController(); // LINT: used but not disposed
///
///   @override
///   Widget build(BuildContext context) => TextField(controller: _controller);
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   final _controller = TextEditingController();
///
///   @override
///   void dispose() {
///     _controller.dispose();
///     super.dispose();
///   }
///
///   @override
///   Widget build(BuildContext context) => TextField(controller: _controller);
/// }
/// ```
///
/// **OK (unused, no warning):**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   final _controller = TextEditingController(); // OK: unused, will be GC'd
///
///   @override
///   Widget build(BuildContext context) => const Text('Hello');
/// }
/// ```
class DisposeNotifier extends AnalysisRule {
  /// The diagnostic code for this rule.
  static const LintCode code = LintCode(
    'dispose_notifier',
    "ChangeNotifier '{0}' is created but never disposed.",
    correctionMessage: "Call '{0}.dispose()' in the State's dispose() method.",
    severity: DiagnosticSeverity.WARNING,
  );

  /// Creates a new instance of [DisposeNotifier].
  DisposeNotifier()
    : super(
        name: 'dispose_notifier',
        description:
            'ChangeNotifier subclasses created in StatefulWidget State '
            'classes must be disposed to prevent memory leaks.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this);
    registry.addClassDeclaration(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // Check if this class extends State<T>
    if (!_isStateClass(node)) return;

    // Get the compilation unit and ignore info
    final unit = node.root as CompilationUnit;
    final ignoreInfo = IgnoreInfo.fromUnit(unit);
    final ruleName = DisposeNotifier.code.name;

    // Check if this rule is ignored for the entire file
    if (ignoreInfo.isIgnoredForFile(ruleName)) return;

    // Find all notifier fields created in this class
    final notifierFields = <FieldDeclaration, List<VariableDeclaration>>{};

    for (final member in node.members) {
      if (member is FieldDeclaration) {
        final notifiers = <VariableDeclaration>[];
        for (final variable in member.fields.variables) {
          if (_isNotifierCreation(variable)) {
            notifiers.add(variable);
          }
        }
        if (notifiers.isNotEmpty) {
          notifierFields[member] = notifiers;
        }
      }
    }

    if (notifierFields.isEmpty) return;

    // Find the dispose method and check what's disposed
    final disposedNames = _getDisposedNames(node);

    // Find all referenced field names (excluding in dispose method)
    final referencedNames = _getReferencedNames(node);

    // Report any notifiers that are referenced but not disposed
    for (final entry in notifierFields.entries) {
      for (final variable in entry.value) {
        final name = variable.name.lexeme;
        // Only warn if the notifier is actually used somewhere
        if (referencedNames.contains(name) && !disposedNames.contains(name)) {
          // Check if this specific line is ignored
          if (!ignoreInfo.isIgnoredAtNode(ruleName, variable, unit)) {
            rule.reportAtNode(variable, arguments: [name]);
          }
        }
      }
    }
  }

  /// Returns true if this class extends `State<T>`.
  bool _isStateClass(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    final superclass = extendsClause?.superclass;
    final element = superclass?.element;
    // Check if it's State or extends State
    return element != null && _extendsState(element);
  }

  /// Recursively checks if the element extends Flutter's State class.
  bool _extendsState(Element element) {
    if (element is! InterfaceElement) return false;

    // Check the class name and library
    if (element.name == 'State') {
      final library = element.library;
      final libraryName = library.name;
      if (libraryName != null && libraryName.startsWith('flutter.')) {
        return true;
      }
      // Also check the library identifier
      final libraryId = library.identifier;
      if (libraryId.contains('flutter')) {
        return true;
      }
    }

    // Check superclass
    final supertype = element.supertype;
    if (supertype != null) {
      final superElement = supertype.element;
      if (_extendsState(superElement)) return true;
    }

    return false;
  }

  /// Checks if the variable is initialized with a ChangeNotifier creation.
  bool _isNotifierCreation(VariableDeclaration variable) {
    final initializer = variable.initializer;
    if (initializer == null) return false;

    // Check for constructor invocation
    DartType? type;
    if (initializer is InstanceCreationExpression) {
      type = initializer.staticType;
    } else if (initializer is MethodInvocation) {
      // Handle factory methods
      type = initializer.staticType;
    }
    return type != null && _isChangeNotifierType(type);
  }

  /// Checks if the type extends ChangeNotifier.
  ///
  /// This covers all Flutter controllers and notifiers since they all
  /// extend ChangeNotifier (TextEditingController, ValueNotifier, etc.).
  bool _isChangeNotifierType(DartType type) {
    if (type is! InterfaceType) return false;
    return _extendsChangeNotifier(type.element);
  }

  /// Recursively checks if the element extends ChangeNotifier.
  bool _extendsChangeNotifier(InterfaceElement element) {
    final name = element.name;

    // Check if this is ChangeNotifier itself
    if (name == 'ChangeNotifier') {
      final library = element.library;
      final libraryId = library.identifier;
      if (libraryId.contains('flutter') || libraryId.contains('foundation')) {
        return true;
      }
    }

    // Check superclass
    final supertype = element.supertype;
    if (supertype != null) {
      if (_extendsChangeNotifier(supertype.element)) return true;
    }

    // Check mixins (ChangeNotifier is often used as a mixin)
    for (final mixin in element.mixins) {
      if (_extendsChangeNotifier(mixin.element)) return true;
    }

    // Check interfaces
    for (final interface in element.interfaces) {
      if (_extendsChangeNotifier(interface.element)) return true;
    }

    return false;
  }

  /// Gets the names of notifiers that are disposed in the dispose method.
  Set<String> _getDisposedNames(ClassDeclaration node) {
    final disposed = <String>{};

    for (final member in node.members) {
      if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
        final body = member.body;
        if (body is BlockFunctionBody) {
          body.block.accept(_DisposeVisitor(disposed));
        }
      }
    }

    return disposed;
  }

  /// Gets names of fields that are referenced in methods (excluding dispose).
  Set<String> _getReferencedNames(ClassDeclaration node) {
    final referenced = <String>{};

    for (final member in node.members) {
      // Skip the dispose method - we handle that separately
      if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
        continue;
      }

      // Check method bodies
      if (member is MethodDeclaration) {
        member.body.accept(_ReferenceVisitor(referenced));
      }

      // Check constructor initializers
      if (member is ConstructorDeclaration) {
        for (final initializer in member.initializers) {
          initializer.accept(_ReferenceVisitor(referenced));
        }
        member.body.accept(_ReferenceVisitor(referenced));
      }
    }

    return referenced;
  }
}

/// Visitor to find dispose() calls in a method body.
class _DisposeVisitor extends RecursiveAstVisitor<void> {
  final Set<String> disposedNames;

  _DisposeVisitor(this.disposedNames);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (node.methodName.name == 'dispose') {
      final target = node.target;
      if (target is SimpleIdentifier) {
        disposedNames.add(target.name);
      } else if (target is PrefixedIdentifier) {
        disposedNames.add(target.identifier.name);
      } else if (target is PropertyAccess) {
        // Handle this._controller.dispose()
        disposedNames.add(target.propertyName.name);
      }
    }
    super.visitMethodInvocation(node);
  }
}

/// Visitor to find identifier references in a method body.
class _ReferenceVisitor extends RecursiveAstVisitor<void> {
  final Set<String> referencedNames;

  _ReferenceVisitor(this.referencedNames);

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    referencedNames.add(node.name);
    super.visitSimpleIdentifier(node);
  }
}
