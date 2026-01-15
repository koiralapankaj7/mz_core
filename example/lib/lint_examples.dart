// ignore_for_file: controller_listen_in_callback, duplicate_listener, remove_listener, dispose_notifier, unused_field, unused_element

import 'package:flutter/material.dart';
import 'package:mz_core/mz_core.dart';

/// Example file with intentional lint violations for testing mz_lints.
///
/// Open this file in your IDE to see the lints in action.
/// Each section demonstrates a specific rule violation.

// =============================================================================
// RULE: dispose_notifier
// =============================================================================

/// BAD: TextEditingController created but not disposed.
class BadControllerExample extends StatefulWidget {
  const BadControllerExample({super.key});

  @override
  State<BadControllerExample> createState() => _BadControllerExampleState();
}

class _BadControllerExampleState extends State<BadControllerExample> {
  // These should trigger dispose_notifier lint
  final _textController = TextEditingController(); // LINT
  final _scrollController = ScrollController(); // OK, as never used
  final _focusNode = FocusNode(); // OK, as never used

  @override
  Widget build(BuildContext context) {
    return TextField(controller: _textController);
  }

  // Missing dispose() method!
}

/// GOOD: Controllers properly disposed.
class GoodControllerExample extends StatefulWidget {
  const GoodControllerExample({super.key});

  @override
  State<GoodControllerExample> createState() => _GoodControllerExampleState();
}

class _GoodControllerExampleState extends State<GoodControllerExample> {
  final _textController = TextEditingController(); // OK
  final _scrollController = ScrollController(); // OK

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(controller: _textController);
  }
}

// =============================================================================
// RULE: remove_listener
// =============================================================================

/// BAD: Listener added but never removed.
class BadListenerExample extends StatefulWidget {
  final ValueNotifier<int> counter;

  const BadListenerExample({super.key, required this.counter});

  @override
  State<BadListenerExample> createState() => _BadListenerExampleState();
}

class _BadListenerExampleState extends State<BadListenerExample> {
  @override
  void initState() {
    super.initState();
    // This should trigger remove_listener lint
    widget.counter.addListener(_onCounterChanged); // LINT
  }

  void _onCounterChanged() {
    setState(() {});
  }

  // Missing removeListener in dispose!

  @override
  Widget build(BuildContext context) {
    return Text('Count: ${widget.counter.value}');
  }
}

/// GOOD: Listener properly removed.
class GoodListenerExample extends StatefulWidget {
  final ValueNotifier<int> counter;

  const GoodListenerExample({super.key, required this.counter});

  @override
  State<GoodListenerExample> createState() => _GoodListenerExampleState();
}

class _GoodListenerExampleState extends State<GoodListenerExample> {
  @override
  void initState() {
    super.initState();
    widget.counter.addListener(_onCounterChanged); // OK
  }

  @override
  void dispose() {
    widget.counter.removeListener(_onCounterChanged);
    super.dispose();
  }

  void _onCounterChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Text('Count: ${widget.counter.value}');
  }
}

// =============================================================================
// RULE: duplicate_listener
// =============================================================================

/// BAD: Same listener added multiple times across methods.
/// The lint analyzes the call graph to detect that _add() is called
/// from initState, causing the same listener to be added twice.
/// The second addListener in _add() is flagged as a duplicate.
class BadDuplicateListenerExample extends StatefulWidget {
  final ValueNotifier<int> counter;

  const BadDuplicateListenerExample({super.key, required this.counter});

  @override
  State<BadDuplicateListenerExample> createState() =>
      _BadDuplicateListenerExampleState();
}

class _BadDuplicateListenerExampleState
    extends State<BadDuplicateListenerExample> {
  @override
  void initState() {
    super.initState();
    widget.counter.addListener(_onCounterChanged); // count = 1
    _add(); // LINT: duplicate - calls addListener again making count = 2
  }

  void _remove() {
    widget.counter.removeListener(_onCounterChanged);
  }

  void _add() {
    // This addListener will be flagged as duplicate
    widget.counter.addListener(_onCounterChanged);
  }

  @override
  void dispose() {
    _remove(); // Properly removes the listener
    super.dispose();
  }

  void _onCounterChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Text('Count: ${widget.counter.value}');
  }
}

/// BAD: Listener added in didUpdateWidget without removing previous one.
class BadDidUpdateWidgetExample extends StatefulWidget {
  final ValueNotifier<int> counter;

  const BadDidUpdateWidgetExample({super.key, required this.counter});

  @override
  State<BadDidUpdateWidgetExample> createState() =>
      _BadDidUpdateWidgetExampleState();
}

class _BadDidUpdateWidgetExampleState extends State<BadDidUpdateWidgetExample> {
  @override
  void didUpdateWidget(BadDidUpdateWidgetExample oldWidget) {
    super.didUpdateWidget(oldWidget);
    // This should trigger duplicate_listener lint
    // Missing: oldWidget.counter.removeListener(_onCounterChanged);
    widget.counter.addListener(_onCounterChanged); // LINT: no remove before add
  }

  @override
  void dispose() {
    widget.counter.removeListener(_onCounterChanged);
    super.dispose();
  }

