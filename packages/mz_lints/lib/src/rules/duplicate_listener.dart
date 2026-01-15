import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'package:mz_lints/src/rules/remove_listener.dart';
import 'package:mz_lints/src/utils/ignore_info.dart';

/// A lint rule that warns when the same listener is added multiple times
/// without removing the previous one first.
///
/// This rule uses a counter-based approach to simulate execution:
/// - Each `addListener` increments the count for that (target, callback) pair
/// - Each `removeListener` decrements the count
/// - If count is already 1+ when adding, it's a duplicate (LINT)
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   @override
///   void initState() {
///     super.initState();
///     _controller.addListener(_onChanged);
///     _controller.addListener(_onChanged); // LINT: count would be 2
///   }
/// }
/// ```
///
/// **BAD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   @override
///   void initState() {
///     super.initState();
///     _controller.addListener(_onChanged);
///     _doSomething();
///   }
///
///   void _doSomething() {
///     _controller.addListener(_onChanged); // LINT: count would be 2
///   }
/// }
/// ```
///
/// **GOOD:**
/// ```dart
/// class _MyWidgetState extends State<MyWidget> {
///   @override
///   void initState() {
///     super.initState();
///     _controller.addListener(_onChanged);
///     _remove();
///     _add();
///   }
///
///   void _remove() {
///     _controller.removeListener(_onChanged); // count becomes 0
///   }
///
///   void _add() {
///     _controller.addListener(_onChanged); // OK: count was 0, now 1
///   }
/// }
/// ```
class DuplicateListener extends AnalysisRule {
  /// The diagnostic code for this rule.
  static const LintCode code = LintCode(
    'duplicate_listener',
    "Listener '{0}' may be added multiple times without removal.",
    correctionMessage:
        "Call 'removeListener({0})' before adding the listener again, or "
        'ensure the listener is only added once.',
    severity: DiagnosticSeverity.WARNING,
  );

