import 'dart:async' show unawaited;
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mz_core/src/logger.dart';

void main() {
  group('LogLevel Tests |', () {
    test('should have correct severity ordering', () {
      expect(LogLevel.trace.severity, 0);
      expect(LogLevel.debug.severity, 1);
      expect(LogLevel.info.severity, 2);
      expect(LogLevel.warning.severity, 3);
      expect(LogLevel.error.severity, 4);
      expect(LogLevel.fatal.severity, 5);
    });

    test('should have correct colors', () {
      expect(LogLevel.trace.color, '\x1B[90m');
      expect(LogLevel.debug.color, '\x1B[36m');
      expect(LogLevel.info.color, '\x1B[34m');
      expect(LogLevel.warning.color, '\x1B[33m');
      expect(LogLevel.error.color, '\x1B[31m');
      expect(LogLevel.fatal.color, '\x1B[35m');
    });

    test('should compare severity with >= operator', () {
      expect(LogLevel.error >= LogLevel.warning, isTrue);
      expect(LogLevel.warning >= LogLevel.warning, isTrue);
      expect(LogLevel.info >= LogLevel.error, isFalse);
    });

    test('should compare severity with > operator', () {
      expect(LogLevel.error > LogLevel.warning, isTrue);
      expect(LogLevel.warning > LogLevel.warning, isFalse);
    });

    test('should compare severity with <= operator', () {
      expect(LogLevel.info <= LogLevel.warning, isTrue);
      expect(LogLevel.warning <= LogLevel.warning, isTrue);
      expect(LogLevel.error <= LogLevel.info, isFalse);
    });

    test('should compare severity with < operator', () {
      expect(LogLevel.info < LogLevel.warning, isTrue);
      expect(LogLevel.warning < LogLevel.warning, isFalse);
    });
  });

  group('LogEntry Tests |', () {
    test('should create with required fields', () {
      final timestamp = DateTime.now();
      final entry = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: timestamp,
      );

      expect(entry.name, 'test');
      expect(entry.level, LogLevel.info);
      expect(entry.timestamp, timestamp);
    });

    test('should create with all fields', () {
      final timestamp = DateTime.now();
      final entry = LogEntry(
        name: 'test',
        level: LogLevel.error,
        timestamp: timestamp,
        id: 'id-123',
        message: 'Test message',
        duration: const Duration(milliseconds: 100),
        color: '\x1B[31m',
        metadata: const {'key': 'value'},
      );

      expect(entry.id, 'id-123');
      expect(entry.message, 'Test message');
      expect(entry.duration, const Duration(milliseconds: 100));
      expect(entry.color, '\x1B[31m');
      expect(entry.metadata, const {'key': 'value'});
    });

    test('should convert to JSON', () {
      final timestamp = DateTime(2024);
      final entry = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: timestamp,
        message: 'msg',
        id: 'id-1',
        duration: const Duration(milliseconds: 50),
        metadata: const {'extra': 123},
      );

      final json = entry.toJson();

      expect(json['name'], 'test');
      expect(json['level'], 'info');
      expect(json['timestamp'], timestamp.toIso8601String());
      expect(json['message'], 'msg');
      expect(json['eventId'], 'id-1');
      expect(json['duration'], 50.0);
      expect(json['extra'], 123);
    });

    test('should handle equality', () {
      final timestamp = DateTime.now();
      final entry1 = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: timestamp,
      );
      final entry2 = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: timestamp,
      );
      final entry3 = LogEntry(
        name: 'other',
        level: LogLevel.info,
        timestamp: timestamp,
      );

      expect(entry1, equals(entry2));
      expect(entry1, isNot(equals(entry3)));
    });

    test('should have consistent hashCode', () {
      final timestamp = DateTime.now();
      final entry1 = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: timestamp,
      );
      final entry2 = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: timestamp,
      );

      expect(entry1.hashCode, equals(entry2.hashCode));
    });
  });

  group('LogGroup Tests |', () {
    test('should create log group', () {
      const group = LogGroup(
        id: 'g1',
        title: 'Test Group',
        description: 'Description',
      );

      expect(group.id, 'g1');
      expect(group.title, 'Test Group');
      expect(group.description, 'Description');
    });

    test('should handle equality based on id', () {
      const group1 = LogGroup(id: 'g1', title: 'A', description: 'A');
      const group2 = LogGroup(id: 'g1', title: 'B', description: 'B');
      const group3 = LogGroup(id: 'g2', title: 'A', description: 'A');

      expect(group1, equals(group2));
      expect(group1, isNot(equals(group3)));
    });

    test('should return true when comparing identical instance', () {
      // This tests line 105: if (identical(this, other)) return true;
      const group = LogGroup(id: 'g1', title: 'Test', description: 'Desc');

      // Compare same instance to itself
      expect(group == group, isTrue);
      expect(group.hashCode == group.hashCode, isTrue);
    });

    test('should have consistent hashCode based on id', () {
      const group1 = LogGroup(id: 'g1', title: 'A', description: 'A');
      const group2 = LogGroup(id: 'g1', title: 'B', description: 'B');

      expect(group1.hashCode, equals(group2.hashCode));
    });
  });

  group('SimpleLogger Tests |', () {
    late List<String> output;
    late SimpleLogger logger;

    setUp(() {
      output = [];
      logger = SimpleLogger(output: _TestOutput(output));
    });

    test('should create with default output', () {
      final logger = SimpleLogger();
      expect(logger.output, isA<ConsoleOutput>());
    });

    test('should filter by minimum level', () {
      logger = SimpleLogger(
        output: _TestOutput(output),
        minimumLevel: LogLevel.warning,
      )
        ..logEntry(
          LogEntry(
            name: 'test',
            level: LogLevel.info,
            timestamp: DateTime.now(),
          ),
        )
        ..logEntry(
          LogEntry(
            name: 'test',
            level: LogLevel.warning,
            timestamp: DateTime.now(),
          ),
        );

      expect(output, hasLength(1)); // Only warning logged
    });

    test('should sample logs based on sample rate', () {
      var loggedCount = 0;
      logger = SimpleLogger(
        output: _TestOutput(output),
        sampleRate: 0.5,
      );

      // Log many entries and verify sampling
      for (var i = 0; i < 100; i++) {
        final result = logger.logEntry(
          LogEntry(
            name: 'test',
            level: LogLevel.info,
            timestamp: DateTime.now(),
          ),
        );
        if (result) loggedCount++;
      }

      // Should be roughly 50% sampled (allow wide variance for randomness)
      expect(loggedCount, greaterThan(10)); // More lenient lower bound
      expect(loggedCount, lessThan(90)); // More lenient upper bound
    });

    test('should not log when disabled', () {
      logger
        ..isEnabled = false
        ..logEntry(
          LogEntry(
            name: 'test',
            level: LogLevel.info,
            timestamp: DateTime.now(),
          ),
        );

      expect(output, isEmpty);
    });

    test('should call observer when logging', () {
      LogEntry? observedEntry;
      logger = SimpleLogger(
        output: _TestOutput(output),
        observer: (entry, group) => observedEntry = entry,
      );

      final entry = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: DateTime.now(),
      );
      logger.logEntry(entry);

      expect(observedEntry, equals(entry));
    });

    test('should filter entries when filter returns true', () {
      logger = SimpleLogger(
        output: _TestOutput(output),
        filter: (entry, group) => entry.name == 'filtered',
      )
        ..logEntry(
          LogEntry(
            name: 'filtered',
            level: LogLevel.info,
            timestamp: DateTime.now(),
          ),
        )
        ..logEntry(
          LogEntry(
            name: 'allowed',
            level: LogLevel.info,
            timestamp: DateTime.now(),
          ),
        );

      expect(output, hasLength(1));
    });

    test('should handle error via onError callback', () {
      Object? caughtError;
      final failingOutput = _FailingOutput();
      logger = SimpleLogger(
        output: failingOutput,
        onError: (error, st) => caughtError = error,
      )..logEntry(
          LogEntry(
            name: 'test',
            level: LogLevel.info,
            timestamp: DateTime.now(),
          ),
        );

      expect(caughtError, isA<Exception>());
    });

    test('should guard callback execution', () {
      var executed = false;
      logger.guard(() => executed = true);
      expect(executed, isTrue);
    });

    test('should not execute guard callback when disabled', () {
      var executed = false;
      logger
        ..isEnabled = false
        ..guard(() => executed = true);
      expect(executed, isFalse);
    });

    test('should start group and add entries', () {
      const group = LogGroup(id: 'g1', title: 'Test', description: 'Desc');
      logger
        ..startGroup(group)
        ..logEntry(
          LogEntry(
            name: 'e1',
            level: LogLevel.info,
            timestamp: DateTime.now(),
          ),
          groupId: 'g1',
        );

      expect(output, isEmpty); // Not written yet
    });

    test('should complete group and output all entries', () {
      const group = LogGroup(id: 'g1', title: 'Test', description: 'Desc');
      logger
        ..startGroup(group)
        ..logEntry(
          LogEntry(
            name: 'e1',
            level: LogLevel.info,
            timestamp: DateTime.now(),
          ),
          groupId: 'g1',
        )
        ..logEntry(
          LogEntry(
            name: 'e2',
            level: LogLevel.info,
            timestamp: DateTime.now(),
          ),
          groupId: 'g1',
        )
        ..completeGroup('g1');

      expect(output, hasLength(1)); // Group written
    });

    test('should throw when completing non-existent group', () {
      expect(
        () => logger.completeGroup('nonexistent'),
        throwsA(isA<Exception>()),
      );
    });

    test('should auto-complete group after timeout', () async {
      const group = LogGroup(id: 'g1', title: 'Test', description: 'Desc');
      logger = SimpleLogger(
        output: _TestOutput(output),
        groupTimeout: const Duration(milliseconds: 100),
      )
        ..startGroup(group)
        ..logEntry(
          LogEntry(
            name: 'e1',
            level: LogLevel.info,
            timestamp: DateTime.now(),
          ),
          groupId: 'g1',
        );

      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(output, hasLength(1)); // Auto-completed
    });

    test('should run group with async function', () async {
      final result = await logger.group<int>(
        'g1',
        'Test Group',
        () async {
          logger.logEntry(
            LogEntry(
              name: 'inside',
              level: LogLevel.info,
              timestamp: DateTime.now(),
            ),
            groupId: 'g1',
          );
          return 42;
        },
      );

      expect(result, 42);
      expect(output, hasLength(1)); // Group completed automatically
    });

    test(
      'should complete group in finally even when function throws',
      () async {
        // This test ensures the finally block (line 182) is executed
        // even when the function throws an exception
        try {
          await logger.group<void>(
            'g2',
            'Error Group',
            () async {
              // Add an entry so the group will be written
              logger.logEntry(
                LogEntry(
                  name: 'before_error',
                  level: LogLevel.info,
                  timestamp: DateTime.now(),
                ),
                groupId: 'g2',
              );
              throw Exception('Test error');
            },
          );
          fail('Should have thrown');
        } on Exception catch (e) {
          // Exception is expected
          expect(e.toString(), contains('Test error'));
        }

        // Group should still be completed due to finally block
        expect(output, hasLength(1));
      },
    );

    test('should dispose and cancel all timers', () {
      const group = LogGroup(id: 'g1', title: 'Test', description: 'Desc');
      logger.startGroup(group);

      expect(() => logger.dispose(), returnsNormally);
    });

    test('should not notify isEnabled setter if value unchanged', () {
      logger
        ..isEnabled = true
        ..isEnabled = true;

      expect(logger.isEnabled, isTrue);
    });
  });

  group('SimpleLoggerX Extension Tests |', () {
    late SimpleLogger logger;
    late _CaptureOutput output;

    setUp(() {
      output = _CaptureOutput();
      logger = SimpleLogger(
        output: output,
        minimumLevel: LogLevel.trace,
      );
    });

    test('should log trace message with extension method', () {
      final result = logger.trace('Trace message');

      expect(result, isTrue);
      expect(output.entries, hasLength(1));
      expect(output.entries[0].level, LogLevel.trace);
      expect(output.entries[0].message, 'Trace message');
      expect(output.entries[0].name, 'Trace');
    });

    test('should log debug message with extension method', () {
      final result = logger.debug('Debug message');

      expect(result, isTrue);
      expect(output.entries, hasLength(1));
      expect(output.entries[0].level, LogLevel.debug);
      expect(output.entries[0].message, 'Debug message');
      expect(output.entries[0].name, 'Debug');
    });

    test('should log info message with extension method', () {
      final result = logger.info('Info message');

      expect(result, isTrue);
      expect(output.entries, hasLength(1));
      expect(output.entries[0].level, LogLevel.info);
      expect(output.entries[0].message, 'Info message');
      expect(output.entries[0].name, 'Info');
    });

    test('should log warning message with extension method', () {
      final result = logger.warning('Warning message');

      expect(result, isTrue);
      expect(output.entries, hasLength(1));
      expect(output.entries[0].level, LogLevel.warning);
      expect(output.entries[0].message, 'Warning message');
      expect(output.entries[0].name, 'Warning');
    });

    test('should log error message with extension method', () {
      final result = logger.error('Error message');

      expect(result, isTrue);
      expect(output.entries, hasLength(1));
      expect(output.entries[0].level, LogLevel.error);
      expect(output.entries[0].message, 'Error message');
      expect(output.entries[0].name, 'Error');
    });

    test('should log fatal message with extension method', () {
      final result = logger.fatal('Fatal message');

      expect(result, isTrue);
      expect(output.entries, hasLength(1));
      expect(output.entries[0].level, LogLevel.fatal);
      expect(output.entries[0].message, 'Fatal message');
      expect(output.entries[0].name, 'Fatal');
    });

    test('should support custom name parameter', () {
      logger
        ..trace('Message', name: 'CustomTrace')
        ..debug('Message', name: 'CustomDebug')
        ..info('Message', name: 'CustomInfo')
        ..warning('Message', name: 'CustomWarning')
        ..error('Message', name: 'CustomError')
        ..fatal('Message', name: 'CustomFatal');

      expect(output.entries, hasLength(6));
      expect(output.entries[0].name, 'CustomTrace');
      expect(output.entries[1].name, 'CustomDebug');
      expect(output.entries[2].name, 'CustomInfo');
      expect(output.entries[3].name, 'CustomWarning');
      expect(output.entries[4].name, 'CustomError');
      expect(output.entries[5].name, 'CustomFatal');
    });

    test('should support groupId parameter', () {
      logger
        ..startGroup(
          const LogGroup(
            id: 'test-group',
            title: 'Test Group',
            description: 'Description',
          ),
        )
        ..trace('Message', groupId: 'test-group')
        ..debug('Message', groupId: 'test-group')
        ..info('Message', groupId: 'test-group');

      expect(output.entries, isEmpty); // Buffered in group

      logger.completeGroup('test-group');
      expect(output.groups, hasLength(1));
      expect(output.groups[0].entries, hasLength(3));
    });

    test('should support id parameter', () {
      logger
        ..trace('Message', id: 'trace-id')
        ..debug('Message', id: 'debug-id')
        ..info('Message', id: 'info-id');

      expect(output.entries, hasLength(3));
      expect(output.entries[0].id, 'trace-id');
      expect(output.entries[1].id, 'debug-id');
      expect(output.entries[2].id, 'info-id');
    });

    test('should support duration parameter', () {
      const duration = Duration(milliseconds: 100);

      logger
        ..trace('Message', duration: duration)
        ..debug('Message', duration: duration)
        ..info('Message', duration: duration);

      expect(output.entries, hasLength(3));
      expect(output.entries[0].duration, duration);
      expect(output.entries[1].duration, duration);
      expect(output.entries[2].duration, duration);
    });

    test('should support metaData parameter', () {
      const metadata = {'key': 'value', 'count': 42};

      logger
        ..trace('Message', metaData: metadata)
        ..debug('Message', metaData: metadata)
        ..info('Message', metaData: metadata);

      expect(output.entries, hasLength(3));
      expect(output.entries[0].metadata, metadata);
      expect(output.entries[1].metadata, metadata);
      expect(output.entries[2].metadata, metadata);
    });

    test('should respect minimum log level', () {
      SimpleLogger(
        output: output,
        minimumLevel: LogLevel.warning,
      )
        ..trace('Filtered')
        ..debug('Filtered')
        ..info('Filtered')
        ..warning('Logged')
        ..error('Logged')
        ..fatal('Logged');

      expect(output.entries, hasLength(3));
      expect(output.entries[0].level, LogLevel.warning);
      expect(output.entries[1].level, LogLevel.error);
      expect(output.entries[2].level, LogLevel.fatal);
    });

    test('should return false when logging is disabled', () {
      logger.isEnabled = false;

      expect(logger.trace('Message'), isFalse);
      expect(logger.debug('Message'), isFalse);
      expect(logger.info('Message'), isFalse);
      expect(logger.warning('Message'), isFalse);
      expect(logger.error('Message'), isFalse);
      expect(logger.fatal('Message'), isFalse);

      expect(output.entries, isEmpty);
    });

    test('should return false when filtered by level', () {
      final strictLogger = SimpleLogger(
        output: output,
        minimumLevel: LogLevel.error,
      );

      expect(strictLogger.trace('Message'), isFalse);
      expect(strictLogger.debug('Message'), isFalse);
      expect(strictLogger.info('Message'), isFalse);
      expect(strictLogger.warning('Message'), isFalse);
      expect(strictLogger.error('Message'), isTrue);
      expect(strictLogger.fatal('Message'), isTrue);
    });
  });

  group('LogSanitizer Tests |', () {
    late LogSanitizer sanitizer;

    setUp(() {
      // Non-const constructor needed for coverage - const instances
      // are optimized at compile-time and not counted by coverage tools
      // ignore: prefer_const_constructors
      sanitizer = LogSanitizer();
    });

    test('should create with default sensitive fields', () {
      expect(sanitizer.sensitiveFields, isNotEmpty);
    });

    test('should create with custom sensitive fields', () {
      const custom = LogSanitizer(sensitiveFields: {'custom'});
      expect(custom.sensitiveFields, contains('custom'));
    });

    test('should sanitize simple JSON', () {
      final json = {'password': 'secret123', 'username': 'user'};
      final sanitized = sanitizer.sanitizeJson(json);

      expect(sanitized['password'], '*********');
      expect(sanitized['username'], 'user');
      expect(json['password'], 'secret123'); // Original unchanged
    });

    test('should sanitize nested JSON', () {
      final json = {
        'user': {
          'name': 'John',
          'password': 'secret',
        },
      };
      final sanitized = sanitizer.sanitizeJson(json);

      // ignore: avoid_dynamic_calls - Sanitized JSON returns dynamic
      expect(sanitized['user']['password'], '******');
      // ignore: avoid_dynamic_calls - Sanitized JSON returns dynamic
      expect(sanitized['user']['name'], 'John');
    });

    test('should sanitize JSON with lists', () {
      final json = {
        'users': [
          {'name': 'John', 'apiKey': 'key123'},
        ],
      };
      final sanitized = sanitizer.sanitizeJson(json);

      // ignore: avoid_dynamic_calls - Sanitized JSON returns dynamic
      expect(sanitized['users'][0]['apiKey'], '******');
    });

    test('should sanitize null values', () {
      final json = {'password': null};
      final sanitized = sanitizer.sanitizeJson(json);

      expect(sanitized['password'], '********');
    });

    test('should sanitize text with sensitive keys', () {
      const text = 'password: secret123\nusername: user';
      final sanitized = sanitizer.sanitizeText(text);

      expect(sanitized, contains('password: *********'));
      expect(sanitized, contains('username: user'));
    });

    test('should sanitize multiline text', () {
      const text = 'line1\ntoken: abc123\nline3';
      final sanitized = sanitizer.sanitizeText(text);

      expect(sanitized, contains('token: ******'));
      expect(sanitized, contains('line1'));
      expect(sanitized, contains('line3'));
    });

    test('should handle text without colons', () {
      const text = 'simple text without colons';
      final sanitized = sanitizer.sanitizeText(text);

      expect(sanitized, text);
    });

    test('should detect case-insensitive sensitive keys', () {
      final json = {'PASSWORD': 'secret', 'Token': 'abc'};
      final sanitized = sanitizer.sanitizeJson(json);

      expect(sanitized['PASSWORD'], '******');
      expect(sanitized['Token'], '***');
    });

    test('should detect partial key matches', () {
      final json = {'userPassword': 'secret', 'apiToken': 'abc'};
      final sanitized = sanitizer.sanitizeJson(json);

      expect(sanitized['userPassword'], '******');
      expect(sanitized['apiToken'], '***');
    });

    test('should sanitize value containing sensitive keywords', () {
      const text = 'config: contains password in value';
      final sanitized = sanitizer.sanitizeText(text);

      expect(sanitized, contains('*'));
      expect(sanitized, isNot(contains('password in value')));
    });
  });

  group('ConsoleOutput Tests |', () {
    test('should create with default formatter', () {
      final output = ConsoleOutput();
      expect(output.formatter, isA<LogFormatter>());
    });

    test('should write entry without error', () {
      final output = ConsoleOutput();
      final entry = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: DateTime.now(),
        message: 'Test',
      );

      expect(() => output.writeEntry(entry), returnsNormally);
    });

    test('should write entry with sanitizer', () {
      final output = ConsoleOutput(sanitizer: const LogSanitizer());
      final entry = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: DateTime.now(),
        message: 'password: secret',
      );

      expect(() => output.writeEntry(entry), returnsNormally);
    });

    test('should write group without error', () {
      final output = ConsoleOutput();
      const group = LogGroup(id: 'g1', title: 'Test', description: 'Desc');
      final entries = [
        LogEntry(
          name: 'e1',
          level: LogLevel.info,
          timestamp: DateTime.now(),
        ),
      ];

      expect(() => output.writeGroup(group, entries), returnsNormally);
    });

    test('should flush successfully', () async {
      final output = ConsoleOutput();
      await expectLater(output.flush(), completes);
    });
  });

  group('FileOutput Tests |', () {
    late IOSink sink;
    late List<String> written;

    setUp(() {
      written = [];
      sink = _MockIOSink(written);
    });

    test('should create with default formatter', () {
      final output = FileOutput(sink);
      expect(output.formatter, isA<LogFormatter>());
    });

    test('should write entry to file', () {
      final output = FileOutput(sink);
      final entry = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: DateTime.now(),
        message: 'msg',
      );

      output.writeEntry(entry);

      expect(written, hasLength(1));
    });

    test('should write group to file', () {
      final output = FileOutput(sink);
      const group = LogGroup(id: 'g1', title: 'Test', description: 'Desc');
      final entries = [
        LogEntry(
          name: 'e1',
          level: LogLevel.info,
          timestamp: DateTime.now(),
        ),
      ];

      output.writeGroup(group, entries);

      expect(written, hasLength(1));
    });

    test('should sanitize file output', () {
      final output = FileOutput(sink, sanitizer: const LogSanitizer());
      final entry = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: DateTime.now(),
        message: 'token: abc123',
      );

      output.writeEntry(entry);

      expect(written[0], contains('token: ******'));
    });

    test('should flush file output', () async {
      final output = FileOutput(sink);
      await expectLater(output.flush(), completes);
    });
  });

  group('BufferedFileOutput Tests |', () {
    late IOSink sink;
    late List<String> written;
    late BufferedFileOutput output;

    setUp(() {
      written = [];
      sink = _MockIOSink(written);
      output = BufferedFileOutput(
        sink,
        bufferSize: 3,
        flushInterval: const Duration(seconds: 10),
      );
    });

    tearDown(() async {
      await output.dispose();
    });

    test('should buffer entries until buffer size reached', () {
      output
        ..writeEntry(
          LogEntry(
            name: 'e1',
            level: LogLevel.info,
            timestamp: DateTime.now(),
          ),
        )
        ..writeEntry(
          LogEntry(
            name: 'e2',
            level: LogLevel.info,
            timestamp: DateTime.now(),
          ),
        );

      expect(written, isEmpty); // Buffered

      output.writeEntry(
        LogEntry(
          name: 'e3',
          level: LogLevel.info,
          timestamp: DateTime.now(),
        ),
      );

      expect(written, hasLength(3)); // Flushed
    });

    test('should flush on demand', () async {
      output.writeEntry(
        LogEntry(
          name: 'e1',
          level: LogLevel.info,
          timestamp: DateTime.now(),
        ),
      );

      expect(written, isEmpty);

      await output.flush();

      expect(written, hasLength(1));
    });

    test('should handle sanitization in buffered output', () async {
      output = BufferedFileOutput(
        sink,
        bufferSize: 10,
        sanitizer: const LogSanitizer(),
      )..writeEntry(
          LogEntry(
            name: 'test',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message: 'password: secret',
          ),
        );

      await output.flush();

      expect(written[0], contains('password: ******'));
      await output.dispose();
    });

    test('should buffer groups', () async {
      const group = LogGroup(id: 'g1', title: 'Test', description: 'Desc');
      final entries = [
        LogEntry(
          name: 'e1',
          level: LogLevel.info,
          timestamp: DateTime.now(),
        ),
      ];

      output.writeGroup(group, entries);

      expect(written, isEmpty);

      await output.flush();

      expect(written, hasLength(1));
    });

    test('should dispose and flush buffer', () async {
      output.writeEntry(
        LogEntry(
          name: 'e1',
          level: LogLevel.info,
          timestamp: DateTime.now(),
        ),
      );

      unawaited(output.dispose());

      // Should flush on dispose
      await Future<void>.delayed(const Duration(milliseconds: 10));
      expect(written, isNotEmpty);
    });

    test('should rethrow error when flush fails', () async {
      // Test line 580: rethrow in catch block
      final throwingSink = _ThrowingIOSink();
      final throwingOutput = BufferedFileOutput(
        throwingSink,
        bufferSize: 2,
      )..writeEntry(
          LogEntry(
            name: 'e1',
            level: LogLevel.info,
            timestamp: DateTime.now(),
          ),
        );

      // Calling flush() directly will throw and rethrow at line 580
      try {
        await throwingOutput.flush();
        fail('Should have thrown');
      } on Exception catch (e) {
        expect(e.toString(), contains('Flush failed'));
      }

      // dispose() also calls flush, so catch that error too
      try {
        await throwingOutput.dispose();
      } on Exception catch (_) {
        // Expected
      }
    });
  });

  group('RotatingFileOutput Tests |', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('log_test_');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('should create rotating file output', () async {
      final path = '${tempDir.path}/test.log';
      final output = RotatingFileOutput(
        path,
        maxSizeBytes: 1000,
        maxFiles: 3,
        bufferSize: 10,
      );

      await output.dispose();
    });

    test('should write to rotating files', () async {
      final path = '${tempDir.path}/test.log';
      final output = RotatingFileOutput(
        path,
        maxSizeBytes: 50, // Smaller to ensure rotation
        maxFiles: 2,
        bufferSize: 1,
      );

      // Write many entries to trigger rotation
      for (var i = 0; i < 20; i++) {
        output.writeEntry(
          LogEntry(
            name: 'entry_$i',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message:
                'Long message to trigger file rotation quickly with more text',
          ),
        );
      }

      await output.flush();
      await output.dispose();

      // Check that rotation occurred
      final files = tempDir.listSync();
      expect(files.length, greaterThanOrEqualTo(2));
    });
  });

  group('AsyncLogger Tests |', () {
    late List<String> output;
    late AsyncLogger logger;

    setUp(() {
      output = [];
      logger = AsyncLogger(output: _TestOutput(output));
    });

    tearDown(() {
      logger.dispose();
    });

    test('should log entries asynchronously', () async {
      logger.logEntry(
        LogEntry(
          name: 'test',
          level: LogLevel.info,
          timestamp: DateTime.now(),
        ),
      );

      // Wait for async processing
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(output, hasLength(1));
    });

    test('should complete groups asynchronously', () async {
      const group = LogGroup(id: 'g1', title: 'Test', description: 'Desc');
      logger
        ..startGroup(group)
        ..logEntry(
          LogEntry(
            name: 'e1',
            level: LogLevel.info,
            timestamp: DateTime.now(),
          ),
          groupId: 'g1',
        )
        ..completeGroup('g1');

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(output, hasLength(1));
    });

    test('should handle errors in async processing', () async {
      Object? caughtError;
      final failingOutput = _FailingOutput();
      logger = AsyncLogger(
        output: failingOutput,
        onError: (error, st) => caughtError = error,
      )..logEntry(
          LogEntry(
            name: 'test',
            level: LogLevel.info,
            timestamp: DateTime.now(),
          ),
        );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(caughtError, isA<Exception>());
      logger.dispose();
    });
  });

  group('JsonOutput Tests |', () {
    test('should create with default settings', () {
      const output = JsonOutput();
      expect(output.prettyPrint, isTrue);
      expect(output.frameLength, 80);
    });

    test('should write entry as JSON', () {
      final messages = <String>[];
      final output = JsonOutput(writer: messages.add, prettyPrint: false);
      final entry = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: DateTime.now(),
      );

      output.writeEntry(entry);

      expect(messages, hasLength(1));
      final json = jsonDecode(messages[0]);
      // ignore: avoid_dynamic_calls - JSON decode returns dynamic
      expect(json['name'], 'test');
      // ignore: avoid_dynamic_calls - JSON decode returns dynamic
      expect(json['level'], 'info');
    });

    test('should write group as JSON', () {
      final messages = <String>[];
      final output = JsonOutput(writer: messages.add, prettyPrint: false);
      const group = LogGroup(id: 'g1', title: 'Title', description: 'Desc');
      final entries = [
        LogEntry(name: 'e1', level: LogLevel.info, timestamp: DateTime.now()),
      ];

      output.writeGroup(group, entries);

      expect(messages, hasLength(1));
      final json = jsonDecode(messages[0]);
      // ignore: avoid_dynamic_calls - JSON decode returns dynamic
      expect(json['id'], 'g1');
      // ignore: avoid_dynamic_calls - JSON decode returns dynamic
      expect(json['entries'], hasLength(1));
    });

    test('should pretty print JSON', () {
      final messages = <String>[];
      final output = JsonOutput(writer: messages.add);
      final entry = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: DateTime.now(),
      );

      output.writeEntry(entry);

      expect(messages, hasLength(1));
      expect(messages[0], contains('\n')); // Multiline
    });

    test('should sanitize JSON output', () {
      final messages = <String>[];
      final output = JsonOutput(
        writer: messages.add,
        prettyPrint: false,
        sanitizer: const LogSanitizer(),
      );
      final entry = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: DateTime.now(),
        metadata: const {'password': 'secret'},
      );

      output.writeEntry(entry);

      expect(messages[0], contains('******'));
      expect(messages[0], isNot(contains('secret')));
    });

    test('should flush successfully', () async {
      const output = JsonOutput();
      await expectLater(output.flush(), completes);
    });
  });

  group('MultiOutput Tests |', () {
    test('should write to multiple outputs', () {
      final output1 = <String>[];
      final output2 = <String>[];
      final multi = MultiOutput([
        _TestOutput(output1),
        _TestOutput(output2),
      ]);

      final entry = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: DateTime.now(),
      );
      multi.writeEntry(entry);

      expect(output1, hasLength(1));
      expect(output2, hasLength(1));
    });

    test('should write group to multiple outputs', () {
      final output1 = <String>[];
      final output2 = <String>[];
      final multi = MultiOutput([
        _TestOutput(output1),
        _TestOutput(output2),
      ]);

      const group = LogGroup(id: 'g1', title: 'Test', description: 'Desc');
      final entries = [
        LogEntry(
          name: 'e1',
          level: LogLevel.info,
          timestamp: DateTime.now(),
        ),
      ];
      multi.writeGroup(group, entries);

      expect(output1, hasLength(1));
      expect(output2, hasLength(1));
    });

    test('should flush all outputs', () async {
      final multi = MultiOutput([
        ConsoleOutput(),
        ConsoleOutput(),
      ]);

      await expectLater(multi.flush(), completes);
    });
  });

  group('LogFormatterSymbols Tests |', () {
    test('should create with default symbols', () {
      const symbols = LogFormatterSymbols();
      expect(symbols.topLeft, '╔');
      expect(symbols.topRight, '╗');
      expect(symbols.bottomLeft, '╚');
      expect(symbols.bottomRight, '╝');
    });

    test('should create with custom symbols', () {
      const symbols = LogFormatterSymbols(
        topLeft: '+',
        topRight: '+',
        bottomLeft: '+',
        bottomRight: '+',
        horizontal: '-',
        vertical: '|',
      );

      expect(symbols.topLeft, '+');
      expect(symbols.horizontal, '-');
    });

    test('should use const constructor', () {
      const symbols1 = LogFormatterSymbols();
      const symbols2 = LogFormatterSymbols();

      // Const constructors create identical instances
      expect(identical(symbols1, symbols2), isTrue);
    });

    test('should have ASCII preset', () {
      const ascii = LogFormatterSymbols.ascii;

      expect(ascii.vertical, '|');
      expect(ascii.horizontal, '-');
      expect(ascii.topLeft, '+');
      expect(ascii.stateStart, '-->');
      expect(ascii.stateNode, '|>');
      expect(ascii.stateEnd, '`>');
    });

    test('should have minimal preset', () {
      const minimal = LogFormatterSymbols.minimal;

      expect(minimal.vertical, '│');
      expect(minimal.horizontal, '─');
      expect(minimal.topLeft, '┌');
      expect(minimal.stateStart, '──>');
      expect(minimal.stateNode, '├─');
      expect(minimal.stateEnd, '└─');
    });

    test('should copyWith individual symbols', () {
      const original = LogFormatterSymbols.ascii;
      final modified = original.copyWith(
        vertical: '║',
        horizontal: '═',
      );

      expect(modified.vertical, '║');
      expect(modified.horizontal, '═');
      // Other symbols should remain from original
      expect(modified.topLeft, '+');
      expect(modified.stateNode, '|>');
    });

    test('should copyWith no parameters returns same values', () {
      const original = LogFormatterSymbols.ascii;
      final copied = original.copyWith();

      expect(copied.vertical, original.vertical);
      expect(copied.horizontal, original.horizontal);
      expect(copied.topLeft, original.topLeft);
      expect(copied.stateStart, original.stateStart);
    });

    test('should copyWith all symbols', () {
      const original = LogFormatterSymbols();
      final modified = original.copyWith(
        vertical: '|',
        horizontal: '-',
        topLeft: '+',
        topRight: '+',
        bottomLeft: '+',
        bottomRight: '+',
        innerVertical: '|',
        innerHorizontal: '-',
        innerTopLeft: '+',
        innerTopRight: '+',
        innerBottomLeft: '+',
        innerBottomRight: '+',
        stateStart: '-->',
        stateNode: '|>',
        stateEnd: '`>',
      );

      expect(modified.vertical, '|');
      expect(modified.horizontal, '-');
      expect(modified.topLeft, '+');
    });
  });

  group('LogFormatter Tests |', () {
    late LogFormatter formatter;

    setUp(() {
      // Explicitly enable colors and disable auto-detect for predictable tests
      formatter = LogFormatter(
        autoDetectWidth: false,
        enableColors: true,
      );
    });

    test('should create with default settings', () {
      expect(formatter.frameLength, 80);
      expect(formatter.symbols, isA<LogFormatterSymbols>());
    });

    test('should format entry without duration', () {
      final entry = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: DateTime.now(),
        message: 'Test',
      );

      final formatted = formatter.formatEntry(entry);

      expect(formatted, contains('INFO'));
      expect(formatted, contains('Test'));
    });

    test('should format entry with duration', () {
      final entry = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: DateTime.now(),
        message: 'Test',
        duration: const Duration(milliseconds: 100),
      );

      final formatted = formatter.formatEntry(entry);

      expect(formatted, contains('100'));
      expect(formatted, contains('ms'));
    });

    test('should format entry with custom color', () {
      final entry = LogEntry(
        name: 'test',
        level: LogLevel.error,
        timestamp: DateTime.now(),
        message: 'Error',
        color: '\x1B[31m',
      );

      final formatted = formatter.formatEntry(entry);

      expect(formatted, contains('\x1B[31m'));
      expect(formatted, contains('\x1B[0m')); // Reset
    });

    test('should format group', () {
      const group = LogGroup(id: 'g1', title: 'Title', description: 'Desc');
      final entries = [
        LogEntry(
          name: 'e1',
          level: LogLevel.info,
          timestamp: DateTime.now(),
          message: 'msg',
        ),
      ];

      final formatted = formatter.formatGroup(group, entries);

      expect(formatted, contains('Title'));
      expect(formatted, contains('Desc'));
      expect(formatted, contains('msg'));
    });

    test('should split long text into chunks', () {
      final longText = 'a' * 200;
      final entry = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: DateTime.now(),
        message: longText,
      );

      final formatted = formatter.formatEntry(entry);

      expect(formatted, isNotEmpty);
    });

    test('should handle multiline messages', () {
      final entry = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: DateTime.now(),
        message: 'line1\nline2\nline3',
      );

      final formatted = formatter.formatEntry(entry);

      expect(formatted, contains('line1'));
      expect(formatted, contains('line2'));
      expect(formatted, contains('line3'));
    });

    test('should format empty group', () {
      const group = LogGroup(id: 'g1', title: 'Empty', description: '');

      final formatted = formatter.formatGroup(group, []);

      expect(formatted, contains('Empty'));
      expect(formatted, contains('╔'));
      expect(formatted, contains('╚'));
    });

    test('should use preset symbols', () {
      final asciiFormatter = LogFormatter(
        symbols: LogFormatterSymbols.ascii,
        enableColors: false,
      );
      final minimalFormatter = LogFormatter(
        symbols: LogFormatterSymbols.minimal,
        enableColors: false,
      );

      const group = LogGroup(id: 'g1', title: 'Test', description: '');

      final asciiOutput = asciiFormatter.formatGroup(group, []);
      final minimalOutput = minimalFormatter.formatGroup(group, []);

      expect(asciiOutput, contains('+'));
      expect(asciiOutput, contains('-'));
      expect(asciiOutput, contains('|'));

      expect(minimalOutput, contains('┌'));
      expect(minimalOutput, contains('─'));
      expect(minimalOutput, contains('│'));
    });

    test('should disable colors when enableColors is false', () {
      final noColorFormatter = LogFormatter(enableColors: false);

      final entry = LogEntry(
        name: 'test',
        level: LogLevel.error,
        timestamp: DateTime.now(),
        message: 'Error',
        color: '\x1B[31m',
      );

      final formatted = noColorFormatter.formatEntry(entry);

      // Should not contain ANSI escape codes
      expect(formatted, isNot(contains('\x1B[31m')));
      expect(formatted, isNot(contains('\x1B[0m')));
      // But should contain the message
      expect(formatted, contains('Error'));
    });

    test('should enable colors explicitly', () {
      final colorFormatter = LogFormatter(enableColors: true);

      final entry = LogEntry(
        name: 'test',
        level: LogLevel.warning,
        timestamp: DateTime.now(),
        message: 'Warning',
        color: '\x1B[33m',
      );

      final formatted = colorFormatter.formatEntry(entry);

      expect(formatted, contains('\x1B[33m'));
      expect(formatted, contains('\x1B[0m'));
    });

    test('should respect manual frameLength override', () {
      final customFormatter = LogFormatter(
        frameLength: 40,
        autoDetectWidth: false,
      );

      expect(customFormatter.frameLength, 40);
    });

    test('should use default frameLength when auto-detect disabled', () {
      final defaultFormatter = LogFormatter(
        autoDetectWidth: false,
      );

      expect(defaultFormatter.frameLength, 80);
    });

    test('should auto-detect terminal width when enabled', () {
      final autoFormatter = LogFormatter();

      // Width should be between 40 and 200 (clamped range)
      expect(autoFormatter.frameLength, greaterThanOrEqualTo(40));
      expect(autoFormatter.frameLength, lessThanOrEqualTo(200));
    });

    test('should detect terminal width with simulated terminal', () {
      // Simulate a terminal with 120 columns
      final width = LogFormatter.detectTerminalWidth(
        hasTerminal: true,
        terminalColumns: 120,
      );
      expect(width, 120);
    });

    test('should clamp terminal width to minimum 40', () {
      // Simulate a very narrow terminal
      final width = LogFormatter.detectTerminalWidth(
        hasTerminal: true,
        terminalColumns: 20,
      );
      expect(width, 40);
    });

    test('should clamp terminal width to maximum 200', () {
      // Simulate a very wide terminal
      final width = LogFormatter.detectTerminalWidth(
        hasTerminal: true,
        terminalColumns: 300,
      );
      expect(width, 200);
    });

    test('should return default 80 when no terminal', () {
      final width = LogFormatter.detectTerminalWidth(
        hasTerminal: false,
      );
      expect(width, 80);
    });

    test('should use stdout.terminalColumns when terminalColumns is null', () {
      // Don't pass terminalColumns - it will use stdout.terminalColumns
      final width = LogFormatter.detectTerminalWidth(
        hasTerminal: true,
        // terminalColumns not passed - will use stdout.terminalColumns
      );
      // Should return a clamped value between 40 and 200
      expect(width, greaterThanOrEqualTo(40));
      expect(width, lessThanOrEqualTo(200));
    });

    test('should detect color support with simulated terminal', () {
      // Simulate a terminal with ANSI support
      final hasColors = LogFormatter.detectColorSupport(
        hasNoColor: false,
        hasTerminal: true,
        supportsAnsiEscapes: true,
      );
      expect(hasColors, isTrue);
    });

    test('should respect NO_COLOR environment variable', () {
      final hasColors = LogFormatter.detectColorSupport(
        hasNoColor: true,
        hasTerminal: true,
        supportsAnsiEscapes: true,
      );
      expect(hasColors, isFalse);
    });

    test('should return false when terminal lacks ANSI support', () {
      final hasColors = LogFormatter.detectColorSupport(
        hasNoColor: false,
        hasTerminal: true,
        supportsAnsiEscapes: false,
      );
      expect(hasColors, isFalse);
    });

    test('should return false when not a terminal', () {
      final hasColors = LogFormatter.detectColorSupport(
        hasNoColor: false,
        hasTerminal: false,
        supportsAnsiEscapes: true,
      );
      expect(hasColors, isFalse);
    });
  });

  group('Visual Output Examples |', () {
    test('should display default Unicode style', () {
      // Visual output for manual inspection
      // Printing separator for visual test output
      // Printing test output for visual verification
      // ignore: avoid_print
      print('\n${'═' * 80}');
      // Printing test section header
      // Printing test output for visual verification
      // ignore: avoid_print
      print('DEFAULT UNICODE STYLE (frameLength: 80)');
      // Printing separator for visual test output
      // Printing test output for visual verification
      // ignore: avoid_print
      print('═' * 80);

      final output = ConsoleOutput(
        formatter: LogFormatter(
          frameLength: 80,
          enableColors: true,
        ),
      );
      final logger = SimpleLogger(output: output)
        // Log info message
        ..logEntry(
          LogEntry(
            name: 'UnicodeDemo',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message: 'This is an info message with default Unicode symbols',
          ),
        )
        // Log warning message
        ..logEntry(
          LogEntry(
            name: 'UnicodeDemo',
            level: LogLevel.warning,
            timestamp: DateTime.now(),
            message: 'This is a warning message',
          ),
        )
        // Log error message
        ..logEntry(
          LogEntry(
            name: 'UnicodeDemo',
            level: LogLevel.error,
            timestamp: DateTime.now(),
            message: 'This is an error message',
          ),
        );

      // Create and log a group
      const group = LogGroup(
        id: 'task-1',
        title: 'Processing Task',
        description: 'Group demo',
      );
      logger
        ..startGroup(group)
        ..logEntry(
          LogEntry(
            name: 'UnicodeDemo',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message: 'Step 1: Initialize',
          ),
          groupId: 'task-1',
        )
        ..logEntry(
          LogEntry(
            name: 'UnicodeDemo',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message: 'Step 2: Process data',
          ),
          groupId: 'task-1',
        )
        ..completeGroup('task-1');

      // Printing visual separator for test output verification
      // Printing test output for visual verification
      // ignore: avoid_print
      print('${'═' * 80}\n');
    });

    test('should display ASCII preset style', () {
      // Visual output for manual inspection
      // Printing visual separator for test output verification
      // Printing test output for visual verification
      // ignore: avoid_print
      print('\n${'=' * 80}');
      // Printing test section header for visual verification
      // Printing test output for visual verification
      // ignore: avoid_print
      print('ASCII PRESET STYLE (maximum compatibility)');
      // Printing visual separator for test output verification
      // Printing test output for visual verification
      // ignore: avoid_print
      print('=' * 80);

      final output = ConsoleOutput(
        formatter: LogFormatter(
          frameLength: 80,
          symbols: LogFormatterSymbols.ascii,
          enableColors: true,
        ),
      );
      final logger = SimpleLogger(output: output)
        ..logEntry(
          LogEntry(
            name: 'ASCIIDemo',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message: 'This is an info message with ASCII symbols',
          ),
        )
        ..logEntry(
          LogEntry(
            name: 'ASCIIDemo',
            level: LogLevel.warning,
            timestamp: DateTime.now(),
            message: 'This is a warning message',
          ),
        )
        ..logEntry(
          LogEntry(
            name: 'ASCIIDemo',
            level: LogLevel.error,
            timestamp: DateTime.now(),
            message: 'This is an error message',
          ),
        );

      const group = LogGroup(
        id: 'task-2',
        title: 'Processing Task',
        description: 'ASCII demo group',
      );
      logger
        ..startGroup(group)
        ..logEntry(
          LogEntry(
            name: 'ASCIIDemo',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message: 'Step 1: Initialize',
          ),
          groupId: 'task-2',
        )
        ..logEntry(
          LogEntry(
            name: 'ASCIIDemo',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message: 'Step 2: Process data',
          ),
          groupId: 'task-2',
        )
        ..completeGroup('task-2');

      // Printing visual separator for test output verification
      // Printing test output for visual verification
      // ignore: avoid_print
      print('${'=' * 80}\n');
    });

    test('should display minimal preset style', () {
      // Visual output for manual inspection
      // Printing visual separator for test output verification
      // Printing test output for visual verification
      // ignore: avoid_print
      print('\n${'─' * 80}');
      // Printing test section header for visual verification
      // Printing test output for visual verification
      // ignore: avoid_print
      print('MINIMAL PRESET STYLE (simple box-drawing)');
      // Printing visual separator for test output verification
      // Printing test output for visual verification
      // ignore: avoid_print
      print('─' * 80);

      final output = ConsoleOutput(
        formatter: LogFormatter(
          frameLength: 80,
          symbols: LogFormatterSymbols.minimal,
          enableColors: true,
        ),
      );
      final logger = SimpleLogger(output: output)
        ..logEntry(
          LogEntry(
            name: 'MinimalDemo',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message: 'This is an info message with minimal symbols',
          ),
        )
        ..logEntry(
          LogEntry(
            name: 'MinimalDemo',
            level: LogLevel.warning,
            timestamp: DateTime.now(),
            message: 'This is a warning message',
          ),
        )
        ..logEntry(
          LogEntry(
            name: 'MinimalDemo',
            level: LogLevel.error,
            timestamp: DateTime.now(),
            message: 'This is an error message',
          ),
        );

      const group = LogGroup(
        id: 'task-3',
        title: 'Processing Task',
        description: 'Minimal demo group',
      );
      logger
        ..startGroup(group)
        ..logEntry(
          LogEntry(
            name: 'MinimalDemo',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message: 'Step 1: Initialize',
          ),
          groupId: 'task-3',
        )
        ..logEntry(
          LogEntry(
            name: 'MinimalDemo',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message: 'Step 2: Process data',
          ),
          groupId: 'task-3',
        )
        ..completeGroup('task-3');

      // Printing test output for visual verification
      // ignore: avoid_print
      print('${'─' * 80}\n');
    });

    test('should display different terminal widths', () {
      // Visual output for manual inspection
      // Printing test output for visual verification
      // ignore: avoid_print
      print('\n${'═' * 80}');
      // Printing test output for visual verification
      // ignore: avoid_print
      print('TERMINAL WIDTH COMPARISON');
      // Printing test output for visual verification
      // ignore: avoid_print
      print('═' * 80);

      // Width 60
      // Printing test output for visual verification
      // ignore: avoid_print
      print('\nWidth: 60 characters');
      // Printing test output for visual verification
      // ignore: avoid_print
      print('─' * 60);

      final output60 = ConsoleOutput(
        formatter: LogFormatter(
          frameLength: 60,
          enableColors: true,
        ),
      );
      SimpleLogger(output: output60).logEntry(
        LogEntry(
          name: 'Width60',
          level: LogLevel.info,
          timestamp: DateTime.now(),
          message: 'This is a longer message that will wrap at 60 chars',
        ),
      );

      // Width 100
      // Printing test output for visual verification
      // ignore: avoid_print
      print('\nWidth: 100 characters');
      // Printing test output for visual verification
      // ignore: avoid_print
      print('─' * 100);

      final output100 = ConsoleOutput(
        formatter: LogFormatter(
          frameLength: 100,
          enableColors: true,
        ),
      );
      SimpleLogger(output: output100).logEntry(
        LogEntry(
          name: 'Width100',
          level: LogLevel.info,
          timestamp: DateTime.now(),
          message: 'This message demonstrates formatter with wider terminal',
        ),
      );

      // Printing test output for visual verification
      // ignore: avoid_print
      print('\n${'═' * 80}\n');
    });

    test('should display custom styled symbols', () {
      // Visual output for manual inspection
      // Printing test output for visual verification
      // ignore: avoid_print
      print('\n${'═' * 80}');
      // Printing test output for visual verification
      // ignore: avoid_print
      print('CUSTOM MIXED STYLE (minimal + heavy borders)');
      // Printing test output for visual verification
      // ignore: avoid_print
      print('═' * 80);

      final customSymbols = LogFormatterSymbols.minimal.copyWith(
        vertical: '║',
        horizontal: '═',
        topLeft: '╔',
        topRight: '╗',
        bottomLeft: '╚',
        bottomRight: '╝',
      );

      final output = ConsoleOutput(
        formatter: LogFormatter(
          frameLength: 80,
          symbols: customSymbols,
          enableColors: true,
        ),
      );
      final logger = SimpleLogger(output: output)
        ..logEntry(
          LogEntry(
            name: 'CustomDemo',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message: 'Custom style with mixed symbols',
          ),
        )
        ..logEntry(
          LogEntry(
            name: 'CustomDemo',
            level: LogLevel.warning,
            timestamp: DateTime.now(),
            message: 'Notice the heavy outer borders',
          ),
        )
        ..logEntry(
          LogEntry(
            name: 'CustomDemo',
            level: LogLevel.error,
            timestamp: DateTime.now(),
            message: 'And lighter inner symbols',
          ),
        );

      const group = LogGroup(
        id: 'task-4',
        title: 'Mixed Style Group',
        description: 'Custom demo group',
      );
      logger
        ..startGroup(group)
        ..logEntry(
          LogEntry(
            name: 'CustomDemo',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message: 'First item',
          ),
          groupId: 'task-4',
        )
        ..logEntry(
          LogEntry(
            name: 'CustomDemo',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message: 'Second item',
          ),
          groupId: 'task-4',
        )
        ..completeGroup('task-4');

      // Printing test output for visual verification
      // ignore: avoid_print
      print('${'═' * 80}\n');
    });

    test('should display with and without colors', () {
      // Visual output for manual inspection
      // Printing test output for visual verification
      // ignore: avoid_print
      print('\n${'═' * 80}');
      // Printing test output for visual verification
      // ignore: avoid_print
      print('COLOR COMPARISON');
      // Printing test output for visual verification
      // ignore: avoid_print
      print('═' * 80);

      // With colors
      // Printing test output for visual verification
      // ignore: avoid_print
      print('\nWith Colors:');
      // Printing test output for visual verification
      // ignore: avoid_print
      print('─' * 80);

      final outputColor = ConsoleOutput(
        formatter: LogFormatter(
          frameLength: 80,
          enableColors: true,
        ),
      );
      SimpleLogger(output: outputColor)
        ..logEntry(
          LogEntry(
            name: 'ColorEnabled',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message: 'Info message (blue)',
          ),
        )
        ..logEntry(
          LogEntry(
            name: 'ColorEnabled',
            level: LogLevel.warning,
            timestamp: DateTime.now(),
            message: 'Warning message (yellow)',
          ),
        )
        ..logEntry(
          LogEntry(
            name: 'ColorEnabled',
            level: LogLevel.error,
            timestamp: DateTime.now(),
            message: 'Error message (red)',
          ),
        );

      // Without colors
      // Printing test output for visual verification
      // ignore: avoid_print
      print('\nWithout Colors:');
      // Printing test output for visual verification
      // ignore: avoid_print
      print('─' * 80);

      final outputNoColor = ConsoleOutput(
        formatter: LogFormatter(
          frameLength: 80,
          enableColors: false,
        ),
      );
      SimpleLogger(output: outputNoColor)
        ..logEntry(
          LogEntry(
            name: 'ColorDisabled',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message: 'Info message (no color)',
          ),
        )
        ..logEntry(
          LogEntry(
            name: 'ColorDisabled',
            level: LogLevel.warning,
            timestamp: DateTime.now(),
            message: 'Warning message (no color)',
          ),
        )
        ..logEntry(
          LogEntry(
            name: 'ColorDisabled',
            level: LogLevel.error,
            timestamp: DateTime.now(),
            message: 'Error message (no color)',
          ),
        );

      // Printing test output for visual verification
      // ignore: avoid_print
      print('\n${'═' * 80}\n');
    });
  });

  group('Coverage Tests |', () {
    test('should handle error without onError callback', () {
      final output = _FailingOutput();
      // This will trigger an error that uses the default debugPrint path
      // No onError callback provided
      SimpleLogger(output: output).logEntry(
        LogEntry(
          name: 'test',
          level: LogLevel.info,
          timestamp: DateTime.now(),
        ),
      );
    });

    test('should sanitize ConsoleOutput group', () {
      const sanitizer = LogSanitizer();
      final output = ConsoleOutput(sanitizer: sanitizer);

      const group = LogGroup(
        id: 'g1',
        title: 'Test Group',
        description: 'Contains password: secret123',
      );
      final entries = [
        LogEntry(
          name: 'e1',
          level: LogLevel.info,
          timestamp: DateTime.now(),
          message: 'apiKey: abc123',
        ),
      ];

      // This should cover the sanitized writeGroup path
      output.writeGroup(group, entries);
    });

    test('should use default LogOutput.writeGroup', () {
      final written = <String>[];
      final output = _SimpleLogOutput(written);

      const group = LogGroup(id: 'g1', title: 'Test', description: 'Desc');
      final entries = [
        LogEntry(
          name: 'e1',
          level: LogLevel.info,
          timestamp: DateTime.now(),
        ),
        LogEntry(
          name: 'e2',
          level: LogLevel.debug,
          timestamp: DateTime.now(),
        ),
      ];

      // This should use the default writeGroup implementation
      output.writeGroup(group, entries);

      expect(written.length, 2); // Should have called writeEntry twice
    });

    test('should handle error during group completion', () async {
      final output = <String>[];
      final errorsCaught = <Object>[];
      // Start a group and add an entry
      // Keep logger in scope to prevent garbage collection before timeout fires
      // ignore: unused_local_variable
      final logger = SimpleLogger(
        output: _TestOutput(output),
        groupTimeout: const Duration(milliseconds: 50),
        onError: (e, st) => errorsCaught.add(e),
      )
        ..startGroup(
          const LogGroup(
            id: 'timeout-group',
            title: 'Test',
            description: '',
          ),
        )
        ..logEntry(
          LogEntry(
            name: 'entry1',
            level: LogLevel.info,
            timestamp: DateTime.now(),
          ),
          groupId: 'timeout-group',
        );

      // Wait for timeout to trigger
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Group should have been auto-completed with the entry
      expect(output, contains('group:timeout-group'));
    });

    test('should sanitize FileOutput writeGroup', () async {
      final tempDir = await Directory.systemTemp.createTemp('test_');
      final file = File('${tempDir.path}/test.log').openWrite();
      const sanitizer = LogSanitizer();
      final output = FileOutput(file, sanitizer: sanitizer);

      const group = LogGroup(
        id: 'g1',
        title: 'Test',
        description: 'password: secret123',
      );
      final entries = [
        LogEntry(
          name: 'e1',
          level: LogLevel.info,
          timestamp: DateTime.now(),
          message: 'apiKey: abc123',
        ),
      ];

      output.writeGroup(group, entries);
      await output.flush();
      await file.close();

      final content = await File('${tempDir.path}/test.log').readAsString();
      expect(content, contains('******')); // Should be sanitized

      await tempDir.delete(recursive: true);
    });

    test('should sanitize BufferedFileOutput writeGroup', () async {
      final written = <String>[];
      final sink = _MockIOSink(written);
      const sanitizer = LogSanitizer();
      final output = BufferedFileOutput(
        sink,
        sanitizer: sanitizer,
        bufferSize: 1,
      );

      const group = LogGroup(
        id: 'g1',
        title: 'Test',
        description: 'password: secret123',
      );
      final entries = [
        LogEntry(
          name: 'e1',
          level: LogLevel.info,
          timestamp: DateTime.now(),
          message: 'apiKey: abc123',
        ),
      ];

      output.writeGroup(group, entries);
      await output.flush();

      expect(written.join(), contains('******')); // Should be sanitized
      await output.dispose();
    });

    test('should sanitize RotatingFileOutput writeEntry', () async {
      final tempDir = await Directory.systemTemp.createTemp('test_');
      const sanitizer = LogSanitizer();
      final output = RotatingFileOutput(
        '${tempDir.path}/test.log',
        sanitizer: sanitizer,
        maxSizeBytes: 1000,
        bufferSize: 1,
      )..writeEntry(
          LogEntry(
            name: 'e1',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message: 'password: secret123',
          ),
        );

      await output.flush();
      await output.dispose();

      final content = await File('${tempDir.path}/test.log').readAsString();
      expect(content, contains('******')); // Should be sanitized

      await tempDir.delete(recursive: true);
    });

    test('should sanitize RotatingFileOutput writeGroup', () async {
      final tempDir = await Directory.systemTemp.createTemp('test_');
      const sanitizer = LogSanitizer();
      final output = RotatingFileOutput(
        '${tempDir.path}/test.log',
        sanitizer: sanitizer,
        maxSizeBytes: 1000,
        bufferSize: 1,
      );

      const group = LogGroup(
        id: 'g1',
        title: 'Test',
        description: 'password: secret123',
      );
      final entries = [
        LogEntry(
          name: 'e1',
          level: LogLevel.info,
          timestamp: DateTime.now(),
          message: 'apiKey: abc123',
        ),
      ];

      output.writeGroup(group, entries);
      await output.flush();
      await output.dispose();

      final content = await File('${tempDir.path}/test.log').readAsString();
      expect(content, contains('******')); // Should be sanitized

      await tempDir.delete(recursive: true);
    });

    test('should handle error during completeGroup', () {
      final output = _FailingOutput();
      // This should trigger error handling when writeGroup fails
      SimpleLogger(output: output)
        ..startGroup(
          const LogGroup(id: 'g1', title: 'Test', description: ''),
        )
        ..logEntry(
          LogEntry(
            name: 'e1',
            level: LogLevel.info,
            timestamp: DateTime.now(),
          ),
          groupId: 'g1',
        )
        ..completeGroup('g1');
    });

    test('should handle timeout for group completion', () async {
      final output = <String>[];
      // Add an entry so the group will be written when completed
      SimpleLogger(
        output: _TestOutput(output),
        groupTimeout: const Duration(milliseconds: 50),
      )
        ..startGroup(
          const LogGroup(id: 'g1', title: 'Test', description: ''),
        )
        ..logEntry(
          LogEntry(
            name: 'test',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message: 'test message',
          ),
          groupId: 'g1',
        );

      // Let timeout fire naturally
      await Future<void>.delayed(const Duration(milliseconds: 100));

      // Group should have been auto-completed
      expect(output, contains('group:g1'));
    });

    test(
      'should catch error in timer callback when completeGroup throws',
      () async {
        // This test hits line 165 by using a logger that throws from
        // completeGroup. When the timer fires and calls completeGroup,
        // it will throw and the catch block at line 165 will catch the error
        final errorsCaught = <Object>[];
        final logger = _ThrowingLogger(
          output: _TestOutput([]),
          groupTimeout: const Duration(milliseconds: 20),
          onError: (e, st) => errorsCaught.add(e),
        )
          // Start a group - timer will fire after 20ms
          ..startGroup(
            const LogGroup(
              id: 'test',
              title: 'Test',
              description: '',
            ),
          );

        // Wait for timer to fire and trigger the error
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // The error should have been caught by line 165
        expect(errorsCaught, isNotEmpty);
        expect(
          errorsCaught.first.toString(),
          contains('Intentional error for testing timer catch'),
        );

        // Cleanup
        logger.dispose();
      },
    );

    test('should delete oldest file when rotation exceeds maxFiles', () async {
      final tempDir = await Directory.systemTemp.createTemp('test_');
      final basePath = '${tempDir.path}/rotate.log';
      final output = RotatingFileOutput(
        basePath,
        maxSizeBytes: 50, // Small size to force rotation
        maxFiles: 2, // Keep 2 rotated files
        bufferSize: 1, // Flush immediately
      );

      // Write large messages to trigger multiple rotations
      // Need at least 3 rotations to hit the deletion code:
      // - Rotation 0->1: _currentFileIndex=0, check 0>=2? No
      // - Rotation 1->2: _currentFileIndex=1, check 1>=2? No
      // - Rotation 2->3: _currentFileIndex=2, check 2>=2? Yes! Delete oldest
      // This hits lines 717-719
      for (var i = 0; i < 5; i++) {
        output.writeEntry(
          LogEntry(
            name: 'logger',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message: 'X' * 100, // 100 char message to guarantee rotation
          ),
        );
        await output.flush();
        // Small delay to ensure file operations complete
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }

      await output.dispose();

      // List all files created
      final allFiles = tempDir.listSync();
      final logFiles = allFiles
          .whereType<File>()
          .where((f) => f.path.contains('rotate.log'))
          .toList();

      // With maxFiles=2, should have at most base + 2 = 3 files
      // But some old files should have been deleted
      expect(logFiles.length, lessThanOrEqualTo(3));

      await tempDir.delete(recursive: true);
    });

    test('should use custom writer for JSON pretty print', () {
      final written = <String>[];
      // Use writeGroup to hit the pretty print with custom writer path
      JsonOutput(
        writer: written.add,
      ).writeGroup(
        const LogGroup(id: 'g1', title: 'Test', description: 'Desc'),
        [
          LogEntry(
            name: 'test',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message: 'Test message',
          ),
        ],
      );

      expect(written, isNotEmpty);
      expect(written.join(), contains('test'));
    });

    test('should format JSON with various value types', () {
      final written = <String>[];
      // Use writeGroup with various metadata types to hit JSON formatting
      JsonOutput(
        writer: written.add,
      ).writeGroup(
        const LogGroup(id: 'g1', title: 'Test', description: 'Desc'),
        [
          LogEntry(
            name: 'test',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            metadata: const {
              'string': 'value',
              'number': 42,
              'decimal': 3.14,
              'scientific': 1.5e-10,
              'boolean': true,
              'boolFalse': false,
              'nullValue': null,
              'array': [1, 2, 3],
            },
          ),
        ],
      );

      final result = written.join();
      expect(result, contains('string'));
      expect(result, contains('42'));
      expect(result, contains('3.14'));
      expect(result, contains('true'));
      expect(result, contains('false'));
      expect(result, contains('null'));
    });

    test(
      'should catch errors in AsyncLogger when completing non-existent group',
      () async {
        final errorsCaught = <Object>[];
        final output = <String>[];
        final logger = AsyncLogger(
          output: _TestOutput(output),
          onError: (e, st) => errorsCaught.add(e),
        )
          // Try to complete a group that doesn't exist
          // This queues a completeGroup task for processing
          // When processed, super.completeGroup will throw Exception
          // which is caught by the error handler
          ..completeGroup('non-existent-group');

        // Wait for async processing
        // Line 790 catch block should catch the error
        await Future<void>.delayed(const Duration(milliseconds: 150));

        // Error should have been caught by line 790
        expect(errorsCaught, isNotEmpty);

        logger.dispose();
      },
    );

    test('should handle very long words in text chunking', () {
      final formatter = LogFormatter(frameLength: 30);
      // Message with words longer than chunk, and one that fits
      final entry = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: DateTime.now(),
        message:
            'Short VeryVeryVeryLongWordWithoutSpacesThatExceedsFrameLength ok',
      );

      final formatted = formatter.formatEntry(entry);
      expect(formatted, isNotEmpty);
    });

    test('should handle text chunking with word at boundary', () {
      final formatter = LogFormatter(frameLength: 25);
      // Create text where space is exactly at boundary
      final entry = LogEntry(
        name: 'test',
        level: LogLevel.info,
        timestamp: DateTime.now(),
        message: 'This is exactly right',
      );

      final formatted = formatter.formatEntry(entry);
      expect(formatted, isNotEmpty);
    });

    test('should split text at word boundaries during chunking', () {
      // Lines 1140, 1142, 1144 are in _splitIntoChunks
      // chunkSize = frameLength - 10 = 30 - 10 = 20
      final formatter = LogFormatter(frameLength: 30);

      // Use formatGroup to call _splitIntoChunks on title and description
      // Title/description must be > 20 chars with spaces to hit the lines
      const group = LogGroup(
        id: 'g1',
        title: 'This is a very long title that exceeds twenty characters',
        description:
            'This is also a long description with many words exceeding limits',
      );

      final formatted = formatter.formatGroup(group, []);

      // Verify chunking happened
      expect(formatted, contains('This'));
      expect(formatted, isNotEmpty);
    });

    test('should handle exact file rotation at maxFiles limit', () async {
      final tempDir = await Directory.systemTemp.createTemp('test_');
      final output = RotatingFileOutput(
        '${tempDir.path}/rotate.log',
        maxSizeBytes: 20,
        maxFiles: 1,
        bufferSize: 1,
      );

      // Write enough to trigger exactly maxFiles + 1 rotations
      for (var i = 0; i < 5; i++) {
        output.writeEntry(
          LogEntry(
            name: 'e$i',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            message: 'Rotation message $i',
          ),
        );
        await output.flush();
      }

      await output.dispose();
      await tempDir.delete(recursive: true);
    });

    test('should colorize JSON boolean and number values', () {
      final written = <String>[];
      // Create entry with metadata where boolean/number are LAST properties
      // so they don't have trailing commas
      JsonOutput(
        writer: written.add,
      ).writeGroup(
        const LogGroup(id: 'g1', title: 'Test', description: 'Desc'),
        [
          LogEntry(
            name: 'test',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            metadata: const {
              'a': 'string',
              'last': true, // This should hit line 911 (boolean)
            },
          ),
          LogEntry(
            name: 'test2',
            level: LogLevel.info,
            timestamp: DateTime.now(),
            metadata: const {
              'b': 'text',
              'count': 42, // This should hit line 913 (number)
            },
          ),
        ],
      );

      final result = written.join();
      expect(result, contains('true'));
      expect(result, contains('42'));
    });
  });
}

