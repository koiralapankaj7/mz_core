import 'package:analyzer/src/lint/registry.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:mz_lints/src/rules/controller_listen_in_callback.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(ControllerListenInCallbackTest);
  });
}

@reflectiveTest
class ControllerListenInCallbackTest extends AnalysisRuleTest {
  @override
  String get analysisRule => ControllerListenInCallback.code.name;

  @override
  void setUp() {
    Registry.ruleRegistry.registerLintRule(ControllerListenInCallback());
    super.setUp();
  }

  @override
  Future<void> tearDown() async {
    Registry.ruleRegistry.unregisterLintRule(ControllerListenInCallback());
    await super.tearDown();
  }

  Future<void> test_ofType_inEventHandlerMethod_reportsLint() async {
    await assertDiagnostics(
      r'''
class Controller {
  static T ofType<T>(Object context, {bool listen = true}) => throw '';
}

class MyWidget {
  void _onButtonPressed(Object context) {
    final ctrl = Controller.ofType<Controller>(context);
  }
}
''',
      [lint(181, 6)],
    );
  }

  Future<void> test_ofType_inHandleMethod_reportsLint() async {
    await assertDiagnostics(
      r'''
class Controller {
  static T ofType<T>(Object context, {bool listen = true}) => throw '';
}

class MyWidget {
  void handleSubmit(Object context) {
    final ctrl = Controller.ofType<Controller>(context);
  }
}
''',
      [lint(177, 6)],
    );
  }

  Future<void> test_ofType_inEventHandler_withListenFalse_noLint() async {
    await assertNoDiagnostics(r'''
class Controller {
  static T ofType<T>(Object context, {bool listen = true}) => throw '';
}

class MyWidget {
  void _onButtonPressed(Object context) {
    final ctrl = Controller.ofType<Controller>(context, listen: false);
  }
}
''');
  }

  Future<void> test_maybeOfType_inHandleMethod_reportsLint() async {
    await assertDiagnostics(
      r'''
class Controller {
  static T? maybeOfType<T>(Object context, {bool listen = true}) => null;
}

class MyWidget {
  void handleTap(Object context) {
    final ctrl = Controller.maybeOfType<Controller>(context);
  }
}
''',
      [lint(176, 11)],
    );
  }

  Future<void> test_ofType_inWidgetReturningMethod_noLint() async {
    await assertNoDiagnostics(r'''
class Controller {
  static T ofType<T>(Object context, {bool listen = true}) => throw '';
}

class Widget {}

class MyWidget {
  Widget build(Object context) {
    final ctrl = Controller.ofType<Controller>(context);
    return Widget();
  }
}
''');
  }

  Future<void> test_ofType_inVoidMethod_reportsLint() async {
    await assertDiagnostics(
      r'''
class Controller {
  static T ofType<T>(Object context, {bool listen = true}) => throw '';
}

class MyWidget {
  void regularMethod(Object context) {
    final ctrl = Controller.ofType<Controller>(context);
  }
}
''',
      [lint(178, 6)],
    );
  }

  Future<void> test_ofType_withListenTrue_inCallback_reportsLint() async {
    await assertDiagnostics(
      r'''
class Controller {
  static T ofType<T>(Object context, {bool listen = true}) => throw '';
}

class MyWidget {
  void _onSubmit(Object context) {
    final ctrl = Controller.ofType<Controller>(context, listen: true);
  }
}
''',
      [lint(174, 6)],
    );
  }

  Future<void> test_unrelatedMethodCall_noLint() async {
    await assertNoDiagnostics(r'''
class SomeClass {
  static void ofType() {}
}

class MyWidget {
  void _onPressed(Object context) {
    SomeClass.ofType();
  }
}
''');
  }

  Future<void> test_ofType_inOnPressedNamedArg_reportsLint() async {
    await assertDiagnostics(
      r'''
class Controller {
  static T ofType<T>(Object context, {bool listen = true}) => throw '';
}

void callWith({required void Function() onPressed}) {
  onPressed();
}

void myWidget(Object context) {
  callWith(
    onPressed: () {
      final ctrl = Controller.ofType<Controller>(context);
    },
  );
}
''',
      [lint(260, 6)],
    );
  }

