import 'package:flutter/material.dart';

/// Example file with intentional lint violations for testing mz_lints.
///
/// Open this file in your IDE to see the lints in action.
/// Each section demonstrates a specific rule violation.

// =============================================================================
// RULE: avoid_print_calls
// =============================================================================

/// This function has print calls that should trigger lints.
void examplePrintCalls() {
  print('This should trigger avoid_print_calls lint'); // LINT
  print('Another print call'); // LINT
}

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
    print('Widget initialized'); // LINT: avoid print
  }

  void _onNotify() {
    print('Notified!'); // LINT: avoid print
  }

  @override
  Widget build(BuildContext context) {
    return TextField(controller: _controller);
  }
}

// =============================================================================
// RULE: controller_listen_in_callback
// =============================================================================

/// Example Controller class (simulating mz_utils Controller).
class Controller {
  static T ofType<T>(BuildContext context, {bool listen = true}) {
    throw UnimplementedError();
  }

  static T? maybeOfType<T>(BuildContext context, {bool listen = true}) {
    return null;
  }
}

/// BAD: Controller.ofType called in callbacks without listen: false.
class BadControllerListenExample extends StatelessWidget {
  const BadControllerListenExample({super.key});

  // BAD: void method = callback, should use listen: false
  void _onButtonPressed(BuildContext context) {
    final ctrl = Controller.ofType<Controller>(context); // LINT
    print(ctrl);
  }

  // BAD: void method = callback, should use listen: false
  void handleSubmit(BuildContext context) {
    final ctrl = Controller.maybeOfType<Controller>(context); // LINT
    print(ctrl);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // BAD: Lambda callback, should use listen: false
        ElevatedButton(
          onPressed: () {
            final ctrl = Controller.ofType<Controller>(context); // LINT
            print(ctrl);
          },
          child: const Text('Submit'),
        ),

        // BAD: onTap callback, should use listen: false
        GestureDetector(
          onTap: () {
            Controller.maybeOfType<Controller>(context); // LINT1
          },
          child: const Text('Tap me'),
        ),

        // BAD: onChanged callback, should use listen: false
        TextField(
          onChanged: (value) {
            Controller.ofType<Controller>(context); // LINT
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
    final ctrl = Controller.ofType<Controller>(context, listen: false); // OK
    print(ctrl);
  }

  // GOOD: Using listen: false in callback
  void handleSubmit(BuildContext context) {
    final ctrl = Controller.maybeOfType<Controller>(
      context,
      listen: false,
    ); // OK
    print(ctrl);
  }

  @override
  Widget build(BuildContext context) {
    // GOOD: In build method (returns Widget), listen: true is correct
    final controller = Controller.ofType<Controller>(context); // OK

    return Column(
      children: [
        Text('Controller: $controller'),

        // GOOD: Using listen: false in onPressed callback
        ElevatedButton(
          onPressed: () {
            final ctrl = Controller.ofType<Controller>(
              context,
              listen: false,
            ); // OK
            print(ctrl);
          },
          child: const Text('Submit'),
        ),

        // GOOD: Using listen: false in onTap callback
        GestureDetector(
          onTap: () {
            Controller.maybeOfType<Controller>(context, listen: false); // OK
          },
          child: const Text('Tap me'),
        ),

        // GOOD: Using listen: false in onChanged callback
        TextField(
          onChanged: (value) {
            Controller.ofType<Controller>(context, listen: false); // OK
          },
        ),
      ],
    );
  }
}
