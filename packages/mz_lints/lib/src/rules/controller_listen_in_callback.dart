import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

import 'package:mz_lints/src/utils/ignore_info.dart';

/// A lint rule that warns when `Controller.ofType` or `Controller.maybeOfType`
/// is called from a callback without setting `listen: false`.
///
/// When accessing a controller from callbacks (onPressed, onTap, onChanged,
/// etc.), `listen` should be set to `false` to avoid unnecessary widget
/// rebuilds.
///
/// **BAD:**
/// ```dart
/// ElevatedButton(
///   onPressed: () {
///     final ctrl = Controller.ofType<MyController>(context); // LINT
///     ctrl.submit();
///   },
///   child: const Text('Submit'),
/// )
/// ```
///
/// **GOOD:**
/// ```dart
/// ElevatedButton(
///   onPressed: () {
///     final ctrl = Controller.ofType<MyController>(context, listen: false);
///     ctrl.submit();
///   },
///   child: const Text('Submit'),
/// )
/// ```
class ControllerListenInCallback extends AnalysisRule {
  /// The diagnostic code for this rule.
  static const LintCode code = LintCode(
    'controller_listen_in_callback',
    "Use 'listen: false' when accessing Controller from a callback.",
    correctionMessage:
        "Add 'listen: false' to avoid unnecessary widget rebuilds.",
    severity: DiagnosticSeverity.WARNING,
  );

  /// Creates a new instance of [ControllerListenInCallback].
  ControllerListenInCallback()
    : super(
        name: 'controller_listen_in_callback',
        description:
            'Controller.ofType and Controller.maybeOfType should use '
            'listen: false when called from callbacks to avoid unnecessary '
            'widget rebuilds.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    final visitor = _Visitor(this);
    registry.addMethodInvocation(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;

  _Visitor(this.rule);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    // Check if this is a call to Controller.ofType or Controller.maybeOfType
    final methodName = node.methodName.name;
    if (methodName != 'ofType' && methodName != 'maybeOfType') return;

    // Check if the target is 'Controller'
    final target = node.target;
    if (target is! SimpleIdentifier || target.name != 'Controller') return;

    // Check if listen: false is already set
    if (_hasListenFalse(node)) return;

    // Check if we're inside a non-Widget-returning function (i.e., a callback)
    if (!_isInsideCallback(node)) return;

    // Check ignore comments before reporting
    final unit = node.root as CompilationUnit;
    final ignoreInfo = IgnoreInfo.fromUnit(unit);
    final ruleName = ControllerListenInCallback.code.name;

    if (ignoreInfo.isIgnoredForFile(ruleName)) return;
    if (ignoreInfo.isIgnoredAtNode(ruleName, node.methodName, unit)) return;

    // Report the lint
    rule.reportAtNode(node.methodName);
  }

  /// Returns true if the method invocation has `listen: false` argument.
  bool _hasListenFalse(MethodInvocation node) {
    for (final arg in node.argumentList.arguments) {
      if (arg is NamedExpression &&
          arg.name.label.name == 'listen' &&
          arg.expression is BooleanLiteral) {
        final boolLiteral = arg.expression as BooleanLiteral;
        if (!boolLiteral.value) {
          return true; // listen: false is set
        }
      }
    }
    return false;
  }

  /// Returns true if the node is inside a callback context.
  ///
  /// A function is considered a callback if it does NOT return `Widget` or
  /// `List<Widget>`. This is a simple and robust heuristic - build methods
  /// return widgets, callbacks (onPressed, onTap, etc.) return void or
  /// other non-widget types.
  bool _isInsideCallback(AstNode node) {
    AstNode? current = node.parent;

    while (current != null) {
      // Check function expressions (lambdas/closures)
      if (current is FunctionExpression) {
        final returnType = _getFunctionExpressionReturnType(current);
        if (!_isWidgetType(returnType)) {
          return true;
        }
      }

      // Check method declarations
      if (current is MethodDeclaration) {
        final returnType = current.returnType;
        if (!_isWidgetType(returnType)) {
          return true;
        }
        // If it returns Widget, this is likely a build method - stop here
        return false;
      }

      // Check function declarations
      if (current is FunctionDeclaration) {
        final returnType = current.returnType;
        if (!_isWidgetType(returnType)) {
          return true;
        }
        return false;
      }

      current = current.parent;
    }

    return false;
  }

  /// Gets the return type annotation from a FunctionExpression if available.
  TypeAnnotation? _getFunctionExpressionReturnType(FunctionExpression expr) {
    // FunctionExpression doesn't directly have a return type,
    // but its parent might give us context
    final parent = expr.parent;

    // If it's a named expression argument, we can't easily get the type
    // But we know callbacks like onPressed, onTap return void
    if (parent is NamedExpression || parent is ArgumentList) {
      // Function expressions passed as arguments are callbacks
      return null; // null means non-Widget (callback)
    }

    // If it's part of a function declaration
    if (parent is FunctionDeclaration) {
      return parent.returnType;
    }

    return null;
  }

  /// Returns true if the type annotation represents `Widget` or `List<Widget>`.
  bool _isWidgetType(TypeAnnotation? type) {
    if (type == null) return false;

    if (type is NamedType) {
      final typeName = type.name.lexeme;
      if (typeName == 'Widget') return true;

      // Check for List<Widget>, Iterable<Widget>, etc.
      final typeArgs = type.typeArguments;
      if (typeArgs != null && typeArgs.arguments.isNotEmpty) {
        for (final arg in typeArgs.arguments) {
          if (arg is NamedType && arg.name.lexeme == 'Widget') {
            return true;
          }
        }
      }
    }

    return false;
  }
}