  Future<void>
  test_ofType_inFunctionDeclaration_returningWidget_noLint() async {
    await assertNoDiagnostics(r'''
class Controller {
  static T ofType<T>(Object context, {bool listen = true}) => throw '';
}

class Widget {}

Widget buildWidget(Object context) {
  final ctrl = Controller.ofType<Controller>(context);
  return Widget();
}
''');
  }

  Future<void>
  test_ofType_inFunctionDeclaration_returningVoid_reportsLint() async {
    await assertDiagnostics(
      r'''
class Controller {
  static T ofType<T>(Object context, {bool listen = true}) => throw '';
}

void doSomething(Object context) {
  final ctrl = Controller.ofType<Controller>(context);
}
''',
      [lint(155, 6)],
    );
  }

  Future<void> test_ofType_inMethodReturningListWidget_noLint() async {
    await assertNoDiagnostics(r'''
class Controller {
  static T ofType<T>(Object context, {bool listen = true}) => throw '';
}

class Widget {}

class MyWidget {
  List<Widget> buildChildren(Object context) {
    final ctrl = Controller.ofType<Controller>(context);
    return <Widget>[];
  }
}
''');
  }

  Future<void> test_ofType_inMethodReturningIterableWidget_noLint() async {
    await assertNoDiagnostics(r'''
class Controller {
  static T ofType<T>(Object context, {bool listen = true}) => throw '';
}

class Widget {}

class MyWidget {
  Iterable<Widget> buildWidgets(Object context) {
    final ctrl = Controller.ofType<Controller>(context);
    return <Widget>[];
  }
}
''');
  }

  Future<void> test_ofType_inArgumentListExpression_reportsLint() async {
    await assertDiagnostics(
      r'''
class Controller {
  static T ofType<T>(Object context, {bool listen = true}) => throw '';
}

void runCallback(void Function() callback) {
  callback();
}

void myWidget(Object context) {
  runCallback(() {
    final ctrl = Controller.ofType<Controller>(context);
  });
}
''',
      [lint(235, 6)],
    );
  }

  Future<void> test_nonControllerClass_ofType_noLint() async {
    await assertNoDiagnostics(r'''
class SomeOtherClass {
  static T ofType<T>(Object context, {bool listen = true}) => throw '';
}

void _onPressed(Object context) {
  final ctrl = SomeOtherClass.ofType<SomeOtherClass>(context);
}
''');
  }

  Future<void> test_instanceMethodCall_noLint() async {
    await assertNoDiagnostics(r'''
class Controller {
  T ofType<T>(Object context, {bool listen = true}) => throw '';
}

void _onPressed(Object context) {
  final c = Controller();
  c.ofType<Controller>(context);
}
''');
  }

  Future<void> test_ignore_for_file_suppresses_lint() async {
    await assertNoDiagnostics(r'''
// ignore_for_file: controller_listen_in_callback
class Controller {
  static T ofType<T>(Object context, {bool listen = true}) => throw '';
}

class MyWidget {
  void _onButtonPressed(Object context) {
    final ctrl = Controller.ofType<Controller>(context);
  }
}
''');
  }

  Future<void> test_ignore_line_suppresses_lint() async {
    await assertNoDiagnostics(r'''
class Controller {
  static T ofType<T>(Object context, {bool listen = true}) => throw '';
}

class MyWidget {
  void _onButtonPressed(Object context) {
    // ignore: controller_listen_in_callback
    final ctrl = Controller.ofType<Controller>(context);
  }
}
''');
  }

  Future<void> test_ignore_different_rule_does_not_suppress() async {
    await assertDiagnostics(
      r'''
// ignore_for_file: dispose_notifier
class Controller {
  static T ofType<T>(Object context, {bool listen = true}) => throw '';
}

class MyWidget {
  void _onButtonPressed(Object context) {
    final ctrl = Controller.ofType<Controller>(context);
  }
}
''',
      [lint(218, 6)],
    );
  }
}
