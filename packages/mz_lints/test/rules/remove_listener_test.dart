import 'package:analyzer/src/lint/registry.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:mz_lints/src/rules/remove_listener.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(RemoveListenerTest);
  });
}

@reflectiveTest
class RemoveListenerTest extends AnalysisRuleTest {
  @override
  String get analysisRule => RemoveListener.code.name;

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

    Registry.ruleRegistry.registerLintRule(RemoveListener());
    super.setUp();
  }

  @override
  Future<void> tearDown() async {
    Registry.ruleRegistry.unregisterLintRule(RemoveListener());
    await super.tearDown();
  }

  // Basic test to verify rule is registered and can be invoked
  Future<void> test_non_state_class_no_lint() async {
    await assertNoDiagnostics(r'''
class MyNotifier {
  void addListener(void Function() listener) {}
  void removeListener(void Function() listener) {}
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

  Future<void> test_class_without_extends_no_lint() async {
    await assertNoDiagnostics(r'''
class MyClass {
  void initState() {
    // Not a real State class
  }
}
''');
  }

  Future<void> test_class_extending_non_state_no_lint() async {
    await assertNoDiagnostics(r'''
class BaseClass {}

class MyClass extends BaseClass {
  void initState() {}
}
''');
  }

  Future<void> test_no_addListener_calls_no_lint() async {
    await assertNoDiagnostics(r'''
class BaseClass {}

class MyClass extends BaseClass {
  void initState() {
    print('hello');
  }

  void dispose() {}
}
''');
  }

  Future<void> test_addListener_without_arguments_no_lint() async {
    await assertNoDiagnostics(r'''
class MyNotifier {
  void addListener() {}
}

class BaseClass {}

class MyClass extends BaseClass {
  final _notifier = MyNotifier();

  void initState() {
    _notifier.addListener();
  }
}
''');
  }

  Future<void> test_addListener_with_closure_no_callback_name_no_lint() async {
    await assertNoDiagnostics(r'''
class MyNotifier {
  void addListener(void Function() listener) {}
}

class BaseClass {}

class MyClass extends BaseClass {
  final _notifier = MyNotifier();

  void initState() {
    _notifier.addListener(() {});
  }
}
''');
  }

  Future<void> test_target_matching_same_name() async {
    await assertNoDiagnostics(r'''
class MyNotifier {
  void addListener(void Function() listener) {}
  void removeListener(void Function() listener) {}
}

class BaseClass {}

class MyClass extends BaseClass {
  final _notifier = MyNotifier();

  void initState() {
    _notifier.addListener(_onChange);
  }

  void dispose() {
    _notifier.removeListener(_onChange);
  }

  void _onChange() {}
}
''');
  }

  Future<void> test_target_matching_partial_match() async {
    // widget.controller vs controller should match based on last part
    await assertNoDiagnostics(r'''
class MyNotifier {
  void addListener(void Function() listener) {}
  void removeListener(void Function() listener) {}
}

class Widget {
  final controller = MyNotifier();
}

class BaseClass {}

class MyClass extends BaseClass {
  Widget get widget => Widget();

  void initState() {
    widget.controller.addListener(_onChange);
  }

  void dispose() {
    widget.controller.removeListener(_onChange);
  }

  void _onChange() {}
}
''');
  }

  Future<void> test_addStatusListener_without_remove_in_non_state() async {
    await assertNoDiagnostics(r'''
class MyAnimation {
  void addStatusListener(void Function() listener) {}
}

class MyClass {
  final _animation = MyAnimation();

  void initState() {
    _animation.addStatusListener(_onStatus);
  }

  void _onStatus() {}
}
''');
  }

  Future<void> test_removeListener_without_arguments_no_effect() async {
    await assertNoDiagnostics(r'''
class MyNotifier {
  void addListener(void Function() listener) {}
  void removeListener() {} // No argument version
}

class BaseClass {}

class MyClass extends BaseClass {
  final _notifier = MyNotifier();

  void dispose() {
    _notifier.removeListener();
  }
}
''');
  }

  Future<void> test_removeListener_with_closure_no_match() async {
    await assertNoDiagnostics(r'''
class MyNotifier {
  void removeListener(void Function() listener) {}
}

class BaseClass {}

class MyClass extends BaseClass {
  final _notifier = MyNotifier();

  void dispose() {
    _notifier.removeListener(() {});
  }
}
''');
  }

  // Tests for State class with Flutter package

  Future<void> test_state_class_no_listeners_no_lint() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  @override
  Widget build(Object context) => const SizedBox();
}
''');
  }

  Future<void> test_state_class_listener_properly_removed_no_lint() async {
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

  @override
  void dispose() {
    _controller.removeListener(_onChange);
    _controller.dispose();
    super.dispose();
  }

  void _onChange() {}
}
''');
  }

  Future<void> test_state_class_listener_not_removed_reports_lint() async {
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChange() {}
}
''',
      [lint(279, 34)],
    );
  }

  Future<void> test_state_class_listener_in_didChangeDependencies() async {
    await assertDiagnostics(
      r'''
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
''',
      [lint(303, 34)],
    );
  }

  Future<void> test_state_class_listener_in_didUpdateWidget() async {
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void didUpdateWidget(MyWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.addListener(_onChange);
  }

  void _onChange() {}
}
''',
      [lint(318, 34)],
    );
  }

  Future<void> test_state_class_status_listener_not_removed() async {
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
  }

  void _onStatus() {}
}
''',
      [lint(276, 39)],
    );
  }

  Future<void> test_state_class_status_listener_properly_removed() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _animation = AnimationController();

  @override
  void initState() {
    super.initState();
    _animation.addStatusListener(_onStatus);
  }

  @override
  void dispose() {
    _animation.removeStatusListener(_onStatus);
    super.dispose();
  }

  void _onStatus() {}
}
''');
  }

  Future<void> test_state_class_multiple_listeners_partial_remove() async {
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller1 = TextEditingController();
  final _controller2 = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller1.addListener(_onChange1);
    _controller2.addListener(_onChange2);
  }

  @override
  void dispose() {
    _controller1.removeListener(_onChange1);
    super.dispose();
  }

  void _onChange1() {}
  void _onChange2() {}
}
''',
      [lint(370, 36)],
    );
  }

  Future<void> test_state_class_prefixed_identifier_callback() async {
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
  void initState() {
    super.initState();
    _controller.addListener(Callbacks.onChange);
  }

  @override
  void dispose() {
    _controller.removeListener(Callbacks.onChange);
    super.dispose();
  }
}
''');
  }

  Future<void> test_state_class_property_access_pattern() async {
    // Tests PropertyAccess in _getTargetName (parent.controller)
    await assertNoDiagnostics(r'''
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
  }

  @override
  void dispose() {
    parent.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {}
}
''');
  }

  Future<void> test_state_class_partial_target_match_lint() async {
    // Tests partial matching - add with one.controller, remove with two.controller
    // These should NOT match, so lint should fire
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controllerOne = TextEditingController();
  final _controllerTwo = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controllerOne.addListener(_onChange);
  }

  @override
  void dispose() {
    _controllerTwo.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {}
}
''',
      [lint(332, 37)],
    );
  }

  Future<void> test_state_class_target_last_part_match() async {
    // Tests that widget.controller matches parent.controller based on last part
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class Parent {
  final controller = TextEditingController();
}

class MyWidget extends StatefulWidget {
  final controller = TextEditingController();
}

class _MyWidgetState extends State<MyWidget> {
  final parent = Parent();

  @override
  void initState() {
    super.initState();
    // Uses widget.controller
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    // Uses parent.controller - should match because last part is 'controller'
    parent.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {}
}
''');
  }

  Future<void> test_state_subclass_detection() async {
    // Tests recursive State class detection (class extends a class that extends State)
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
  }

  void _onChange() {}
}
''',
      [lint(355, 34)],
    );
  }

  Future<void> test_no_target_addListener_no_lint() async {
    // Tests addListener without a target (null target case)
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';

class MyWidget extends StatefulWidget {}

// A class with addListener as a method on self
class _MyWidgetState extends State<MyWidget> {
  void addListener(void Function() callback) {}
  void removeListener(void Function() callback) {}

  @override
  void initState() {
    super.initState();
    // No target - calling addListener on self
    addListener(_onChange);
  }

  @override
  void dispose() {
    removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {}
}
''');
  }

  Future<void> test_mixed_target_null_reports_lint() async {
    // Tests when addListener has a target but removeListener has no target
    // This hits line 149: if (added == null || removed == null) return false
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  // Local method that shadows removeListener
  void removeListener(void Function() callback) {}

  @override
  void initState() {
    super.initState();
    // Has target: _controller
    _controller.addListener(_onChange);
  }

  @override
  void dispose() {
    // No target - calls local removeListener, not _controller.removeListener
    removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {}
}
''',
      [lint(408, 34)],
    );
  }

  Future<void> test_ignore_for_file_suppresses_lint() async {
    // Tests that ignore_for_file comment suppresses the lint
    await assertNoDiagnostics(r'''
// ignore_for_file: remove_listener
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChange() {}
}
''');
  }

  Future<void> test_ignore_line_suppresses_lint() async {
    // Tests that line-level ignore comment suppresses the lint
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    // ignore: remove_listener
    _controller.addListener(_onChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChange() {}
}
''');
  }

  Future<void> test_ignore_different_rule_does_not_suppress() async {
    // Tests that ignoring a different rule doesn't suppress this lint
    await assertDiagnostics(
      r'''
// ignore_for_file: dispose_notifier
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChange() {}
}
''',
      [lint(316, 34)],
    );
  }

  Future<void> test_addListener_in_helper_method_reports_lint() async {
    // Tests that addListener in a helper method called from initState is detected
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
    _setupListeners();
  }

  void _setupListeners() {
    _controller.addListener(_onChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChange() {}
}
''',
      [lint(334, 34)],
    );
  }

  Future<void> test_addListener_in_helper_with_remove_no_lint() async {
    // Tests that addListener in a helper is matched with removeListener in dispose helper
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _setupListeners();
  }

  void _setupListeners() {
    _controller.addListener(_onChange);
  }

  @override
  void dispose() {
    _cleanupListeners();
    _controller.dispose();
    super.dispose();
  }

  void _cleanupListeners() {
    _controller.removeListener(_onChange);
  }

  void _onChange() {}
}
''');
  }

  Future<void> test_addListener_in_nested_helper_reports_lint() async {
    // Tests that addListener in a deeply nested helper is detected
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
    _setup();
  }

  void _setup() {
    _setupListeners();
  }

  void _setupListeners() {
    _controller.addListener(_onChange);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChange() {}
}
''',
      [lint(371, 34)],
    );
  }

  Future<void> test_direct_add_with_remove_in_helper_no_lint() async {
    // Tests that addListener directly in initState with removeListener
    // in a helper called from dispose works correctly
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

  void _removeListener() {
    _controller.removeListener(_onChange);
  }

  @override
  void dispose() {
    _removeListener();
    _controller.dispose();
    super.dispose();
  }

  void _onChange() {}
}
''');
  }

  Future<void> test_widget_target_with_remove_in_helper_no_lint() async {
    // Tests that addListener with widget.x target and removeListener
    // in a helper called from dispose works correctly
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {
  final ValueNotifier<int> counter = ValueNotifier(0);
}

class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    widget.counter.addListener(_onChange);
  }

  void _removeListener() {
    widget.counter.removeListener(_onChange);
  }

  @override
  void dispose() {
    _removeListener();
    super.dispose();
  }

  void _onChange() {}
}
''');
  }
}
