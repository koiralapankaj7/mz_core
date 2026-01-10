import 'package:flutter/material.dart';
import 'package:mz_core/mz_core.dart';

class ExtensionsDemoScreen extends StatefulWidget {
  const ExtensionsDemoScreen({super.key});

  @override
  State<ExtensionsDemoScreen> createState() => _ExtensionsDemoScreenState();
}

class _ExtensionsDemoScreenState extends State<ExtensionsDemoScreen> {
  String _iterableResult = '';
  String _listResult = '';
  String _setResult = '';
  String _stringResult = '';
  String _numResult = '';
  String _widgetResult = '';

  @override
  void initState() {
    super.initState();
    _runIterableExamples();
    _runListExamples();
    _runSetExamples();
    _runStringExamples();
    _runNumExamples();
    _runWidgetExamples();
  }

  void _runIterableExamples() {
    final items = ['apple', 'banana', 'cherry'];

    final indexed = items.toIndexedMap((i) => 'item$i');
    final map = items.toMap((e) => MapEntry(e[0], e));
    final found = items.firstWhereWithIndexOrNull((e) => e.startsWith('b'));
    final index = items.indexOf('cherry');

    _iterableResult =
        '''
Original: $items

toIndexedMap:
$indexed

toMap (first char as key):
$map

firstWhereWithIndexOrNull (starts with 'b'):
${found != null ? 'Index: ${found.$1}, Value: ${found.$2}' : 'Not found'}

indexOf('cherry'): $index
indexOf('grape'): ${items.indexOf('grape')}
''';
  }

  void _runListExamples() {
    final numbers = [1, 2, 3, 4, 5, 3];
    final copy1 = [...numbers];
    final removed1 = copy1.removeFirstWhere((n) => n > 2);

    final copy2 = [1, 2, 3, 4];
    final replaced = copy2.replaceFirst((n) => n == 3 ? 10 : null);

    final copy3 = [1, 2, 3];
    copy3.replaceAll([2, 4]);

    final copy4 = [1, 2, 3, 2, 4, 2];
    copy4.removeAll([2, 4]);

    final copy5 = [1, 2, 3, 2, 4, 2];
    copy5.removeAll([2], firstOccurrences: false);

    _listResult =
        '''
removeFirstWhere (n > 2):
Original: $numbers
Removed: $removed1
Result: $copy1

replaceFirst (3 -> 10):
Original: [1, 2, 3, 4]
Index: $replaced
Result: $copy2

replaceAll ([2, 4]):
Original: [1, 2, 3]
Result: $copy3

removeAll ([2, 4], first only):
Original: [1, 2, 3, 2, 4, 2]
Result: $copy4

removeAll ([2], all):
Original: [1, 2, 3, 2, 4, 2]
Result: $copy5
''';
  }

  void _runSetExamples() {
    final set = {1, 2, 3};
    final removed = set.removeAndReturn(2);
    final notFound = set.removeAndReturn(5);

    _setResult =
        '''
removeAndReturn(2):
Original: {1, 2, 3}
Removed: $removed
Result: $set

removeAndReturn(5):
Result: $notFound (not in set)
''';
  }

  void _runStringExamples() {
    final examples = ['helloWorld', 'user_name', 'API-Key', 'HTTPSConnection'];

    final results = examples
        .map((e) => '$e -> ${e.toCapitalizedWords()}')
        .join('\n');

    _stringResult =
        '''
toCapitalizedWords():

$results
''';
  }

  void _runNumExamples() {
    final examples = [5.0, 5.123, 5.789, 10.0, 3.14159];

    final results = examples
        .map((n) => '$n -> ${n.toStringAsFixedFloor(2)}')
        .join('\n');

    _numResult =
        '''
toStringAsFixedFloor(2):
(integers show 1 decimal, others show 2)

$results

fillTo() - IntMZX:
0.fillTo(3, 'x') -> ${0.fillTo(3, 'x')}
5.fillTo(7, true) -> ${5.fillTo(7, true)}
''';
  }

  void _runWidgetExamples() {
    _widgetResult = '''
insertBetween() - WidgetMZX:

Original: [Text('A'), Text('B'), Text('C')]

After insertBetween((i) => Divider()):
[Text('A'), Divider(), Text('B'), Divider(), Text('C')]

See the visual example below:
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Extensions Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: '1. IterableMZX',
            description: 'Extensions for Iterable operations',
            child: _CodeResultCard(result: _iterableResult),
          ),
          const SizedBox(height: 24),
          _Section(
            title: '2. ListMZX',
            description: 'Extensions for List modifications',
            child: _CodeResultCard(result: _listResult),
          ),
          const SizedBox(height: 24),
          _Section(
            title: '3. SetMZX',
            description: 'Extensions for Set operations',
            child: _CodeResultCard(result: _setResult),
          ),
          const SizedBox(height: 24),
          _Section(
            title: '4. StringMZX',
            description: 'Extensions for String transformations',
            child: _CodeResultCard(result: _stringResult),
          ),
          const SizedBox(height: 24),
          _Section(
            title: '5. IntMZX & NumMZX',
            description: 'Extensions for number operations',
            child: _CodeResultCard(result: _numResult),
          ),
          const SizedBox(height: 24),
          _Section(
            title: '6. WidgetMZX',
            description: 'Extensions for Widget lists',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _CodeResultCard(result: _widgetResult),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Visual Example:',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...[
                          _ExampleCard('Item A', Colors.blue),
                          _ExampleCard('Item B', Colors.green),
                          _ExampleCard('Item C', Colors.orange),
                        ].insertBetween((i) => const Divider(height: 1)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleCard extends StatelessWidget {
  const _ExampleCard(this.text, this.color);

  final String text;
  final MaterialColor color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color[300]!),
      ),
      child: Text(
        text,
        style: TextStyle(fontWeight: FontWeight.bold, color: color[700]),
      ),
    );
  }
}

class _CodeResultCard extends StatelessWidget {
  const _CodeResultCard({required this.result});

  final String result;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: SelectableText(
          result,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
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
