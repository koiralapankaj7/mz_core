import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/error/error.dart';

import 'package:mz_lints/src/utils/ignore_info.dart';

/// Extracts the target name from an expression for listener matching.
///
/// Returns the string representation of the target, handling:
/// - SimpleIdentifier: `_controller` -> `_controller`
/// - PrefixedIdentifier: `widget.controller` -> `widget.controller`
/// - PropertyAccess: `a.b.c` -> `a.b.c`
String? getTargetName(Expression? target) {
  if (target == null) return null;
  if (target is SimpleIdentifier) return target.name;
  if (target is PrefixedIdentifier) {
    return '${target.prefix.name}.${target.identifier.name}';
  }
  if (target is PropertyAccess) {
    final targetStr = getTargetName(target.target);
    if (targetStr != null) {
      return '$targetStr.${target.propertyName.name}';
    }
    return target.propertyName.name;
  }
  return null;
}

/// A lint rule that ensures listeners added to Listenables are properly removed.
///
/// This rule detects `addListener` and `addStatusListener` calls on any
/// `Listenable` implementation (ChangeNotifier, Animation, ValueNotifier, etc.)
/// and verifies they have matching `removeListener`/`removeStatusListener`
/// calls in the dispose method.
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   @override
///   void initState() {
///     super.initState();
///     widget.controller.addListener(_onChanged); // LINT: never removed
///   }
///
///   void _onChanged() {}
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   @override
///   void initState() {
///     super.initState();
///     widget.controller.addListener(_onChanged);
///   }
///
///   @override
///   void dispose() {
///     widget.controller.removeListener(_onChanged);
///     super.dispose();
///   }
///
///   void _onChanged() {}
/// }
/// ```
class RemoveListener extends AnalysisRule {
  /// The diagnostic code for this rule.
  static const LintCode code = LintCode(
    'remove_listener',
    "Listener '{0}' is added but never removed.",
    correctionMessage:
        "Call 'removeListener({0})' in the dispose() method to prevent memory "
        'leaks.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Creates a new instance of [RemoveListener].
  RemoveListener()
    : super(
        name: 'remove_listener',
        description:
            'Listeners added to Listenables must be removed to prevent '
            'memory leaks.',
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
    final ruleName = RemoveListener.code.name;

    // Check if this rule is ignored for the entire file
    if (ignoreInfo.isIgnoredForFile(ruleName)) return;

    // Find all addListener calls
    final addedListeners = <_ListenerInfo>[];
    final removedListeners = <_ListenerInfo>[];

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;

        if (methodName == 'initState' ||
            methodName == 'didChangeDependencies' ||
            methodName == 'didUpdateWidget') {
          // Look for addListener calls
          member.accept(_AddListenerVisitor(addedListeners));
        } else if (methodName == 'dispose') {
          // Look for removeListener calls
          member.accept(_RemoveListenerVisitor(removedListeners));
        }
      }
    }

    // Report listeners that are added but not removed
    for (final added in addedListeners) {
      final isRemoved = removedListeners.any(
        (removed) =>
            removed.callbackName == added.callbackName &&
            _targetMatches(added.targetName, removed.targetName),
      );

      if (!isRemoved) {
        // Check if this specific line is ignored
        if (!ignoreInfo.isIgnoredAtNode(ruleName, added.node, unit)) {
          rule.reportAtNode(added.node, arguments: [added.callbackName]);
        }
      }
    }
  }

  /// Checks if two target names match (accounting for widget.x vs x patterns).
  bool _targetMatches(String? added, String? removed) {
    // Both null means both are calling on self - matches
    if (added == null && removed == null) {
      return true;
    }
    // One null, one not - doesn't match
    if (added == null || removed == null) {
      return false;
    }
    // Exact match
    if (added == removed) {
      return true;
    }
    // Handle widget.controller vs controller patterns
    final addedParts = added.split('.');
    final removedParts = removed.split('.');

    // Compare the last meaningful part (the actual controller name)
    return addedParts.last == removedParts.last;
  }

  /// Returns true if this class extends `State<T>`.
  bool _isStateClass(ClassDeclaration node) {
    final extendsClause = node.extendsClause;
    if (extendsClause == null) return false;

    final superclass = extendsClause.superclass;
    final element = superclass.element;
    return element != null && _extendsState(element);
  }

  /// Recursively checks if the element extends Flutter's State class.
  bool _extendsState(Element element) {
    if (element is! InterfaceElement) return false;

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

    final supertype = element.supertype;
    if (supertype != null) {
      if (_extendsState(supertype.element)) return true;
    }

    return false;
  }
}

/// Information about a listener call.
class _ListenerInfo {
  final String? targetName;
  final String callbackName;
  final AstNode node;

  _ListenerInfo({
    required this.targetName,
    required this.callbackName,
    required this.node,
  });
}

/// Visitor to find addListener calls.
class _AddListenerVisitor extends RecursiveAstVisitor<void> {
  final List<_ListenerInfo> listeners;

  _AddListenerVisitor(this.listeners);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;

    if (methodName == 'addListener' || methodName == 'addStatusListener') {
      final args = node.argumentList.arguments;
      if (args.isNotEmpty) {
        final callback = args.first;
        String? callbackName;

        if (callback is SimpleIdentifier) {
          callbackName = callback.name;
        } else if (callback is PrefixedIdentifier) {
          callbackName = callback.identifier.name;
        }

        if (callbackName != null) {
          listeners.add(
            _ListenerInfo(
              targetName: getTargetName(node.target),
              callbackName: callbackName,
              node: node,
            ),
          );
        }
      }
    }

    super.visitMethodInvocation(node);
  }
}

/// Visitor to find removeListener calls.
class _RemoveListenerVisitor extends RecursiveAstVisitor<void> {
  final List<_ListenerInfo> listeners;

  _RemoveListenerVisitor(this.listeners);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;

    if (methodName == 'removeListener' ||
        methodName == 'removeStatusListener') {
      final args = node.argumentList.arguments;
      if (args.isNotEmpty) {
        final callback = args.first;
        String? callbackName;

        if (callback is SimpleIdentifier) {
          callbackName = callback.name;
        } else if (callback is PrefixedIdentifier) {
          callbackName = callback.identifier.name;
        }

        if (callbackName != null) {
          listeners.add(
            _ListenerInfo(
              targetName: getTargetName(node.target),
              callbackName: callbackName,
              node: node,
            ),
          );
        }
      }
    }

    super.visitMethodInvocation(node);
  }
}
