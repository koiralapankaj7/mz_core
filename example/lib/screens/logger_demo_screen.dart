import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mz_core/mz_core.dart';

class LoggerDemoScreen extends StatefulWidget {
  const LoggerDemoScreen({super.key});

  @override
  State<LoggerDemoScreen> createState() => _LoggerDemoScreenState();
}

enum OutputFormat { plain, json, compact }

class _LoggerDemoScreenState extends State<LoggerDemoScreen> {
  late SimpleLogger _logger;
  final List<String> _logOutput = [];
  OutputFormat _outputFormat = OutputFormat.plain;

  @override
  void initState() {
    super.initState();
    _createLogger();
  }

  void _createLogger() {
    _logger = SimpleLogger(
      output: _getOutputForFormat(_outputFormat),
      minimumLevel: LogLevel.trace,
    );
  }

  LogOutput _getOutputForFormat(OutputFormat format) {
    switch (format) {
      case OutputFormat.plain:
        return _PlainTextOutput(_logOutput, () => setState(() {}));
      case OutputFormat.json:
        return _JsonOutput(_logOutput, () => setState(() {}));
      case OutputFormat.compact:
        return _CompactOutput(_logOutput, () => setState(() {}));
    }
  }

  void _changeOutputFormat(OutputFormat format) {
    if (_outputFormat == format) return;

    setState(() {
      _outputFormat = format;
      _logOutput.clear();
    });

    _logger.dispose();
    _createLogger();
  }

  @override
  void dispose() {
    _logger.dispose();
    super.dispose();
  }

  void _clearLogs() {
    setState(() => _logOutput.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Logger Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: _clearLogs,
            tooltip: 'Clear logs',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(flex: 2, child: _LogControls(logger: _logger)),
          const Divider(height: 1),
          _OutputFormatSelector(
            selectedFormat: _outputFormat,
            onFormatChanged: _changeOutputFormat,
          ),
          const Divider(height: 1),
          Expanded(flex: 3, child: _LogOutput(logs: _logOutput)),
        ],
      ),
    );
  }
}

class _OutputFormatSelector extends StatelessWidget {
  const _OutputFormatSelector({
    required this.selectedFormat,
    required this.onFormatChanged,
  });

