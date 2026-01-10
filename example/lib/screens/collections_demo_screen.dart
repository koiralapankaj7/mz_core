import 'package:flutter/material.dart';
import 'package:mz_core/mz_core.dart';

class CollectionsDemoScreen extends StatefulWidget {
  const CollectionsDemoScreen({super.key});

  @override
  State<CollectionsDemoScreen> createState() => _CollectionsDemoScreenState();
}

class _CollectionsDemoScreenState extends State<CollectionsDemoScreen> {
  late final ListenableList<String> _taskList;
  late final ListenableSet<String> _tagSet;
  final _taskController = TextEditingController();
  final _tagController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _taskList = ListenableList<String>.from([
      'Buy groceries',
      'Walk the dog',
      'Finish project',
    ]);
    _tagSet = ListenableSet<String>.from({'urgent', 'personal', 'work'});
  }

  @override
  void dispose() {
    _taskList.dispose();
    _tagSet.dispose();
    _taskController.dispose();
    _tagController.dispose();
    super.dispose();
  }

  void _addTask() {
    if (_taskController.text.trim().isEmpty) return;
    _taskList.add(_taskController.text.trim());
    _taskController.clear();
  }

  void _removeTask(int index) {
    _taskList.removeAt(index);
  }

  void _modifyTask(int index) {
    final current = _taskList[index];
    _taskList[index] = '$current (modified)';
  }

  void _toggleTag(String tag) {
    if (_tagSet.contains(tag)) {
      _tagSet.remove(tag);
    } else {
      _tagSet.add(tag);
    }
  }

  void _addCustomTag() {
    if (_tagController.text.trim().isEmpty) return;
    _tagSet.add(_tagController.text.trim());
    _tagController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collections Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Section(
            title: '1. ListenableList',
            description: 'A list that notifies listeners on add/remove/modify',
            child: _ListenableListDemo(
              taskList: _taskList,
              taskController: _taskController,
              onAddTask: _addTask,
              onRemoveTask: _removeTask,
              onModifyTask: _modifyTask,
            ),
          ),
          const SizedBox(height: 24),
          _Section(
            title: '2. ListenableSet',
            description: 'A set that notifies listeners on add/remove',
            child: _ListenableSetDemo(
              tagSet: _tagSet,
              tagController: _tagController,
              onToggleTag: _toggleTag,
              onAddCustomTag: _addCustomTag,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListenableListDemo extends StatelessWidget {
  const _ListenableListDemo({
    required this.taskList,
    required this.taskController,
    required this.onAddTask,
    required this.onRemoveTask,
    required this.onModifyTask,
  });

  final ListenableList<String> taskList;
  final TextEditingController taskController;
  final VoidCallback onAddTask;
  final void Function(int index) onRemoveTask;
  final void Function(int index) onModifyTask;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: taskController,
                    decoration: const InputDecoration(
                      labelText: 'New Task',
                      hintText: 'Enter task name...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => onAddTask(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onAddTask,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListenableBuilder(
                listenable: taskList,
                builder: (context, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Tasks',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${taskList.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (taskList.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'No tasks yet',
                              style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        )
                      else
                        ...taskList.asMap().entries.map((entry) {
                          final index = entry.key;
                          final task = entry.value;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: Colors.grey[300]!),
                              ),
                              child: Row(
                                children: [
                                  Expanded(child: Text(task)),
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 20),
                                    onPressed: () => onModifyTask(index),
                                    tooltip: 'Modify',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    icon: const Icon(Icons.delete, size: 20),
                                    onPressed: () => onRemoveTask(index),
                                    tooltip: 'Delete',
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adding, modifying, or removing tasks. The UI updates automatically!',
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

class _ListenableSetDemo extends StatelessWidget {
  const _ListenableSetDemo({
    required this.tagSet,
    required this.tagController,
    required this.onToggleTag,
    required this.onAddCustomTag,
  });

  final ListenableSet<String> tagSet;
  final TextEditingController tagController;
  final void Function(String tag) onToggleTag;
  final VoidCallback onAddCustomTag;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: tagController,
                    decoration: const InputDecoration(
                      labelText: 'New Tag',
                      hintText: 'Enter tag name...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => onAddCustomTag(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: onAddCustomTag,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListenableBuilder(
                listenable: tagSet,
                builder: (context, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Active Tags',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${tagSet.length}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (tagSet.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: Text(
                              'No tags selected',
                              style: TextStyle(
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: tagSet.map((tag) {
                            return FilterChip(
                              label: Text(tag),
                              selected: true,
                              onSelected: (_) => onToggleTag(tag),
                              selectedColor: Colors.blue[200],
                              checkmarkColor: Colors.blue[900],
                            );
                          }).toList(),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Predefined Tags (Click to Toggle):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: tagSet,
              builder: (context, _) {
                final predefinedTags = [
                  'urgent',
                  'personal',
                  'work',
                  'home',
                  'health',
                ];
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: predefinedTags.map((tag) {
                    final isSelected = tagSet.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: isSelected,
                      onSelected: (_) => onToggleTag(tag),
                      selectedColor: Colors.blue[200],
                      checkmarkColor: Colors.blue[900],
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 8),
            Text(
              'Click tags to add/remove them. Sets automatically prevent duplicates!',
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
