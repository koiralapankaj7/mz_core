import 'package:analyzer/src/lint/registry.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:mz_lints/src/rules/duplicate_listener.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(DuplicateListenerTest);
  });
}

@reflectiveTest
class DuplicateListenerTest extends AnalysisRuleTest {
  @override
  String get analysisRule => DuplicateListener.code.name;

  @override
  void setUp() {
    // Create Flutter stub package
    newPackage('flutter')
      ..addFile('lib/widgets.dart', r'''
export 'src/framework.dart';
''')
      ..addFile('lib/foundation.dart', r'''
export 'src/change_notifier.dart';
''')
      ..addFile('lib/src/framework.dart', r'''
abstract class Widget {}
abstract class StatefulWidget extends Widget {}
mixin class State<T extends StatefulWidget> {
  T get widget => throw UnimplementedError();
  void initState() {}
  void didChangeDependencies() {}
  void didUpdateWidget(T oldWidget) {}
  void dispose() {}
  Widget build(Object context) => throw UnimplementedError();
}
class BuildContext {}
class SizedBox extends Widget {
  const SizedBox();
}
''')
      ..addFile('lib/src/change_notifier.dart', r'''
class ChangeNotifier {
  void addListener(void Function() listener) {}
  void removeListener(void Function() listener) {}
  void dispose() {}
  void notifyListeners() {}
}
class TextEditingController extends ChangeNotifier {
  String text = '';
}
class ScrollController extends ChangeNotifier {}
class ValueNotifier<T> extends ChangeNotifier {
  ValueNotifier(this.value);
  T value;
}
class AnimationController extends ChangeNotifier {
  void addStatusListener(void Function() listener) {}
  void removeStatusListener(void Function() listener) {}
}
''');

    Registry.ruleRegistry.registerLintRule(DuplicateListener());
    super.setUp();
  }

  @override
  Future<void> tearDown() async {
    Registry.ruleRegistry.unregisterLintRule(DuplicateListener());
    await super.tearDown();
  }

  // Non-State class tests - should detect duplicates

  Future<void> test_non_state_class_detects_duplicate() async {
    await assertDiagnostics(
      r'''
class MyNotifier {
  void addListener(void Function() listener) {}
}

class MyClass {
  final _notifier = MyNotifier();

  void setup() {
    _notifier.addListener(_onChange);
    _notifier.addListener(_onChange);
  }

  void _onChange() {}
}
''',
      [lint(180, 32)],
    );
  }

  Future<void> test_non_state_class_single_add_no_lint() async {
    await assertNoDiagnostics(r'''
class MyNotifier {
  void addListener(void Function() listener) {}
}

class MyClass {
  final _notifier = MyNotifier();

  void setup() {
    _notifier.addListener(_onChange);
  }

  void _onChange() {}
}
''');
  }

  // Cross-method duplicate detection tests

  Future<void> test_duplicate_in_helper_method_called_from_initState() async {
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _doSomething();
  }

  void _doSomething() {
    _controller.addListener(_onChange);
  }