  final OutputFormat selectedFormat;
  final ValueChanged<OutputFormat> onFormatChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey[200],
      child: Row(
        children: [
          const Text(
            'Output Format:',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SegmentedButton<OutputFormat>(
              segments: const [
                ButtonSegment(
                  value: OutputFormat.plain,
                  label: Text('Plain Text'),
                  icon: Icon(Icons.text_fields),
                ),
                ButtonSegment(
                  value: OutputFormat.json,
                  label: Text('JSON'),
                  icon: Icon(Icons.data_object),
                ),
                ButtonSegment(
                  value: OutputFormat.compact,
                  label: Text('Compact'),
                  icon: Icon(Icons.compress),
                ),
              ],
              selected: {selectedFormat},
              onSelectionChanged: (Set<OutputFormat> selected) {
                onFormatChanged(selected.first);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LogControls extends StatelessWidget {
  const _LogControls({required this.logger});

  final SimpleLogger logger;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Log Levels',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ElevatedButton(
              onPressed: () => logger.trace('This is a trace message'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
              ),
              child: const Text('TRACE'),
            ),
            ElevatedButton(
              onPressed: () => logger.debug('Debugging information'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.cyan),
              child: const Text('DEBUG'),
            ),
            ElevatedButton(
              onPressed: () => logger.info('Info message'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('INFO'),
            ),
            ElevatedButton(
              onPressed: () => logger.warning('Warning message'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text('WARNING'),
            ),
            ElevatedButton(
              onPressed: () => logger.error('Error occurred'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('ERROR'),
            ),
            ElevatedButton(
              onPressed: () => logger.fatal('Critical failure'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
              child: const Text('FATAL'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text(
          'Log Groups',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _logGroupExample(logger),
          icon: const Icon(Icons.account_tree),
          label: const Text('Execute Grouped Operation'),
        ),
        const SizedBox(height: 24),
        Text(
          'Advanced Features',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: () => _logWithMetadata(logger),
          icon: const Icon(Icons.data_object),
          label: const Text('Log with Metadata'),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _logWithDuration(logger),
          icon: const Icon(Icons.timer),
          label: const Text('Log with Duration'),
        ),
      ],
    );
  }

  Future<void> _logGroupExample(SimpleLogger logger) async {
    await logger.group<void>('api-call', 'API Request', () async {
      logger
        ..debug('Preparing request', groupId: 'api-call')
        ..info('Sending GET /users/123', groupId: 'api-call')
        ..debug('Response received (200 OK)', groupId: 'api-call');
    }, description: 'Fetching user data');
  }

  void _logWithMetadata(SimpleLogger logger) {
    logger.info(
      'User action performed',
      name: 'UserAction',
      metaData: const {
        'userId': '12345',
        'action': 'button_click',
        'screen': 'home',
        'timestamp': '2024-01-05T12:00:00Z',
      },
    );
  }

  void _logWithDuration(SimpleLogger logger) {
    logger.info(
      'Operation completed',
      name: 'Performance',
      duration: const Duration(milliseconds: 142),
    );
  }
}

class _LogOutput extends StatelessWidget {
  const _LogOutput({required this.logs});

  final List<String> logs;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey[900],
      child: logs.isEmpty
          ? Center(
              child: Text(
                'No logs yet.\nClick buttons above to generate logs.',
                style: TextStyle(color: Colors.grey[400], fontSize: 16),
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: logs.length,
              itemBuilder: (context, index) {
                final log = logs[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: SelectableText(
                    log,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: _getColorForLog(log),
                    ),
                  ),
                );
              },
            ),
    );
  }

  Color _getColorForLog(String log) {
    if (log.contains('[TRACE]')) return Colors.grey[400]!;
    if (log.contains('[DEBUG]')) return Colors.cyan[300]!;
    if (log.contains('[INFO]')) return Colors.blue[300]!;
    if (log.contains('[WARNING]')) return Colors.orange[300]!;
    if (log.contains('[ERROR]')) return Colors.red[300]!;
    if (log.contains('[FATAL]')) return Colors.purple[300]!;
    return Colors.white;
  }
}

// Plain Text Output - Detailed format with timestamps
class _PlainTextOutput extends LogOutput {
  _PlainTextOutput(this.output, this.onUpdate);

  final List<String> output;
  final VoidCallback onUpdate;

  @override
  void writeEntry(LogEntry entry) {
    final timestamp = entry.timestamp.toString().substring(11, 23);
    final level = entry.level.name.toUpperCase().padRight(7);
    final message = entry.message ?? '';

    final buffer = StringBuffer('$timestamp [$level] ');

    if (entry.name != level.trim()) {
      buffer.write('[${entry.name}] ');
    }

    buffer.write(message);

    if (entry.metadata != null && entry.metadata!.isNotEmpty) {
      buffer.write(' ${entry.metadata}');
    }

    if (entry.duration != null) {
      buffer.write(' (${entry.duration!.inMilliseconds}ms)');
    }

    output.add(buffer.toString());
    onUpdate();
  }

  void _writeEntryWithoutUpdate(LogEntry entry) {
    final timestamp = entry.timestamp.toString().substring(11, 23);
    final level = entry.level.name.toUpperCase().padRight(7);
    final message = entry.message ?? '';

    final buffer = StringBuffer('$timestamp [$level] ');

    if (entry.name != level.trim()) {
      buffer.write('[${entry.name}] ');
    }

    buffer.write(message);

    if (entry.metadata != null && entry.metadata!.isNotEmpty) {
      buffer.write(' ${entry.metadata}');
    }

    if (entry.duration != null) {
      buffer.write(' (${entry.duration!.inMilliseconds}ms)');
    }

    output.add(buffer.toString());
  }

  @override
  void writeGroup(LogGroup group, List<LogEntry> entries) {
    output.add('═══ ${group.title} ═══');
    if (group.description.isNotEmpty) {
      output.add('Description: ${group.description}');
    }
    entries.forEach(_writeEntryWithoutUpdate);
    output.add('═══ End ${group.title} ═══');
    onUpdate();
  }

  @override
  Future<void> flush() async {}
}

// JSON Output - Structured JSON format
class _JsonOutput extends LogOutput {
  _JsonOutput(this.output, this.onUpdate);

  final List<String> output;
  final VoidCallback onUpdate;

  @override
  void writeEntry(LogEntry entry) {
    final json = _entryToJson(entry);
    output.add(const JsonEncoder.withIndent('  ').convert(json));
    onUpdate();
  }

  Map<String, dynamic> _entryToJson(LogEntry entry) {
    return {
      'timestamp': entry.timestamp.toIso8601String(),
      'level': entry.level.name.toUpperCase(),
      'name': entry.name,
      if (entry.message != null) 'message': entry.message,
      if (entry.metadata != null && entry.metadata!.isNotEmpty)
        'metadata': entry.metadata,
      if (entry.duration != null) 'duration_ms': entry.duration!.inMilliseconds,
      if (entry.id != null) 'id': entry.id,
    };
  }

  @override
  void writeGroup(LogGroup group, List<LogEntry> entries) {
    final json = {
      'type': 'group',
      'id': group.id,
      'title': group.title,
      if (group.description.isNotEmpty) 'description': group.description,
      'entries': entries.map(_entryToJson).toList(),
    };

    output.add(const JsonEncoder.withIndent('  ').convert(json));
    onUpdate();
  }

  @override
  Future<void> flush() async {}
}

// Compact Output - Minimal format without timestamps
class _CompactOutput extends LogOutput {
  _CompactOutput(this.output, this.onUpdate);

  final List<String> output;
  final VoidCallback onUpdate;

  @override
  void writeEntry(LogEntry entry) {
    final level = entry.level.name.toUpperCase().substring(0, 1);
    final message = entry.message ?? '';
    final duration = entry.duration != null
        ? ' (${entry.duration!.inMilliseconds}ms)'
        : '';

    output.add('[$level] $message$duration');
    onUpdate();
  }

  void _writeEntryWithoutUpdate(LogEntry entry) {
    final level = entry.level.name.toUpperCase().substring(0, 1);
    final message = entry.message ?? '';
    final duration = entry.duration != null
        ? ' (${entry.duration!.inMilliseconds}ms)'
        : '';

    output.add('[$level] $message$duration');
  }

  @override
  void writeGroup(LogGroup group, List<LogEntry> entries) {
    output.add('▶ ${group.title}');
    entries.forEach(_writeEntryWithoutUpdate);
    output.add('◀ ${group.title}');
    onUpdate();
  }

  @override
  Future<void> flush() async {}
}
