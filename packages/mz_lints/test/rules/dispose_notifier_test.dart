import 'package:analyzer/src/lint/registry.dart';
import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:mz_lints/src/rules/dispose_notifier.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(DisposeNotifierTest);
  });
}

@reflectiveTest
class DisposeNotifierTest extends AnalysisRuleTest {
  @override
  String get analysisRule => DisposeNotifier.code.name;

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
  void initState() {}
  void dispose() {}
  Widget build(Object context) => throw UnimplementedError();
}
class BuildContext {}
class SizedBox extends Widget {
  const SizedBox();
}
''')
      ..addFile('lib/src/change_notifier.dart', r'''
mixin class ChangeNotifier {
  void addListener(void Function() listener) {}
  void removeListener(void Function() listener) {}
  void dispose() {}
  void notifyListeners() {}
}
class TextEditingController extends ChangeNotifier {
  TextEditingController();
  factory TextEditingController.fromValue(Object? value) => TextEditingController();
  String text = '';
}
class ScrollController extends ChangeNotifier {}
class ValueNotifier<T> extends ChangeNotifier {
  ValueNotifier(this.value);
  T value;
}
mixin ChangeNotifierMixin {
  void addListener(void Function() listener) {}
  void removeListener(void Function() listener) {}
  void dispose() {}
  void notifyListeners() {}
}
class MixinNotifier with ChangeNotifierMixin {}

class NotifierFactory {
  static TextEditingController create() => TextEditingController();
}

// Interface that extends ChangeNotifier for interface-based detection test
abstract class IChangeNotifier extends ChangeNotifier {}
class InterfaceBasedNotifier implements IChangeNotifier {
  @override void addListener(void Function() listener) {}
  @override void removeListener(void Function() listener) {}
  @override void dispose() {}
  @override void notifyListeners() {}
}

// For testing PrefixedIdentifier dispose (StaticClass.field.dispose())
class Holder {
  static final controller = TextEditingController();
}
''');

    Registry.ruleRegistry.registerLintRule(DisposeNotifier());
    super.setUp();
  }

  @override
  Future<void> tearDown() async {
    Registry.ruleRegistry.unregisterLintRule(DisposeNotifier());
    await super.tearDown();
  }

  Future<void> test_non_state_class_no_lint() async {
    await assertNoDiagnostics(r'''
class MyController {
  void dispose() {}
}

class MyClass {
  final _controller = MyController();

  void doSomething() {}
}
''');
  }

  Future<void> test_class_without_extends_no_lint() async {
    // Tests that classes without extends clause don't trigger the rule
    await assertNoDiagnostics(r'''