  void _onCounterChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Text('Count: ${widget.counter.value}');
  }
}

/// GOOD: Listener properly managed in didUpdateWidget.
class GoodDidUpdateWidgetExample extends StatefulWidget {
  final ValueNotifier<int> counter;

  const GoodDidUpdateWidgetExample({super.key, required this.counter});

  @override
  State<GoodDidUpdateWidgetExample> createState() =>
      _GoodDidUpdateWidgetExampleState();
}

class _GoodDidUpdateWidgetExampleState
    extends State<GoodDidUpdateWidgetExample> {
  @override
  void initState() {
    super.initState();
    widget.counter.addListener(_onCounterChanged); // OK
  }

  @override
  void didUpdateWidget(GoodDidUpdateWidgetExample oldWidget) {
    super.didUpdateWidget(oldWidget);
    // GOOD: Remove from old widget before adding to new widget
    oldWidget.counter.removeListener(_onCounterChanged);
    widget.counter.addListener(_onCounterChanged); // OK
  }

  @override
  void dispose() {
    widget.counter.removeListener(_onCounterChanged);
    super.dispose();
  }

  void _onCounterChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Text('Count: ${widget.counter.value}');
  }
}

// =============================================================================
// COMBINED: Multiple violations in one class
// =============================================================================

/// BAD: Multiple lint violations.
class MultipleViolationsExample extends StatefulWidget {
  final ValueNotifier<String> notifier;

  const MultipleViolationsExample({super.key, required this.notifier});

  @override
  State<MultipleViolationsExample> createState() =>
      _MultipleViolationsExampleState();
}

class _MultipleViolationsExampleState extends State<MultipleViolationsExample> {
  final _controller = TextEditingController(); // LINT: not disposed

  @override
  void initState() {
    super.initState();
    widget.notifier.addListener(_onNotify); // LINT: not removed
  }

  void _onNotify() {}

  @override
  Widget build(BuildContext context) {
    return TextField(controller: _controller);
  }
}

// =============================================================================
// RULE: controller_listen_in_callback
// =============================================================================

/// Example Controller for demonstrating controller_listen_in_callback rule.
class ExampleController extends Controller {
  int count = 0;

  void increment() {
    count++;
    notifyListeners();
  }
}

/// BAD: Controller.ofType called in callbacks without listen: false.
class BadControllerListenExample extends StatelessWidget {
  const BadControllerListenExample({super.key});

  // BAD: void method = callback, should use listen: false
  void _onButtonPressed(BuildContext context) {
    final ctrl = Controller.ofType<ExampleController>(context); // LINT
    ctrl.increment();
  }

  // BAD: void method = callback, should use listen: false
  void handleSubmit(BuildContext context) {
    final ctrl = Controller.maybeOfType<ExampleController>(context); // LINT
    ctrl?.increment();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BAD: Lambda callback, should use listen: false
        ElevatedButton(
          onPressed: () {
            final ctrl = Controller.ofType<ExampleController>(context); // LINT
            ctrl.increment();
          },
          child: const Text('Submit'),
        ),

        // BAD: onTap callback, should use listen: false
        GestureDetector(
          onTap: () {
            Controller.maybeOfType<ExampleController>(context); // LINT
          },
          child: const Text('Tap me'),
        ),

        // BAD: onChanged callback, should use listen: false
        TextField(
          onChanged: (value) {
            Controller.ofType<ExampleController>(context); // LINT
          },
        ),
      ],
    );
  }
}

/// GOOD: Controller.ofType called correctly with listen: false in callbacks.
class GoodControllerListenExample extends StatelessWidget {
  const GoodControllerListenExample({super.key});

  // GOOD: Using listen: false in callback
  void _onButtonPressed(BuildContext context) {
    final ctrl = Controller.ofType<ExampleController>(
      context,
      listen: false,
    ); // OK
    ctrl.increment();
  }

  // GOOD: Using listen: false in callback
  void handleSubmit(BuildContext context) {
    final ctrl = Controller.maybeOfType<ExampleController>(
      context,
      listen: false,
    ); // OK
    ctrl?.increment();
  }

  @override
  Widget build(BuildContext context) {
    // GOOD: In build method (returns Widget), listen: true is correct
    final controller = Controller.ofType<ExampleController>(context); // OK

    return Column(
      children: [
        Text('Controller: ${controller.count}'),

        // GOOD: Using listen: false in onPressed callback
        ElevatedButton(
          onPressed: () {
            final ctrl = Controller.ofType<ExampleController>(
              context,
              listen: false,
            ); // OK
            ctrl.increment();
          },
          child: const Text('Submit'),
        ),

        // GOOD: Using listen: false in onTap callback
        GestureDetector(
          onTap: () {
            Controller.maybeOfType<ExampleController>(
              context,
              listen: false,
            ); // OK
          },
          child: const Text('Tap me'),
        ),

        // GOOD: Using listen: false in onChanged callback
        TextField(
          onChanged: (value) {
            Controller.ofType<ExampleController>(context, listen: false); // OK
          },
        ),
      ],
    );
  }
}
