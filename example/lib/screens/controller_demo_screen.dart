import 'package:flutter/material.dart';
import 'package:mz_core/mz_core.dart';

class ControllerDemoScreen extends StatefulWidget {
  const ControllerDemoScreen({super.key});

  @override
  State<ControllerDemoScreen> createState() => _ControllerDemoScreenState();
}

class _ControllerDemoScreenState extends State<ControllerDemoScreen> {
  late final CounterController _counterController;
  late final FormController _formController;
  late final PriorityController _priorityController;

  @override
  void initState() {
    super.initState();
    _counterController = CounterController();
    _formController = FormController();
    _priorityController = PriorityController();
  }

  @override
  void dispose() {
    _counterController.dispose();
    _formController.dispose();
    _priorityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Controller Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: '1. Basic Counter with .watch()',
            child: _CounterDemo(controller: _counterController),
          ),
          const SizedBox(height: 24),
          _Section(
            title: '2. Key-Based Selective Notifications',
            child: _FormDemo(controller: _formController),
          ),
          const SizedBox(height: 24),
          _Section(
            title: '3. Priority Listeners',
            child: _PriorityDemo(controller: _priorityController),
          ),
        ],
      ),
    );
  }
}

// Counter Controller
class CounterController with Controller {
  int _count = 0;
  int get count => _count;

  void increment() {
    _count++;
    notifyListeners();
  }

  void decrement() {
    _count--;
    notifyListeners();
  }

  void reset() {
    _count = 0;
    notifyListeners();
  }
}

// Form Controller with key-based notifications
class FormController with Controller {
  String _name = '';
  String _email = '';
  String _phone = '';

  String get name => _name;
  String get email => _email;
  String get phone => _phone;

  void setName(String value) {
    _name = value;
    notifyListeners(key: 'name');
  }

  void setEmail(String value) {
    _email = value;
    notifyListeners(key: 'email');
  }

  void setPhone(String value) {
    _phone = value;
    notifyListeners(key: 'phone');
  }
}

// Priority Controller
class PriorityController with Controller {
  final List<String> _log = [];
  List<String> get log => List.unmodifiable(_log);

  void trigger() {
    _log.clear();
    notifyListeners();
  }

  void clearLog() {
    _log.clear();
    notifyListeners();
  }
}

// Counter Demo Widget
class _CounterDemo extends StatelessWidget {
  const _CounterDemo({required this.controller});

  final CounterController controller;

  @override
  Widget build(BuildContext context) {
    // Using .watch() - automatically rebuilds when controller changes
    final count = controller.watch(context).count;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Count: $count',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: controller.decrement,
                  child: const Icon(Icons.remove),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: controller.reset,
                  child: const Text('Reset'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: controller.increment,
                  child: const Icon(Icons.add),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'This widget uses .watch() for automatic rebuilds',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// Form Demo Widget
class _FormDemo extends StatelessWidget {
  const _FormDemo({required this.controller});

  final FormController controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
              ),
              onChanged: controller.setName,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              onChanged: controller.setEmail,
            ),
            const SizedBox(height: 12),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Phone',
                border: OutlineInputBorder(),
              ),
              onChanged: controller.setPhone,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            // Only rebuilds when 'name' changes
            _FormField(
              controller: controller,
              watchKey: 'name',
              label: 'Name Preview',
              getValue: (c) => c.name,
            ),
            const SizedBox(height: 8),
            // Only rebuilds when 'email' changes
            _FormField(
              controller: controller,
              watchKey: 'email',
              label: 'Email Preview',
              getValue: (c) => c.email,
            ),
            const SizedBox(height: 8),
            // Only rebuilds when 'phone' changes
            _FormField(
              controller: controller,
              watchKey: 'phone',
              label: 'Phone Preview',
              getValue: (c) => c.phone,
            ),
            const SizedBox(height: 8),
            Text(
              'Each preview only rebuilds when its specific field changes!',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  const _FormField({
    required this.controller,
    required this.watchKey,
    required this.label,
    required this.getValue,
  });

  final FormController controller;
  final String watchKey;
  final String label;
  final String Function(FormController) getValue;

  @override
  Widget build(BuildContext context) {
    // Only rebuilds when the specific key is notified
    final value = controller.watch(context, key: watchKey);
    final displayValue = getValue(value);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              displayValue.isEmpty ? '(empty)' : displayValue,
              style: TextStyle(
                color: displayValue.isEmpty ? Colors.grey : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Priority Demo Widget
class _PriorityDemo extends StatefulWidget {
  const _PriorityDemo({required this.controller});

  final PriorityController controller;

  @override
  State<_PriorityDemo> createState() => _PriorityDemoState();
}

class _PriorityDemoState extends State<_PriorityDemo> {
  @override
  void initState() {
    super.initState();

    // Add listeners with different priorities
    widget.controller.addListener(
      () => widget.controller._log.add('Low priority (0)'),
      priority: 0,
    );

    widget.controller.addListener(
      () => widget.controller._log.add('High priority (10)'),
      priority: 10,
    );

    widget.controller.addListener(
      () => widget.controller._log.add('Medium priority (5)'),
      priority: 5,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: widget.controller.trigger,
              child: const Text('Trigger Notification'),
            ),
            const SizedBox(height: 16),
            ControllerBuilder<PriorityController>(
              controller: widget.controller,
              builder: (context, ctrl) {
                if (ctrl.log.isEmpty) {
                  return const Text(
                    'Click button to see priority order',
                    textAlign: TextAlign.center,
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Execution Order:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...ctrl.log.asMap().entries.map(
                      (entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text('${entry.key + 1}. ${entry.value}'),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Higher priority listeners execute first!',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}