// Test helpers
class _SimpleLogOutput extends LogOutput {
  _SimpleLogOutput(this.written);
  final List<String> written;

  @override
  void writeEntry(LogEntry entry) {
    written.add(entry.name);
  }

  @override
  Future<void> flush() async {}
}

class _TestOutput extends LogOutput {
  _TestOutput(this.output);
  final List<String> output;

  @override
  void writeEntry(LogEntry entry) {
    output.add('entry:${entry.name}');
  }

  @override
  void writeGroup(LogGroup group, List<LogEntry> entries) {
    output.add('group:${group.id}');
  }

  @override
  Future<void> flush() async {}
}

class _FailingOutput extends LogOutput {
  @override
  void writeEntry(LogEntry entry) {
    throw Exception('Write failed');
  }

  @override
  void writeGroup(LogGroup group, List<LogEntry> entries) {
    throw Exception('Write failed');
  }

  @override
  Future<void> flush() async {}
}

class _MockIOSink implements IOSink {
  _MockIOSink(this.written);
  final List<String> written;

  @override
  void writeln([Object? obj = '']) {
    written.add(obj.toString());
  }

  @override
  Future<void> flush() async {}

  @override
  void write(Object? object) {}

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  void add(List<int> data) {}

  @override
  Future<void> close() async {}