class MyClass {
  void doSomething() {}
}
''');
  }

  Future<void> test_state_class_no_notifiers_no_lint() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  @override
  Widget build(Object context) => const SizedBox();
}
''');
  }

  Future<void> test_state_class_notifier_disposed_no_lint() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(Object context) {
    print(_controller.text);
    return const SizedBox();
  }
}
''');
  }

  Future<void> test_state_class_notifier_not_disposed_reports_lint() async {
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  Widget build(Object context) {
    print(_controller.text);
    return const SizedBox();
  }
}
''',
      [lint(179, 37)],
    );
  }

  Future<void> test_state_class_notifier_unused_no_lint() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  Widget build(Object context) => const SizedBox();
}
''');
  }

  Future<void> test_state_class_multiple_notifiers_partial_dispose() async {
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(Object context) {
    print(_textController.text);
    print(_scrollController);
    return const SizedBox();
  }
}
''',
      [lint(230, 38)],
    );
  }

  Future<void> test_state_class_value_notifier_not_disposed() async {
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _counter = ValueNotifier<int>(0);

  @override
  Widget build(Object context) {
    print(_counter.value);
    return const SizedBox();
  }
}
''',
      [lint(179, 32)],
    );
  }

  Future<void> test_state_class_dispose_in_expression_body() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  Widget build(Object context) {
    print(_controller.text);
    return const SizedBox();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
''');
  }

  Future<void> test_state_class_factory_method_notifier() async {
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController.fromValue(null);

  @override
  Widget build(Object context) {
    print(_controller.text);
    return const SizedBox();
  }
}
''',
      [lint(179, 51)],
    );
  }

  Future<void> test_state_class_mixin_notifier_no_lint() async {
    // MixinNotifier uses a mixin, not ChangeNotifier inheritance
    // The rule currently only checks ChangeNotifier extension chain
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _notifier = MixinNotifier();

  @override
  Widget build(Object context) {
    print(_notifier);
    return const SizedBox();
  }
}
''');
  }

  Future<void> test_state_class_prefixed_dispose_call() async {
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class Holder {
  final controller = TextEditingController();
}

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _holder = Holder();

  @override
  void dispose() {
    _holder.controller.dispose();
    super.dispose();
  }

  @override
  Widget build(Object context) {
    print(_holder.controller.text);
    return const SizedBox();
  }
}
''');
  }

  Future<void> test_state_class_constructor_reference() async {
    // Tests that references in constructor body are detected
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  _MyWidgetState() {
    print(_controller.text);
  }

  @override
  Widget build(Object context) => const SizedBox();
}
''',
      [lint(179, 37)],
    );
  }

  Future<void> test_state_class_static_factory_method_notifier() async {
    // Tests MethodInvocation initializer (static factory method)
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = NotifierFactory.create();

  @override
  Widget build(Object context) {
    print(_controller.text);
    return const SizedBox();
  }
}
''',
      [lint(179, 38)],
    );
  }

  Future<void> test_state_class_constructor_initializer_list() async {
    // Tests constructor initializer list reference detection
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();
  final String _text;

  _MyWidgetState() : _text = 'initial' {
    // Empty body, reference is in initializer list pattern
  }

  void someMethod() {
    print(_controller.text);
  }

  @override
  Widget build(Object context) => const SizedBox();
}
''',
      [lint(179, 37)],
    );
  }

  Future<void> test_state_class_this_prefixed_dispose() async {
    // Tests PrefixedIdentifier dispose call (this._controller.dispose())
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    this._controller.dispose();
    super.dispose();
  }

  @override
  Widget build(Object context) {
    print(_controller.text);
    return const SizedBox();
  }
}
''');
  }

  Future<void> test_state_class_interface_based_notifier() async {
    // Tests interface-based ChangeNotifier detection (implements interface that extends ChangeNotifier)
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _notifier = InterfaceBasedNotifier();

  @override
  Widget build(Object context) {
    print(_notifier);
    return const SizedBox();
  }
}
''',
      [lint(179, 36)],
    );
  }

  Future<void> test_state_class_static_holder_dispose() async {
    // Tests PrefixedIdentifier dispose (Holder.controller.dispose())
    // The rule only checks field notifiers, not static ones
    // But this tests the PrefixedIdentifier path in _DisposeVisitor
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    // This uses PrefixedIdentifier: Holder.controller
    Holder.controller.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(Object context) {
    print(_controller.text);
    return const SizedBox();
  }
}
''');
  }

  Future<void> test_state_class_mixin_based_notifier_reports_lint() async {
    // Tests mixin-based ChangeNotifier detection (element.mixins check)
    // MixinNotifier uses ChangeNotifierMixin which has addListener/removeListener
    // but doesn't extend ChangeNotifier - this tests the mixin detection path
    await assertDiagnostics(
      r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

// Custom class that uses ChangeNotifier as a mixin
class MyMixinNotifier with ChangeNotifier {}

class _MyWidgetState extends State<MyWidget> {
  final _notifier = MyMixinNotifier();

  @override
  Widget build(Object context) {
    print(_notifier);
    return const SizedBox();
  }
}
''',
      [lint(277, 29)],
    );
  }

  Future<void> test_state_class_field_without_initializer_no_lint() async {
    // Tests that fields without initializers are not flagged
    await assertNoDiagnostics(r'''
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  Widget build(Object context) {
    print(_controller.text);
    return const SizedBox();
  }
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
  Widget build(Object context) {
    print(_controller.text);
    return const SizedBox();
  }
}
''',
      [lint(255, 37)],
    );
  }

  Future<void> test_ignore_for_file_suppresses_lint() async {
    // Tests that ignore_for_file comment suppresses the lint
    await assertNoDiagnostics(r'''
// ignore_for_file: dispose_notifier
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  Widget build(Object context) {
    print(_controller.text);
    return const SizedBox();
  }
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
  // ignore: dispose_notifier
  final _controller = TextEditingController();

  @override
  Widget build(Object context) {
    print(_controller.text);
    return const SizedBox();
  }
}
''');
  }

  Future<void> test_ignore_different_rule_does_not_suppress() async {
    // Tests that ignoring a different rule doesn't suppress this lint
    await assertDiagnostics(
      r'''
// ignore_for_file: remove_listener
import 'package:flutter/widgets.dart';
import 'package:flutter/foundation.dart';

class MyWidget extends StatefulWidget {}

class _MyWidgetState extends State<MyWidget> {
  final _controller = TextEditingController();

  @override
  Widget build(Object context) {
    print(_controller.text);
    return const SizedBox();
  }
}
''',
      [lint(215, 37)],
    );
  }
}
