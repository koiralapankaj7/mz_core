import 'package:flutter/material.dart';
import 'package:mz_core/mz_core.dart';

class RateLimitingDemoScreen extends StatefulWidget {
  const RateLimitingDemoScreen({super.key});

  @override
  State<RateLimitingDemoScreen> createState() => _RateLimitingDemoScreenState();
}

class _RateLimitingDemoScreenState extends State<RateLimitingDemoScreen> {
  final _debounceSearchController = TextEditingController();
  final _throttleController = _ThrottleCounter();
  int _debounceSearchCount = 0;
  String _lastSearchTerm = '';

  @override
  void dispose() {
    _debounceSearchController.dispose();
    _throttleController.dispose();
    Debouncer.cancelAll();
    super.dispose();
  }

  void _handleSearch(String value) {
    Debouncer.debounce('search', const Duration(milliseconds: 500), () {
      setState(() {
        _debounceSearchCount++;
        _lastSearchTerm = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate Limiting Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: '1. Debouncing (Search)',
            description: 'Search API calls only after user stops typing',
            child: _DebounceDemo(
              controller: _debounceSearchController,
              onChanged: _handleSearch,
              searchCount: _debounceSearchCount,
              lastSearchTerm: _lastSearchTerm,
            ),
          ),
          const SizedBox(height: 24),
          _Section(
            title: '2. Throttling (Button)',
            description: 'Limit how often a function can execute',
            child: _ThrottleDemo(controller: _throttleController),
          ),
          const SizedBox(height: 24),
          _Section(
            title: '3. Advanced Debouncer',
            description: 'Type-safe async debouncing with cancellation',
            child: const _AdvanceDebouncerDemo(),
          ),
        ],
      ),
    );
  }
}

class _DebounceDemo extends StatelessWidget {
  const _DebounceDemo({
    required this.controller,
    required this.onChanged,
    required this.searchCount,
    required this.lastSearchTerm,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final int searchCount;
  final String lastSearchTerm;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Search',
                hintText: 'Type to search...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: onChanged,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'API Calls Made: $searchCount',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (lastSearchTerm.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text('Last Search: "$lastSearchTerm"'),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Notice: API call only happens 500ms after you stop typing',
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

class _ThrottleCounter with Controller {
  static const _tag = 'throttle_demo';

  int _clickCount = 0;
  int _executionCount = 0;

  int get clickCount => _clickCount;
  int get executionCount => _executionCount;

  void handleClick() {
    _clickCount++;
    notifyListeners();

    Throttler.throttle(_tag, const Duration(seconds: 1), () {
      _executionCount++;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    Throttler.cancel(_tag);
    super.dispose();
  }
}

class _ThrottleDemo extends StatelessWidget {
  const _ThrottleDemo({required this.controller});

  final _ThrottleCounter controller;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ElevatedButton.icon(
              onPressed: controller.handleClick,
              icon: const Icon(Icons.touch_app),
              label: const Text('Click Me Rapidly!'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ControllerBuilder<_ThrottleCounter>(
              controller: controller,
              builder: (context, ctrl) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _Counter(
                            label: 'Clicks',
                            count: ctrl.clickCount,
                            color: Colors.blue,
                          ),
                          _Counter(
                            label: 'Executions',
                            count: ctrl.executionCount,
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Function executes at most once per second, even with rapid clicks',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _AdvanceDebouncerDemo extends StatefulWidget {
  const _AdvanceDebouncerDemo();

  @override
  State<_AdvanceDebouncerDemo> createState() => _AdvanceDebouncerDemoState();
}

class _AdvanceDebouncerDemoState extends State<_AdvanceDebouncerDemo> {
  late final Debounceable<String, String> _debouncedSearch;
  final _textController = TextEditingController();
  String _result = '';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _debouncedSearch = Debouncer.debounceAsync<String, String>('search', (
      query,
    ) async {
      await Future<void>.delayed(const Duration(seconds: 1));
      return 'Results for: "$query"';
    }, duration: const Duration(milliseconds: 800));
  }

  @override
  void dispose() {
    Debouncer.cancel('search');
    _textController.dispose();
    super.dispose();
  }

  Future<void> _handleInput(String value) async {
    if (value.isEmpty) {
      setState(() {
        _result = '';
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);

    final result = await _debouncedSearch(value);
    if (mounted) {
      setState(() {
        _result = result ?? '';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _textController,
              decoration: const InputDecoration(
                labelText: 'Type-safe Async Search',
                hintText: 'Enter query...',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _handleInput,
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: _isLoading
                  ? const Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Searching...'),
                      ],
                    )
                  : Text(
                      _result.isEmpty ? 'No results yet' : _result,
                      style: TextStyle(
                        color: _result.isEmpty ? Colors.grey[600] : null,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              'Cancels previous request if you type within 800ms',
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
  const _Section({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
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
        const SizedBox(height: 4),
        Text(
          description,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
        ),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}
