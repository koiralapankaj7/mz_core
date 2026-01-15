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
/// Returns the string representation of the target expression, handling:
/// - [SimpleIdentifier]: `_controller` → `"_controller"`
/// - [PrefixedIdentifier]: `widget.controller` → `"widget.controller"`
/// - [PropertyAccess]: `a.b.c` → `"a.b.c"`
///
/// Returns `null` if the target cannot be converted to a string.
///
/// This is used internally by [RemoveListener] to match `addListener` calls
/// with their corresponding `removeListener` calls.
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

    // Single pass: collect all method info, listener operations, and method calls
    final methodBodies = <String, MethodDeclaration>{};
    final addListenersByMethod = <String, List<_ListenerInfo>>{};
    final removeListenersByMethod = <String, List<_ListenerInfo>>{};
    final methodCallsByMethod = <String, List<String>>{};
    final lifecycleMethodNames = <String>[];
    String? disposeMethodName;

    final collector = _CombinedListenerCollector(
      addListenersByMethod,
      removeListenersByMethod,
      methodCallsByMethod,
    );

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;
        methodBodies[methodName] = member;
        collector.currentMethod = methodName;
        member.accept(collector);

        if (methodName == 'initState' ||
            methodName == 'didChangeDependencies' ||
            methodName == 'didUpdateWidget') {
          lifecycleMethodNames.add(methodName);
        } else if (methodName == 'dispose') {
          disposeMethodName = methodName;
        }
      }
    }

    // Early exit: no lifecycle methods means nothing to check
    if (lifecycleMethodNames.isEmpty) return;

    // Collect addListener calls from lifecycle methods (including through helpers)
    final addedListeners = <_ListenerInfo>[];
    final visitedAdd = <String>{};
    for (final lifecycle in lifecycleMethodNames) {
      _collectListenersTransitively(
        lifecycle,
        addListenersByMethod,
        methodCallsByMethod,
        addedListeners,
        visitedAdd,
      );
    }

    // Early exit: no listeners added means nothing to check
    if (addedListeners.isEmpty) return;

    // Collect removeListener calls from dispose (including through helpers)
    final removedListeners = <_ListenerInfo>[];
    if (disposeMethodName != null) {
      _collectListenersTransitively(
        disposeMethodName,
        removeListenersByMethod,
        methodCallsByMethod,
        removedListeners,
        <String>{},
      );
    }

    // Find unremoved listeners
    final unremovedListeners = <_ListenerInfo>[];
    for (final added in addedListeners) {
      final isRemoved = removedListeners.any(
        (removed) =>
            removed.callbackName == added.callbackName &&
            _targetMatches(added.targetName, removed.targetName),
      );
      if (!isRemoved) {
        unremovedListeners.add(added);
      }
    }

    // Early exit: all listeners are properly removed
    if (unremovedListeners.isEmpty) return;

    // Get ignore info only if we need to report (lazy evaluation)
    final unit = node.root as CompilationUnit;
    final ignoreInfo = IgnoreInfo.fromUnit(unit);
    final ruleName = RemoveListener.code.name;

    // Check if this rule is ignored for the entire file
    if (ignoreInfo.isIgnoredForFile(ruleName)) return;

    // Report unremoved listeners
    for (final added in unremovedListeners) {
      if (!ignoreInfo.isIgnoredAtNode(ruleName, added.node, unit)) {
        rule.reportAtNode(added.node, arguments: [added.callbackName]);
      }
    }
  }

  /// Collects listeners from a method transitively through method calls.
  void _collectListenersTransitively(
    String methodName,
    Map<String, List<_ListenerInfo>> listenersByMethod,
    Map<String, List<String>> methodCallsByMethod,
    List<_ListenerInfo> result,
    Set<String> visited,
  ) {
    if (visited.contains(methodName)) return;
    visited.add(methodName);

    // Add direct listeners from this method
    final listeners = listenersByMethod[methodName];
    if (listeners != null) {
      result.addAll(listeners);
    }

    // Recursively check called methods
    final calls = methodCallsByMethod[methodName];
    if (calls != null) {
      for (final calledMethod in calls) {
        _collectListenersTransitively(
          calledMethod,
          listenersByMethod,
          methodCallsByMethod,
          result,
          visited,
        );
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

/// Combined visitor to collect add/remove listeners and method calls in one pass.
class _CombinedListenerCollector extends RecursiveAstVisitor<void> {
  final Map<String, List<_ListenerInfo>> addListenersByMethod;
  final Map<String, List<_ListenerInfo>> removeListenersByMethod;
  final Map<String, List<String>> methodCallsByMethod;
  String currentMethod = '';

  _CombinedListenerCollector(
    this.addListenersByMethod,
    this.removeListenersByMethod,
    this.methodCallsByMethod,
  );

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final methodName = node.methodName.name;
    final target = node.target;

    // Check for listener operations
    final isAdd =
        methodName == 'addListener' || methodName == 'addStatusListener';
    final isRemove =
        methodName == 'removeListener' || methodName == 'removeStatusListener';

    if (isAdd || isRemove) {
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
          final info = _ListenerInfo(
            targetName: getTargetName(target),
            callbackName: callbackName,
            node: node,
          );
          if (isAdd) {
            addListenersByMethod
                .putIfAbsent(currentMethod, () => <_ListenerInfo>[])
                .add(info);
          } else {
            removeListenersByMethod
                .putIfAbsent(currentMethod, () => <_ListenerInfo>[])
                .add(info);
          }
        }
      }
    }

    // Check for local method calls (no target or 'this' target)
    if (target == null || target is ThisExpression) {
      methodCallsByMethod
          .putIfAbsent(currentMethod, () => <String>[])
          .add(methodName);
    }

    super.visitMethodInvocation(node);
  }
}
