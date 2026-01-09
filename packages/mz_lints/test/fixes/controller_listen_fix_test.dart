import 'package:analyzer/src/lint/registry.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:mz_lints/src/rules/controller_listen_in_callback.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(AddListenFalseTest);
  });
}

@reflectiveTest
class AddListenFalseTest extends AnalysisRuleTest {
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

  Future<void> test_diagnostic_exists_for_fix_target() async {
    // Verify the diagnostic exists that the fix would target
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

  Future<void> test_maybeOfType_diagnostic_exists() async {
    await assertDiagnostics(
      r'''
class Controller {
  static T? maybeOfType<T>(Object context, {bool listen = true}) => null;
}

class MyWidget {
  void _onTap(Object context) {
    final ctrl = Controller.maybeOfType<Controller>(context);
  }
}
''',
      [lint(173, 11)],
    );
  }

  Future<void> test_listen_true_diagnostic_exists() async {
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
}