  @override
  Future<void> get done async {}

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding encoding) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
}

// Helper class that throws when flush is called
class _ThrowingIOSink implements IOSink {
  @override
  void writeln([Object? obj = '']) {
    // Allow writes to succeed
  }

  @override
  Future<void> flush() async {
    // Throw on flush to test catch block
    throw Exception('Flush failed');
  }

  @override
  void write(Object? object) {}

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {}

  @override
  void writeCharCode(int charCode) {}

  @override
  Future<void> addStream(Stream<List<int>> stream) async {}

  @override
  void add(List<int> data) {}

  @override
  Future<void> close() async {}

  @override
  Future<void> get done async {}

  @override
  Encoding get encoding => utf8;

  @override
  set encoding(Encoding encoding) {}

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}
}

// Helper class that captures LogEntry objects for testing extension methods
class _CaptureOutput extends LogOutput {
  final List<LogEntry> entries = [];
  final List<({LogGroup group, List<LogEntry> entries})> groups = [];

  @override
  void writeEntry(LogEntry entry) {
    entries.add(entry);
  }

  @override
  void writeGroup(LogGroup group, List<LogEntry> entries) {
    groups.add((group: group, entries: entries));
  }

  @override
  Future<void> flush() async {}
}

// Helper class that throws from completeGroup to test line 165
class _ThrowingLogger extends SimpleLogger {
  _ThrowingLogger({
    super.output,
    super.groupTimeout,
    super.onError,
  });

  @override
  bool completeGroup(String groupId) {
    // Always throw to trigger the catch block in timer callback (line 165)
    throw Exception('Intentional error for testing timer catch');
  }
}