  /// Creates a new instance of [DuplicateListener].
  DuplicateListener()
    : super(
        name: 'duplicate_listener',
        description:
            'Listeners should not be added multiple times without removing '
            'the previous listener first.',
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

  /// Lifecycle methods in execution order for State classes.
  static const _lifecycleOrder = [
    'initState',
    'didChangeDependencies',
    'didUpdateWidget',
  ];

  _Visitor(this.rule);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    // Collect all listener operations and method calls in a single pass
    final operationsByMethod = <String, List<_ListenerOperation>>{};
    final methodCalls = <String, List<_MethodCallInfo>>{};
    final methodBodies = <String, MethodDeclaration>{};
    final collector = _CombinedCollector(operationsByMethod, methodCalls);

    for (final member in node.members) {
      if (member is MethodDeclaration) {
        final methodName = member.name.lexeme;
        methodBodies[methodName] = member;

        // Don't collect operations from dispose (it's for cleanup)
        if (methodName != 'dispose') {
          collector.currentMethod = methodName;
          member.accept(collector);
        }
      }
    }

    // Early exit: no listener operations means no duplicates possible
    if (operationsByMethod.isEmpty) return;

    // Flatten operations for counting
    final allOperations = operationsByMethod.values
        .expand((ops) => ops)
        .toList();

    // Early exit: count adds per (target, callback) - if max is 1, no duplicates
    final addCounts = <String, int>{};
    for (final op in allOperations) {
      if (op.isAdd) {
        final key = _normalizeKey(op.targetName, op.callbackName);
        addCounts[key] = (addCounts[key] ?? 0) + 1;
      }
    }
    if (addCounts.values.every((count) => count <= 1)) return;

    // Get ignore info only if we need to report (lazy evaluation)
    final unit = node.root as CompilationUnit;
    final ignoreInfo = IgnoreInfo.fromUnit(unit);
    final ruleName = DuplicateListener.code.name;

    // Check if this rule is ignored for the entire file
    if (ignoreInfo.isIgnoredForFile(ruleName)) return;

    // Build reverse call graph (who calls whom)
    final calledBy = <String, Set<String>>{};
    for (final entry in methodCalls.entries) {
      for (final call in entry.value) {
        calledBy.putIfAbsent(call.callee, () => <String>{}).add(entry.key);
      }
    }

    // Find lifecycle entry points that exist in this class
    final entryPoints = <String>[];
    for (final lifecycle in _lifecycleOrder) {
      if (methodBodies.containsKey(lifecycle)) {
        entryPoints.add(lifecycle);
      }
    }

    // For State classes: also add methods with operations that aren't called
    // by other methods (they could be called from build callbacks)
    // But skip private methods not called from anywhere (likely dead code)
    if (entryPoints.isNotEmpty) {
      // Find methods reachable from lifecycle methods
      final reachable = <String>{};
      for (final entry in entryPoints) {
        _collectReachableMethods(entry, methodCalls, reachable);
      }

      // Add non-reachable methods with operations only if they COULD be called
      for (final op in allOperations) {
        final methodName = op.methodName;
        if (!reachable.contains(methodName) &&
            !entryPoints.contains(methodName)) {
          // Skip private methods not called from anywhere (dead code)
          final isPrivate = methodName.startsWith('_');
          final isCalledAnywhere =
              calledBy.containsKey(methodName) &&
              calledBy[methodName]!.isNotEmpty;

          if (isPrivate && !isCalledAnywhere) {
            // Dead code - skip
            continue;
          }

          // Public method or called from somewhere - could be entry point
          entryPoints.add(methodName);
        }
      }
    } else {
      // No lifecycle methods - find methods that aren't called by others
      for (final op in allOperations) {
        final methodName = op.methodName;
        if (!calledBy.containsKey(methodName) ||
            calledBy[methodName]!.isEmpty) {
          if (!entryPoints.contains(methodName)) {
            entryPoints.add(methodName);
          }
        }
      }
    }

    // Simulate execution from entry points
    final duplicates = <_ListenerOperation>{};
    final counts = <String, int>{};

    // Pre-compute sorted events per method to avoid repeated sorting
    final eventsByMethod = <String, List<_ExecutionEvent>>{};
    for (final methodName in operationsByMethod.keys) {
      final events = <_ExecutionEvent>[];
      final ops = operationsByMethod[methodName] ?? const [];
      final calls = methodCalls[methodName] ?? const [];
      for (final op in ops) {
        events.add(_ExecutionEvent(op.offset, operation: op));
      }
      for (final call in calls) {
        events.add(_ExecutionEvent(call.offset, methodCall: call));
      }
      if (events.length > 1) {
        events.sort((a, b) => a.offset.compareTo(b.offset));
      }
      eventsByMethod[methodName] = events;
    }
    // Also add methods that have calls but no operations
    for (final methodName in methodCalls.keys) {
      if (!eventsByMethod.containsKey(methodName)) {
        final calls = methodCalls[methodName]!;
        final events = calls
            .map((c) => _ExecutionEvent(c.offset, methodCall: c))
            .toList();
        if (events.length > 1) {
          events.sort((a, b) => a.offset.compareTo(b.offset));
        }
        eventsByMethod[methodName] = events;
      }
    }

    for (final entryPoint in entryPoints) {
      final visited = <String>{};
      _simulateExecution(
        entryPoint,
        eventsByMethod,
        counts,
        visited,
        duplicates,
      );
    }

    // Report duplicates
    for (final op in duplicates) {
      if (!ignoreInfo.isIgnoredAtNode(ruleName, op.node, unit)) {
        rule.reportAtNode(op.node, arguments: [op.callbackName]);
      }
    }
  }

