import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:mz_lints/src/rules/remove_listener.dart';
import 'package:test/test.dart';

void main() {
  group('getTargetName', () {
    test('returns null for null target', () {
      expect(getTargetName(null), isNull);
    });

    test('returns name for SimpleIdentifier', () {
      final expr = _parseExpression('_controller.addListener(_onChange)');
      final invocation = expr as MethodInvocation;
      expect(getTargetName(invocation.target), equals('_controller'));
    });

    test('returns prefixed name for PrefixedIdentifier', () {
      final expr = _parseExpression('widget.controller.addListener(_onChange)');
      final invocation = expr as MethodInvocation;
      // widget.controller is a PrefixedIdentifier
      expect(getTargetName(invocation.target), equals('widget.controller'));
    });

    test('returns chained name for PropertyAccess', () {
      final expr = _parseExpression(
        'parent.child.controller.addListener(_onChange)',
      );
      final invocation = expr as MethodInvocation;
      // parent.child.controller is a PropertyAccess chain
      expect(
        getTargetName(invocation.target),
        equals('parent.child.controller'),
      );
    });

    test('returns property name when PropertyAccess has null target', () {
      // This tests the fallback case in PropertyAccess handling
      // when target.target returns null from getTargetName
      final expr = _parseExpression('(getHolder()).controller.dispose()');
      final invocation = expr as MethodInvocation;
      // (getHolder()).controller is a PropertyAccess where target is
      // a ParenthesizedExpression (not handled by getTargetName)
      expect(getTargetName(invocation.target), equals('controller'));
    });

    test('returns null for unhandled expression types', () {
      final expr = _parseExpression('getController().dispose()');
      final invocation = expr as MethodInvocation;
      // getController() is a MethodInvocation, not handled
      expect(getTargetName(invocation.target), isNull);
    });
  });
}

/// Parses a Dart expression and returns the AST node.
Expression _parseExpression(String code) {
  final result = parseString(
    content:
        '''
void main() {
  $code;
}
''',
  );
  final unit = result.unit;
  final function = unit.declarations.first as FunctionDeclaration;
  final body = function.functionExpression.body as BlockFunctionBody;
  final statement = body.block.statements.first as ExpressionStatement;
  return statement.expression;
}