  void _onChange() {}
}
''',
      [lint(368, 34)],
    );
  }

  Future<void> test_duplicate_across_multiple_methods() async {
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
  }

  void someOtherMethod() {
    _controller.addListener(_onChange);
  }

  void _onChange() {}
}
''',
      [lint(351, 34)],
    );
  }

  Future<void> test_multiple_methods_with_remove_no_lint() async {
    // If there's a removeListener in a reachable method, a second add is allowed
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
  }

  void restart() {
    _controller.removeListener(_onChange);
    _controller.addListener(_onChange);
  }

  void _onChange() {}
}
''');
  }

  Future<void> test_unreachable_remove_method_still_flags_duplicate() async {
    // removeListener in a method that's never called shouldn't count
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _doSomething();
  }

  void _doSomething() {
    _controller.addListener(_onChange);
  }

  // This method is never called, so its removeListener doesn't count
  void _neverCalled() {
    _controller.removeListener(_onChange);
  }

  void _onChange() {}
}
''',
      [lint(368, 34)],
    );
  }

  Future<void> test_remove_called_after_duplicate_add_still_flags() async {
    // removeListener called AFTER the duplicate add doesn't help
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _add();
  }

  void _remove() {
    _controller.removeListener(_onChange);
  }

  void _add() {
    _controller.addListener(_onChange);
    _remove();
  }

  void _onChange() {}
}
''',
      [lint(419, 34)],
    );
  }

  Future<void> test_remove_called_before_duplicate_add_no_lint() async {
    // removeListener called BEFORE the duplicate add should pass
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _add();
  }

  void _remove() {
    _controller.removeListener(_onChange);
  }

  void _add() {
    _remove();
    _controller.addListener(_onChange);
  }

  void _onChange() {}
}
''');
  }

  Future<void>
  test_remove_in_separate_method_called_before_add_no_lint() async {
    // removeListener in a separate method called before add's method from
    // common ancestor (initState) should pass
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _remove();
    _add();
  }

  void _remove() {
    _controller.removeListener(_onChange);
  }

  void _add() {
    _controller.addListener(_onChange);
  }

  void _onChange() {}
}
''');
  }

  Future<void> test_remove_in_separate_method_called_after_add_flags() async {
    // removeListener in a separate method called AFTER add's method from
    // common ancestor should still flag the duplicate
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _add();
    _remove();
  }

  void _remove() {
    _controller.removeListener(_onChange);
  }

  void _add() {
    _controller.addListener(_onChange);
  }

  void _onChange() {}
}
''',
      [lint(434, 34)],
    );
  }

  // initState tests - duplicate addListener

  Future<void> test_single_addListener_no_lint() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
  }

  void _onChange() {}
}
''');
  }

  Future<void> test_duplicate_addListener_in_initState() async {
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _controller.addListener(_onChange);
  }

  void _onChange() {}
}
''',
      [lint(319, 34)],
    );
  }

  Future<void> test_duplicate_addStatusListener_in_initState() async {
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _animation = AnimationController();

  @override
  void initState() {
    super.initState();
    _animation.addStatusListener(_onStatus);
    _animation.addStatusListener(_onStatus);
  }

  void _onStatus() {}
}
''',
      [lint(321, 39)],
    );
  }

  Future<void> test_different_callbacks_no_lint() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange1);
    _controller.addListener(_onChange2);
  }

  void _onChange1() {}
  void _onChange2() {}
}
''');
  }

  Future<void> test_different_targets_no_lint() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller1 = TextEditingController();
  final _controller2 = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller1.addListener(_onChange);
    _controller2.addListener(_onChange);
  }

  void _onChange() {}
}
''');
  }

  // didUpdateWidget tests - duplicate addListener detection

  Future<void> test_addListener_in_didUpdateWidget_single_no_lint() async {
    // Single addListener is not a duplicate
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {
  final controller = TextEditingController();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  void didUpdateWidget(MyWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller.addListener(_onChange);
  }

  void _onChange() {}
}
''');
  }

  Future<void> test_addListener_in_didUpdateWidget_with_remove_before() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {
  final controller = TextEditingController();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  void didUpdateWidget(MyWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.controller.removeListener(_onChange);
    widget.controller.addListener(_onChange);
  }

  void _onChange() {}
}
''');
  }

  Future<void> test_addListener_in_didUpdateWidget_with_remove_no_lint() async {
    // With a remove, one add is valid
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {
  final controller = TextEditingController();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  void didUpdateWidget(MyWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    widget.controller.addListener(_onChange);
    oldWidget.controller.removeListener(_onChange);
  }

  void _onChange() {}
}
''');
  }

  Future<void> test_initState_and_didUpdateWidget_pattern_no_lint() async {
    // Common Flutter pattern: add in initState, remove/add in didUpdateWidget
    // oldWidget.X should be normalized to widget.X for matching
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {
  final controller = TextEditingController();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(MyWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.controller.removeListener(_onChange);
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {}
}
''');
  }

  // didChangeDependencies tests

  Future<void>
  test_addListener_in_didChangeDependencies_single_no_lint() async {
    // Single addListener is not a duplicate
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.addListener(_onChange);
  }

  void _onChange() {}
}
''');
  }

  Future<void> test_addListener_in_didChangeDependencies_with_remove() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.removeListener(_onChange);
    _controller.addListener(_onChange);
  }

  void _onChange() {}
}
''');
  }

  // Prefixed identifier removeListener test (for coverage)

  Future<void> test_prefixed_callback_with_remove_no_lint() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class Callbacks {
  static void onChange() {}
}

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.removeListener(Callbacks.onChange);
    _controller.addListener(Callbacks.onChange);
  }
}
''');
  }

  // ignore comment tests

  Future<void> test_ignore_for_file_suppresses_lint() async {
    await assertNoDiagnostics(r'''
// ignore_for_file: duplicate_listener
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _controller.addListener(_onChange);
  }

  void _onChange() {}
}
''');
  }

  Future<void> test_ignore_line_suppresses_lint() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    // ignore: duplicate_listener
    _controller.addListener(_onChange);
  }

  void _onChange() {}
}
''');
  }

  // State subclass test

  Future<void> test_state_subclass_detects_duplicate() async {
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

abstract class BaseState<T extends StatefulWidget> extends State<T> {}

class _MyWidgetState extends BaseState<MyWidget> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChange);
    _controller.addListener(_onChange);
  }

  void _onChange() {}
}
''',
      [lint(395, 34)],
    );
  }

  // Prefixed identifier callback test

  Future<void> test_prefixed_identifier_callback_duplicate() async {
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class Callbacks {
  static void onChange() {}
}

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(Callbacks.onChange);
    _controller.addListener(Callbacks.onChange);
  }
}
''',
      [lint(377, 43)],
    );
  }

  // Property access target test

  Future<void> test_property_access_target_duplicate() async {
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class Parent {
  final controller = TextEditingController();
}

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final parent = Parent();

  @override
  void initState() {
    super.initState();
    parent.controller.addListener(_onChange);
    parent.controller.addListener(_onChange);
  }

  void _onChange() {}
}
''',
      [lint(369, 40)],
    );
  }
}