  /// Simulates execution of a method and tracks listener counts.
  void _simulateExecution(
    String methodName,
    Map<String, List<_ExecutionEvent>> eventsByMethod,
    Map<String, int> counts,
    Set<String> visited,
    Set<_ListenerOperation> duplicates,
  ) {
    // Prevent infinite recursion
    if (visited.contains(methodName)) return;
    visited.add(methodName);

    // Get pre-sorted events for this method
    final events = eventsByMethod[methodName];
    if (events == null || events.isEmpty) {
      visited.remove(methodName);
      return;
    }

    // Process events in order
    for (final event in events) {
      if (event.operation != null) {
        final op = event.operation!;
        final key = _normalizeKey(op.targetName, op.callbackName);

        if (op.isAdd) {
          final currentCount = counts[key] ?? 0;
          if (currentCount > 0) {
            // Duplicate! Count is already 1+
            duplicates.add(op);
          }
          counts[key] = currentCount + 1;
        } else {
          // Remove
          final currentCount = counts[key] ?? 0;
          if (currentCount > 0) {
            counts[key] = currentCount - 1;
          }
        }
      } else if (event.methodCall != null) {
        // Recurse into called method
        _simulateExecution(
          event.methodCall!.callee,
          eventsByMethod,
          counts,
          visited,
          duplicates,
        );
      }
    }

    // Allow re-entry for different call paths
    visited.remove(methodName);
  }

  /// Creates a normalized key for grouping listeners.
  String _normalizeKey(String? targetName, String callbackName) {
    var normalizedTarget = targetName ?? '';

    // Normalize oldWidget.X to widget.X for matching
    if (normalizedTarget.startsWith('oldWidget.')) {
      normalizedTarget = 'widget.${normalizedTarget.substring(10)}';
    }

    return '$normalizedTarget.$callbackName';
  }

  /// Collects all methods reachable from the given method (transitively).
  void _collectReachableMethods(
    String methodName,
    Map<String, List<_MethodCallInfo>> methodCalls,
    Set<String> reachable,
  ) {
    if (reachable.contains(methodName)) return;
    reachable.add(methodName);

    final calls = methodCalls[methodName] ?? [];
    for (final call in calls) {
      _collectReachableMethods(call.callee, methodCalls, reachable);
    }
  }
}

/// Represents an add or remove listener operation.
class _ListenerOperation {
  final String? targetName;
  final String callbackName;
  final String methodName;
  final int offset;
  final AstNode node;
  final bool isAdd;

  _ListenerOperation({
    required this.targetName,
    required this.callbackName,
    required this.methodName,
    required this.offset,
    required this.node,
    required this.isAdd,
  });
}

/// An event during execution simulation.
class _ExecutionEvent {
  final int offset;
  final _ListenerOperation? operation;
  final _MethodCallInfo? methodCall;

  _ExecutionEvent(this.offset, {this.operation, this.methodCall});
}

/// Information about a method call.
class _MethodCallInfo {
  final String callee;
  final int offset;

  _MethodCallInfo(this.callee, this.offset);
}

/// Combined visitor to collect both listener operations and method calls in one pass.
class _CombinedCollector extends RecursiveAstVisitor<void> {
  final Map<String, List<_ListenerOperation>> operationsByMethod;
  final Map<String, List<_MethodCallInfo>> methodCalls;
  String currentMethod = '';

  _CombinedCollector(this.operationsByMethod, this.methodCalls);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final invocationName = node.methodName.name;
    final target = node.target;

    // Check for listener operations
    final isAdd =
        invocationName == 'addListener' ||
        invocationName == 'addStatusListener';
    final isRemove =
        invocationName == 'removeListener' ||
        invocationName == 'removeStatusListener';

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
          operationsByMethod
              .putIfAbsent(currentMethod, () => <_ListenerOperation>[])
              .add(
                _ListenerOperation(
                  targetName: getTargetName(target),
                  callbackName: callbackName,
                  methodName: currentMethod,
                  offset: node.offset,
                  node: node,
                  isAdd: isAdd,
                ),
              );
        }
      }
    }

    // Check for local method calls (no target or 'this' target)
    if (target == null || target is ThisExpression) {
      methodCalls
          .putIfAbsent(currentMethod, () => <_MethodCallInfo>[])
          .add(_MethodCallInfo(invocationName, node.offset));
    }

    super.visitMethodInvocation(node);
  }
}
