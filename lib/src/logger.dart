// TODO(pankaj): Add web support for file-based outputs (FileOutput,
// BufferedFileOutput, RotatingFileOutput). On web, implement a downloadable
// log file feature using browser download APIs to help with debugging.
// See: https://github.com/user/repo/issues/XXX

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint, immutable;

/// Function signature for filtering log entries.
typedef LogFilter = bool Function(LogEntry entry, LogGroup? group);

/// Function signature for observing log entries.
typedef LogObserver = void Function(LogEntry entry, LogGroup? group);

/// Function signature for handling logging errors.
typedef LogErrorHandler = void Function(Object error, StackTrace? stackTrace);

/// {@template mz_core.LogLevel}
/// Log severity levels for filtering and categorizing log messages.
///
/// [LogLevel] defines six severity levels from lowest to highest:
/// [trace], [debug], [info], [warning], [error], and [fatal].
///
/// Each level has an associated severity value and ANSI color code for
/// console output. Levels can be compared using standard comparison operators.
///
/// ## Severity Levels
///
/// * [trace] (0): Fine-grained debug information
/// * [debug] (1): Debug messages for development
/// * [info] (2): Informational messages about normal operation
/// * [warning] (3): Warning messages about potential issues
/// * [error] (4): Error messages about failures
/// * [fatal] (5): Critical errors requiring immediate attention
///
/// ## Usage
///
/// {@tool snippet}
/// Filter logs by minimum level:
///
/// ```dart
/// final logger = SimpleLogger(
///   minimumLevel: LogLevel.warning,
/// );
///
/// logger.debug('Not logged');     // Below minimum
/// logger.info('Not logged');      // Below minimum
/// logger.warning('Logged');       // At or above minimum
/// logger.error('Logged');         // At or above minimum
/// ```
/// {@end-tool}
///
/// {@tool snippet}
/// Compare log levels:
///
/// ```dart
/// if (entry.level >= LogLevel.error) {
///   alertAdmin(entry);
/// }
///
/// if (entry.level < LogLevel.warning) {
///   // Debug or info level
///   logToFile(entry);
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [SimpleLogger.minimumLevel], which filters based on severity
/// * [LogEntry.level], which specifies the entry's severity
/// {@endtemplate}
enum LogLevel {
  /// Trace level logging (lowest severity).
  ///
  /// Use for fine-grained debug information like method entry/exit,
  /// variable values, or detailed flow tracing.
  trace(0, color: '\x1B[90m'),

  /// Debug level logging.
  ///
  /// Use for debug messages helpful during development and troubleshooting.
  debug(1, color: '\x1B[36m'),

  /// Info level logging.
  ///
  /// Use for informational messages about normal application operation.
  info(2, color: '\x1B[34m'),

  /// Warning level logging.
  ///
  /// Use for warning messages about potential problems that don't prevent
  /// operation.
  warning(3, color: '\x1B[33m'),

  /// Error level logging.
  ///
  /// Use for error messages about failures that were handled or recovered from.
  error(4, color: '\x1B[31m'),

  /// Fatal level logging (highest severity).
  ///
  /// Use for critical errors that require immediate attention or may cause
  /// application termination.
  fatal(5, color: '\x1B[35m');

  const LogLevel(this.severity, {required this.color});

  /// Severity level as an integer (higher = more severe).
  ///
  /// Used for level comparison and filtering. Higher values indicate more
  /// severe log levels.
  final int severity;

  /// ANSI color code for console output.
  ///
  /// Used by [ConsoleOutput] to colorize log messages based on their severity.
  final String color;

  /// Checks if this level is greater than or equal to [other].
  ///
  /// Returns `true` if this level's severity is at least as high as [other].
  bool operator >=(LogLevel other) => severity >= other.severity;

  /// Checks if this level is greater than [other].
  ///
  /// Returns `true` if this level's severity is strictly higher than [other].
  bool operator >(LogLevel other) => severity > other.severity;

  /// Checks if this level is less than or equal to [other].
  ///
  /// Returns `true` if this level's severity is at most as high as [other].
  bool operator <=(LogLevel other) => severity <= other.severity;

  /// Checks if this level is less than [other].
  ///
  /// Returns `true` if this level's severity is strictly lower than [other].
  bool operator <(LogLevel other) => severity < other.severity;
}

/// {@template mz_core.LogEntry}
/// Represents a single structured log entry with metadata.
///
/// [LogEntry] contains all information about a log event including:
/// * [name]: The category or source of the log
/// * [level]: Severity level ([LogLevel])
/// * [timestamp]: When the event occurred
/// * [message]: Optional human-readable message
/// * [metadata]: Additional structured data
/// * [duration]: Optional timing information
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Create log entries with different severity levels:
///
/// ```dart
/// final entry = LogEntry(
///   name: 'UserService',
///   level: LogLevel.info,
///   timestamp: DateTime.now(),
///   message: 'User logged in',
///   metadata: {
///     'userId': '123',
///     'sessionId': 'abc',
///   },
/// );
///
/// logger.logEntry(entry);
/// ```
/// {@end-tool}
///
/// ## Timing Logs
///
/// {@tool snippet}
/// Log operation duration:
///
/// ```dart
/// final stopwatch = Stopwatch()..start();
/// await performOperation();
/// stopwatch.stop();
///
/// logger.logEntry(LogEntry(
///   name: 'Performance',
///   level: LogLevel.debug,
///   timestamp: DateTime.now(),
///   message: 'Operation completed',
///   duration: stopwatch.elapsed,
/// ));
/// ```
/// {@end-tool}
///
/// ## Structured Metadata
///
/// {@tool snippet}
/// Include structured data with logs:
///
/// ```dart
/// logger.logEntry(LogEntry(
///   name: 'API',
///   level: LogLevel.info,
///   timestamp: DateTime.now(),
///   message: 'Request completed',
///   metadata: {
///     'method': 'GET',
///     'path': '/users/123',
///     'statusCode': 200,
///     'responseTime': 145,
///   },
/// ));
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [LogLevel], which defines severity levels
/// * [LogGroup], which organizes related entries
/// * [SimpleLogger.logEntry], which outputs log entries
/// {@endtemplate}
@immutable
class LogEntry {
  /// Creates a new log entry with the specified properties.
  ///
  /// {@macro mz_core.LogEntry}
  ///
  /// The [name] parameter categorizes the log (e.g., 'Database', 'Auth').
  ///
  /// The [level] parameter specifies the severity.
  ///
  /// The [timestamp] parameter records when the event occurred. Typically set
  /// to `DateTime.now()`.
  ///
  /// The [message] parameter provides a human-readable description.
  ///
  /// The [metadata] parameter contains structured data as key-value pairs.
  ///
  /// The [duration] parameter tracks how long an operation took.
  ///
  /// The [id] parameter uniquely identifies this log event.
  ///
  /// The [color] parameter overrides the default color for this entry.
  const LogEntry({
    required this.name,
    required this.level,
    required this.timestamp,
    this.id,
    this.message,
    this.color,
    this.duration,
    this.metadata,
  });

  /// Name or category of the log entry.
  ///
  /// Used to categorize logs by their source or purpose. Common examples:
  /// 'Database', 'Auth', 'API', 'UI', 'Performance'.
  final String name;

  /// Severity level of the log entry.
  ///
  /// Determines if the entry is output based on [SimpleLogger.minimumLevel].
  final LogLevel level;

  /// When the log entry was created.
  ///
  /// Typically set to `DateTime.now()` when creating the entry.
  final DateTime timestamp;

  /// Optional unique identifier for this log event.
  ///
  /// Useful for correlating logs across systems or tracking specific events.
  final String? id;

  /// Optional human-readable log message.
  ///
  /// Provides context about what happened. Can be null if metadata is
  /// sufficient.
  final String? message;

  /// Optional duration for timing logs.
  ///
  /// Use to track how long an operation took. Typically populated using a
  /// [Stopwatch].
  final Duration? duration;

  /// Optional custom color override for console output.
  ///
  /// If provided, overrides the default color for this entry's log level.
  final String? color;

  /// Additional metadata as key-value pairs.
  ///
  /// Contains structured data about the log event. Values can be of any JSON-
  /// serializable type (String, num, bool, List, Map).
  final Map<String, dynamic>? metadata;

  /// Converts the log entry to a JSON map.
  Map<String, dynamic> toJson() => {
        'name': name,
        'level': level.name,
        'timestamp': timestamp.toIso8601String(),
        if (message != null) 'message': message,
        if (id != null) 'eventId': id,
        if (duration != null) 'duration': duration!.inMicroseconds / 1000,
        ...?metadata,
      };

  @override
  int get hashCode =>
      name.hashCode ^
      level.hashCode ^
      timestamp.hashCode ^
      id.hashCode ^
      message.hashCode ^
      duration.hashCode ^
      metadata.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LogEntry &&
        other.name == name &&
        other.level == level &&
        other.timestamp == timestamp &&
        other.id == id &&
        other.message == message &&
        other.duration == duration &&
        other.metadata == metadata;
  }
}

/// {@template mz_core.LogGroup}
/// Represents a group of related log entries.
///
/// [LogGroup] organizes related [LogEntry] objects together for batch output.
/// All entries added to a group are buffered and output together when the
/// group is completed via [SimpleLogger.completeGroup].
///
/// ## When to Use Groups
///
/// Use log groups when you want to:
/// * Organize related operations together
/// * Batch output for better readability
/// * Track multi-step processes as a unit
/// * Associate metadata with a collection of logs
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Create and use a log group:
///
/// ```dart
/// logger.startGroup(const LogGroup(
///   id: 'user-signup',
///   title: 'User Registration',
///   description: 'Complete user signup flow',
/// ));
///
/// logger.logEntry(entry1, groupId: 'user-signup');
/// logger.logEntry(entry2, groupId: 'user-signup');
/// logger.logEntry(entry3, groupId: 'user-signup');
///
/// logger.completeGroup('user-signup');
/// // All three entries output together
/// ```
/// {@end-tool}
///
/// ## Automatic Completion with group()
///
/// {@tool snippet}
/// Use the convenience method for automatic lifecycle:
///
/// ```dart
/// final result = await logger.group(
///   'api-request',
///   'API Request',
///   () async {
///     logger.info('Starting request');
///     final data = await api.fetch();
///     logger.info('Request completed');
///     return data;
///   },
///   description: 'Fetch user data from API',
/// );
/// // Group automatically completed even if exception thrown
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [SimpleLogger.startGroup], which creates a new group
/// * [SimpleLogger.completeGroup], which finalizes a group
/// * [SimpleLogger.group], which provides automatic lifecycle management
/// {@endtemplate}
@immutable
class LogGroup {
  /// Creates a new log group with the specified properties.
  ///
  /// {@macro mz_core.LogGroup}
  ///
  /// The [id] parameter uniquely identifies this group. Must be unique within
  /// the logger instance.
  ///
  /// The [title] parameter provides a human-readable name for the group.
  ///
  /// The [description] parameter adds optional context about the group's
  /// purpose.
  const LogGroup({
    required this.id,
    required this.title,
    required this.description,
  });

  /// Unique identifier for the log group.
  ///
  /// Used to associate log entries with this group via
  /// [SimpleLogger.logEntry]'s `groupId` parameter.
  ///
  /// Must be unique within a [SimpleLogger] instance at any given time.
  final String id;

  /// Human-readable title for the log group.
  ///
  /// Displayed in the log output to identify the group. Should briefly
  /// describe what the group represents (e.g., 'User Login', 'Data Import').
  final String title;

  /// Description of the log group.
  ///
  /// Provides additional context about the group's purpose. Can be an empty
  /// string if the title is sufficient.
  final String description;

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LogGroup && other.id == id;
  }
}

/// {@template mz_core.SimpleLogger}
/// A flexible logging system with level filtering, sampling, and group support.
///
/// [SimpleLogger] provides structured logging with the following features:
///
/// * **Level filtering**: Control which severity levels are logged
/// * **Sampling**: Probabilistically log messages to reduce volume
/// * **Log groups**: Organize related log entries together
/// * **Multiple outputs**: Console, file, JSON, or rotating files
/// * **Custom formatting**: Control how logs are displayed
/// * **Error handling**: Graceful error handling with callbacks
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Create a logger and log different severity levels:
///
/// ```dart
/// final logger = SimpleLogger(
///   output: ConsoleOutput(
///     formatter: LogFormatter(enableColors: true),
///   ),
///   minimumLevel: LogLevel.debug,
/// );
///
/// logger.trace('Detailed trace information');
/// logger.debug('Debug message');
/// logger.info('Application started');
/// logger.warning('Low memory warning');
/// logger.error('Failed to connect');
/// logger.fatal('Critical system failure');
/// ```
/// {@end-tool}
///
/// ## Using Log Groups
///
/// {@tool snippet}
/// Group related log entries for better organization:
///
/// ```dart
/// // Manual grouping
/// logger.startGroup(const LogGroup(
///   id: 'user-auth',
///   title: 'User Authentication',
///   description: 'Login flow',
/// ));
///
/// logger.logEntry(
///   LogEntry(
///     name: 'AuthStart',
///     level: LogLevel.info,
///     timestamp: DateTime.now(),
///     message: 'Starting authentication',
///   ),
///   groupId: 'user-auth',
/// );
///
/// logger.completeGroup('user-auth');
///
/// // Or use the convenience method
/// await logger.group('api-call', 'Fetch Data', () async {
///   logger.info('Making API request');
///   final data = await fetchData();
///   logger.info('Data received');
///   return data;
/// });
/// ```
/// {@end-tool}
///
/// ## Level Filtering and Sampling
///
/// {@tool snippet}
/// Control log volume with filters and sampling:
///
/// ```dart
/// // Only log warnings and above
/// final logger = SimpleLogger(
///   minimumLevel: LogLevel.warning,
/// );
///
/// // Log only 10% of messages (useful for high-volume logs)
/// final sampledLogger = SimpleLogger(
///   sampleRate: 0.1,
/// );
///
/// // Custom filtering
/// final filteredLogger = SimpleLogger(
///   filter: (entry, group) => entry.name != 'ignored',
/// );
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [LogLevel], which defines severity levels
/// * [LogEntry], which represents a single log message
/// * [LogGroup], which groups related log entries
/// * [LogOutput], which controls where logs are written
/// * [SimpleLoggerX], for convenience methods (trace, debug, info, etc.)
/// {@endtemplate}
class SimpleLogger {
  /// Creates a new logger instance.
  ///
  /// {@macro mz_core.SimpleLogger}
  ///
  /// The [output] parameter specifies where logs are written. Defaults to
  /// [ConsoleOutput] if not provided.
  ///
  /// The [minimumLevel] parameter controls which log levels are output.
  /// Messages below this level are filtered out. Defaults to [LogLevel.info].
  ///
  /// The [sampleRate] parameter controls probabilistic logging. A value of 1.0
  /// (default) logs all messages, while 0.1 logs approximately 10% of messages.
  /// Must be between 0.0 (exclusive) and 1.0 (inclusive).
  ///
  /// The [groupTimeout] parameter sets the maximum time a log group can remain
  /// open before being auto-completed. This prevents memory leaks from
  /// uncompleted groups. Defaults to 5 minutes.
  ///
  /// The [observer] parameter allows monitoring all log entries before they're
  /// written to the output.
  ///
  /// The [filter] parameter provides fine-grained control over which entries
  /// are logged. Return `true` to filter out (skip) an entry.
  ///
  /// The [onError] parameter handles errors that occur during logging
  /// operations. If not provided, errors are printed using [debugPrint].
  ///
  /// {@tool snippet}
  /// Create a logger with custom configuration:
  ///
  /// ```dart
  /// final logger = SimpleLogger(
  ///   output: ConsoleOutput(
  ///     formatter: LogFormatter(
  ///       enableColors: true,
  ///       frameLength: 80,
  ///     ),
  ///   ),
  ///   minimumLevel: LogLevel.debug,
  ///   sampleRate: 1.0,
  ///   groupTimeout: const Duration(minutes: 5),
  ///   observer: (entry, group) {
  ///     // Monitor all log entries
  ///     analyticsService.trackLog(entry);
  ///   },
  ///   filter: (entry, group) {
  ///     // Filter out entries from ignored sources
  ///     return entry.name == 'ignored-source';
  ///   },
  ///   onError: (error, stackTrace) {
  ///     // Handle logging errors
  ///     errorReporter.report(error, stackTrace);
  ///   },
  /// );
  /// ```
  /// {@end-tool}
  SimpleLogger({
    this.debugLabel,
    LogOutput? output,
    this.observer,
    this.filter,
    this.minimumLevel = LogLevel.info,
    this.sampleRate = 1.0,
    this.groupTimeout = const Duration(minutes: 5),
    this.onError,
  })  : output = output ?? ConsoleOutput(),
        assert(
          sampleRate > 0 && sampleRate <= 1.0,
          'Sample rate must be 0-1',
        );

  /// Where to send log output.
  final LogOutput output;

  /// Observer that receives all log entries.
  final LogObserver? observer;

  /// Filter function to exclude certain log entries.
  final LogFilter? filter;

  /// Optional debug label for this logger instance.
  final String? debugLabel;

  /// Minimum log level to output.
  final LogLevel minimumLevel;

  /// Sampling rate (0.0-1.0) for probabilistic logging.
  final double sampleRate;

  /// Timeout for auto-flushing log groups.
  final Duration groupTimeout;

  /// Error handler for logging errors.
  final LogErrorHandler? onError;

  final _activeGroups = <String, LogGroup>{};
  final _groupEntries = <String, List<LogEntry>>{};
  final _groupTimers = <String, Timer>{};

  /// Whether logging is enabled for this logger instance
  bool get isEnabled => _isEnabled;
  bool _isEnabled = true;
  set isEnabled(bool value) {
    if (_isEnabled == value) return;
    _isEnabled = value;
  }

  /// {@template mz_core.SimpleLogger.guard}
  /// Executes [callback] only if logging is enabled.
  ///
  /// This is useful for expensive logging operations that should only run when
  /// logging is active.
  ///
  /// Returns `true` if the callback was executed, `false` if logging is
  /// disabled.
  ///
  /// {@tool snippet}
  /// Guard expensive logging operations:
  ///
  /// ```dart
  /// if (logger.guard(() {
  ///   final expensiveData = computeExpensiveDebugInfo();
  ///   logger.debug('Debug info: $expensiveData');
  /// })) {
  ///   print('Logging executed');
  /// }
  /// ```
  /// {@end-tool}
  /// {@endtemplate}
  bool guard(void Function() callback) {
    if (!_isEnabled) return false;
    callback();
    return true;
  }

  /// Starts a log group with automatic timeout cleanup.
  ///
  /// Groups allow you to organize related log entries together. Entries added
  /// with [logEntry] using the group's ID will be batched and output together
  /// when [completeGroup] is called.
  ///
  /// **Important**: A timeout is automatically set using [groupTimeout]. If the
  /// group is not manually completed before the timeout, it will be
  /// auto-completed to prevent memory leaks.
  ///
  /// {@tool snippet}
  /// Create and use a log group:
  ///
  /// ```dart
  /// logger.startGroup(const LogGroup(
  ///   id: 'task-123',
  ///   title: 'Data Processing',
  ///   description: 'User data ETL pipeline',
  /// ));
  ///
  /// logger.logEntry(
  ///   LogEntry(
  ///     name: 'Step1',
  ///     level: LogLevel.info,
  ///     timestamp: DateTime.now(),
  ///     message: 'Loading data',
  ///   ),
  ///   groupId: 'task-123',
  /// );
  ///
  /// logger.logEntry(
  ///   LogEntry(
  ///     name: 'Step2',
  ///     level: LogLevel.info,
  ///     timestamp: DateTime.now(),
  ///     message: 'Processing data',
  ///   ),
  ///   groupId: 'task-123',
  /// );
  ///
  /// logger.completeGroup('task-123');
  /// ```
  /// {@end-tool}
  ///
  /// See also:
  ///
  /// * [group], which provides a more convenient API for grouping
  /// * [completeGroup], which outputs and closes a group
  /// * [LogGroup], which represents a group of log entries
  void startGroup(LogGroup group) {
    if (!_isEnabled) return;

    _activeGroups[group.id] = group;
    _groupEntries[group.id] = [];

    // Auto-complete after timeout to prevent memory leaks
    _groupTimers[group.id] = Timer(groupTimeout, () {
      if (_activeGroups.containsKey(group.id)) {
        try {
          completeGroup(group.id);
        } on Exception catch (e, st) {
          _handleError(e, st);
        }
      }
    });
  }

  /// Runs [fn] within a log group context with automatic completion.
  ///
  /// This is a convenience method that automatically starts a group, executes
  /// [fn], and completes the group when done. The group is completed even if
  /// [fn] throws an exception.
  ///
  /// Returns the value returned by [fn].
  ///
  /// The [id] parameter uniquely identifies this group. The [title] parameter
  /// provides a human-readable name. The [description] parameter adds optional
  /// context.
  ///
  /// {@tool snippet}
  /// Use group to automatically handle group lifecycle:
  ///
  /// ```dart
  /// final user = await logger.group(
  ///   'fetch-user',
  ///   'Fetch User Data',
  ///   () async {
  ///     logger.info('Starting API request');
  ///     final response = await api.getUser('123');
  ///     logger.info('User fetched: ${response.name}');
  ///     return response;
  ///   },
  ///   description: 'User data fetch operation',
  /// );
  /// ```
  /// {@end-tool}
  ///
  /// See also:
  ///
  /// * [startGroup], for manual group management
  /// * [completeGroup], for manual group completion
  Future<T> group<T>(
    String id,
    String title,
    Future<T> Function() fn, {
    String description = '',
  }) async {
    final logGroup = LogGroup(id: id, title: title, description: description);
    startGroup(logGroup);
    try {
      return await fn();
    } finally {
      completeGroup(id);
    }
  }

  /// Logs a single entry with level filtering and sampling.
  ///
  /// The [entry] parameter contains the log data including level, message, and
  /// metadata.
  ///
  /// The optional [groupId] parameter associates this entry with a log group.
  /// If provided, the entry is buffered and output when [completeGroup] is
  /// called. If not provided, the entry is output immediately.
  ///
  /// Returns `false` if the entry was filtered out (by level, sampling, or
  /// custom filter), `true` if it was logged.
  ///
  /// {@tool snippet}
  /// Log entries at different levels:
  ///
  /// ```dart
  /// // Immediate logging
  /// logger.logEntry(LogEntry(
  ///   name: 'AppStart',
  ///   level: LogLevel.info,
  ///   timestamp: DateTime.now(),
  ///   message: 'Application started',
  ///   metadata: {'version': '1.0.0'},
  /// ));
  ///
  /// // Grouped logging
  /// logger.startGroup(const LogGroup(
  ///   id: 'startup',
  ///   title: 'Startup',
  ///   description: 'App initialization',
  /// ));
  ///
  /// logger.logEntry(
  ///   LogEntry(
  ///     name: 'Init',
  ///     level: LogLevel.debug,
  ///     timestamp: DateTime.now(),
  ///   ),
  ///   groupId: 'startup',
  /// );
  ///
  /// logger.completeGroup('startup');
  /// ```
  /// {@end-tool}
  ///
  /// See also:
  ///
  /// * [LogEntry], which represents a log entry
  /// * [LogLevel], for the available severity levels
  /// * [SimpleLoggerX], for convenience methods (trace, debug, info, etc.)
  bool logEntry(LogEntry entry, {String? groupId}) {
    if (!_isEnabled) return false;

    // Level filtering
    if (entry.level < minimumLevel) return false;

    // Sampling
    if (sampleRate < 1.0 && !_shouldSample()) return false;

    return guard(() {
      // Filter before observer for performance
      final group = groupId != null ? _activeGroups[groupId] : null;
      final isFiltered = filter?.call(entry, group) ?? false;
      if (isFiltered) return;

      observer?.call(entry, group);

      if (groupId == null) {
        _safeWriteEntry(entry);
      } else {
        _groupEntries[groupId]?.add(entry);
      }
    });
  }

  /// Completes a log group and outputs all its entries.
  ///
  /// This method finalizes a log group identified by [groupId], cancels its
  /// timeout timer, and writes all buffered entries to the output.
  ///
  /// Returns `false` if logging is disabled or the group is not found
  /// (throws [Exception] in that case), `true` if the group was completed
  /// successfully.
  ///
  /// **Note**: If the group has no entries, nothing is written to the output.
  ///
  /// Throws an [Exception] if no group with the given [groupId] exists.
  ///
  /// {@tool snippet}
  /// Complete a log group:
  ///
  /// ```dart
  /// logger.startGroup(const LogGroup(
  ///   id: 'batch-123',
  ///   title: 'Batch Processing',
  ///   description: 'Data import',
  /// ));
  ///
  /// logger.logEntry(entry1, groupId: 'batch-123');
  /// logger.logEntry(entry2, groupId: 'batch-123');
  /// logger.logEntry(entry3, groupId: 'batch-123');
  ///
  /// // Output all entries at once
  /// logger.completeGroup('batch-123');
  /// ```
  /// {@end-tool}
  ///
  /// See also:
  ///
  /// * [startGroup], which creates a new group
  /// * [group], which automatically completes the group
  bool completeGroup(String groupId) {
    return guard(() {
      _groupTimers[groupId]?.cancel();
      _groupTimers.remove(groupId);

      final group = _activeGroups.remove(groupId);
      final entries = _groupEntries.remove(groupId);

      if (group == null) {
        throw Exception('Log group not found: $groupId');
      }

      if (entries != null && entries.isNotEmpty) {
        _safeWriteGroup(group, entries);
      }
    });
  }

  /// Disposes resources and cancels all timers.
  ///
  /// This method should be called when the logger is no longer needed. It:
  ///
  /// * Cancels all pending group timeout timers
  /// * Clears all active groups and their buffered entries
  ///
  /// **Important**: After calling [dispose], the logger should not be used.
  /// Buffered group entries will be lost if not completed before disposal.
  ///
  /// {@tool snippet}
  /// Dispose a logger when done:
  ///
  /// ```dart
  /// class MyService {
  ///   final SimpleLogger _logger;
  ///
  ///   MyService() : _logger = SimpleLogger();
  ///
  ///   void close() {
  ///     _logger.dispose();
  ///   }
  /// }
  /// ```
  /// {@end-tool}
  void dispose() {
    for (final timer in _groupTimers.values) {
      timer.cancel();
    }
    _groupTimers.clear();
    _activeGroups.clear();
    _groupEntries.clear();
  }

  void _safeWriteEntry(LogEntry entry) {
    try {
      output.writeEntry(entry);
    } on Exception catch (e, st) {
      _handleError(e, st);
    }
  }

  void _safeWriteGroup(LogGroup group, List<LogEntry> entries) {
    try {
      output.writeGroup(group, entries);
    } on Exception catch (e, st) {
      _handleError(e, st);
    }
  }

  void _handleError(Object error, StackTrace? stackTrace) {
    if (onError != null) {
      onError!(error, stackTrace);
    } else {
      debugPrint('[SimpleLogger] Error: $error');
    }
  }

  bool _shouldSample() {
    final random = math.Random();
    return random.nextDouble() < sampleRate;
  }
}

// +++++++++++++++++++++++++++++++++++++++++++++++++++++
// ==================== LOG OUTPUT =====================
// +++++++++++++++++++++++++++++++++++++++++++++++++++++

/// Handles sanitization of sensitive information in logs
class LogSanitizer {
  /// Creates a sanitizer with the given sensitive field names.
  const LogSanitizer({
    this.sensitiveFields = const {
      'password',
      'token',
      'apiKey',
      'secret',
      'authorization',
      'cookie',
      'session',
      'credential',
      'key',
      'private',
    },
  });

  /// Set of field names considered sensitive.
  final Set<String> sensitiveFields;

  /// Sanitizes sensitive information in the JSON output
  Map<String, dynamic> sanitizeJson(Map<String, dynamic> json) {
    return _deepSanitize(json) as Map<String, dynamic>;
  }

  dynamic _deepSanitize(dynamic value) {
    if (value is Map) {
      final sanitized = <String, dynamic>{};
      for (final entry in value.entries) {
        final key = entry.key.toString();
        if (_isSensitiveKey(key)) {
          sanitized[key] = _maskValue(entry.value);
        } else {
          sanitized[key] = _deepSanitize(entry.value);
        }
      }
      return sanitized;
    } else if (value is List) {
      return value.map(_deepSanitize).toList();
    }
    return value;
  }

  /// Sanitizes sensitive information in text output
  String sanitizeText(String text) {
    // Split text into lines to handle multiline content
    final lines = text.split('\n');
    final sanitizedLines = lines.map((line) {
      // Look for key-value pairs in the line
      final colonIndex = line.indexOf(':');
      if (colonIndex == -1) return line;

      final key = line.substring(0, colonIndex).trim();
      if (_isSensitiveKey(key)) {
        final value = line.substring(colonIndex + 1).trim();
        return '$key: ${_maskValue(value)}';
      }

      // Check for sensitive information in the value
      final value = line.substring(colonIndex + 1).trim();
      if (_containsSensitiveInfo(value)) {
        return '$key: ${_maskValue(value)}';
      }

      return line;
    });

    return sanitizedLines.join('\n');
  }

  String _maskValue(dynamic value) {
    if (value == null) return '********';
    final strValue = value.toString();
    return '*' * strValue.length;
  }

  bool _isSensitiveKey(String key) {
    final lowerKey = key.toLowerCase();
    return sensitiveFields.any(lowerKey.contains);
  }

  bool _containsSensitiveInfo(String value) {
    // Check if the value contains any sensitive patterns
    final lowerValue = value.toLowerCase();
    return sensitiveFields.any(lowerValue.contains);
  }
}

/// Abstract interface for log output destinations
abstract class LogOutput {
  /// Creates a log output with optional sanitizer.
  const LogOutput({this.sanitizer});

  /// Optional sanitizer for sensitive data.
  final LogSanitizer? sanitizer;

  /// Writes a single log entry.
  void writeEntry(LogEntry entry);

  /// Flushes any buffered output.
  Future<void> flush();

  /// Writes a group of log entries.
  void writeGroup(LogGroup group, List<LogEntry> entries) {
    entries.forEach(writeEntry);
  }
}

/// Console output implementation using debugPrint
class ConsoleOutput extends LogOutput {
  /// Creates a console output with optional formatter and sanitizer.
  ConsoleOutput({LogFormatter? formatter, super.sanitizer})
      : formatter = formatter ?? LogFormatter();

  /// Formatter for converting log entries to strings.
  final LogFormatter formatter;

  @override
  void writeEntry(LogEntry entry) {
    final sanitizedEntry = sanitizer != null
        ? LogEntry(
            name: entry.name,
            level: entry.level,
            timestamp: entry.timestamp,
            message: sanitizer!.sanitizeText(entry.message ?? ''),
            id: entry.id,
            duration: entry.duration,
            color: entry.color,
            metadata: entry.metadata,
          )
        : entry;
    final formatted = formatter.formatEntry(sanitizedEntry);
    debugPrint(formatted);
  }

  @override
  void writeGroup(LogGroup group, List<LogEntry> entries) {
    final sanitizedGroup = sanitizer != null
        ? LogGroup(
            id: group.id,
            title: group.title,
            description: sanitizer!.sanitizeText(group.description),
          )
        : group;
    final sanitizedEntries = sanitizer != null
        ? entries
            .map(
              (e) => LogEntry(
                name: e.name,
                level: e.level,
                timestamp: e.timestamp,
                message: sanitizer!.sanitizeText(e.message ?? ''),
                id: e.id,
                duration: e.duration,
                color: e.color,
                metadata: e.metadata,
              ),
            )
            .toList()
        : entries;
    final formatted = formatter.formatGroup(sanitizedGroup, sanitizedEntries);
    debugPrint(formatted);
  }

  @override
  Future<void> flush() async {}
}

/// File output implementation with customizable formatting
class FileOutput extends LogOutput {
  /// Creates a file output with the given file sink.
  FileOutput(this.file, {LogFormatter? formatter, super.sanitizer})
      : formatter = formatter ?? LogFormatter();

  /// The file sink to write to.
  final IOSink file;

  /// Formatter for converting log entries to strings.
  final LogFormatter formatter;

  @override
  void writeEntry(LogEntry entry) {
    final sanitizedEntry = sanitizer != null
        ? LogEntry(
            name: entry.name,
            level: entry.level,
            timestamp: entry.timestamp,
            message: sanitizer!.sanitizeText(entry.message ?? ''),
            id: entry.id,
            duration: entry.duration,
            color: entry.color,
            metadata: entry.metadata,
          )
        : entry;
    final formatted = formatter.formatEntry(sanitizedEntry);
    file.writeln(formatted);
  }

  @override
  void writeGroup(LogGroup group, List<LogEntry> entries) {
    final sanitizedGroup = sanitizer != null
        ? LogGroup(
            id: group.id,
            title: group.title,
            description: sanitizer!.sanitizeText(group.description),
          )
        : group;
    final sanitizedEntries = sanitizer != null
        ? entries
            .map(
              (e) => LogEntry(
                name: e.name,
                level: e.level,
                timestamp: e.timestamp,
                message: sanitizer!.sanitizeText(e.message ?? ''),
                id: e.id,
                duration: e.duration,
                color: e.color,
                metadata: e.metadata,
              ),
            )
            .toList()
        : entries;
    final formatted = formatter.formatGroup(sanitizedGroup, sanitizedEntries);
    file.writeln(formatted);
  }

  @override
  Future<void> flush() => file.flush();
}

/// Buffered file output for better I/O performance
class BufferedFileOutput extends LogOutput {
  /// Creates a buffered file output.
  BufferedFileOutput(
    this.file, {
    LogFormatter? formatter,
    super.sanitizer,
    this.bufferSize = 100,
    this.flushInterval = const Duration(seconds: 5),
  }) : formatter = formatter ?? LogFormatter() {
    unawaited(_startFlushTimer());
  }

  /// The file sink to write to.
  final IOSink file;

  /// Formatter for converting log entries to strings.
  final LogFormatter formatter;

  /// Maximum number of entries to buffer before flushing.
  final int bufferSize;

  /// How often to flush the buffer automatically.
  final Duration flushInterval;

  final _buffer = <String>[];
  Timer? _flushTimer;

  @override
  void writeEntry(LogEntry entry) {
    final sanitizedEntry = sanitizer != null
        ? LogEntry(
            name: entry.name,
            level: entry.level,
            timestamp: entry.timestamp,
            message: sanitizer!.sanitizeText(entry.message ?? ''),
            id: entry.id,
            duration: entry.duration,
            color: entry.color,
            metadata: entry.metadata,
          )
        : entry;
    final formatted = formatter.formatEntry(sanitizedEntry);
    _buffer.add(formatted);

    if (_buffer.length >= bufferSize) {
      unawaited(flush());
    }
  }

  @override
  void writeGroup(LogGroup group, List<LogEntry> entries) {
    final sanitizedGroup = sanitizer != null
        ? LogGroup(
            id: group.id,
            title: group.title,
            description: sanitizer!.sanitizeText(group.description),
          )
        : group;
    final sanitizedEntries = sanitizer != null
        ? entries
            .map(
              (e) => LogEntry(
                name: e.name,
                level: e.level,
                timestamp: e.timestamp,
                message: sanitizer!.sanitizeText(e.message ?? ''),
                id: e.id,
                duration: e.duration,
                color: e.color,
                metadata: e.metadata,
              ),
            )
            .toList()
        : entries;
    final formatted = formatter.formatGroup(sanitizedGroup, sanitizedEntries);
    _buffer.add(formatted);

    if (_buffer.length >= bufferSize) {
      unawaited(flush());
    }
  }

  @override
  Future<void> flush() async {
    if (_buffer.isEmpty) return;

    try {
      _buffer.forEach(file.writeln);
      await file.flush();
      _buffer.clear();
    } on Exception {
      // Keep buffer for retry
      rethrow;
    }
  }

  /// Starts the periodic flush timer.
  Future<void> _startFlushTimer() async {
    _flushTimer = Timer.periodic(flushInterval, (_) => unawaited(flush()));
  }

  /// Disposes the output and flushes remaining data.
  Future<void> dispose() async {
    _flushTimer?.cancel();
    await flush();
  }
}

/// Rotating file output with size and file count limits
class RotatingFileOutput extends LogOutput {
  /// Creates a rotating file output.
  RotatingFileOutput(
    this.basePath, {
    LogFormatter? formatter,
    super.sanitizer,
    this.maxSizeBytes = 10 * 1024 * 1024, // 10MB default
    this.maxFiles = 5,
    this.bufferSize = 100,
  }) : formatter = formatter ?? LogFormatter();

  /// Base path for log files.
  final String basePath;

  /// Formatter for converting log entries to strings.
  final LogFormatter formatter;

  /// Maximum size in bytes before rotating.
  final int maxSizeBytes;

  /// Maximum number of log files to keep.
  final int maxFiles;

  /// Buffer size for batching writes.
  final int bufferSize;

  IOSink? _currentFile;
  int _currentFileSize = 0;
  int _currentFileIndex = 0;
  final _buffer = <String>[];
  bool _isFlushing = false;

  @override
  void writeEntry(LogEntry entry) {
    final sanitizedEntry = sanitizer != null
        ? LogEntry(
            name: entry.name,
            level: entry.level,
            timestamp: entry.timestamp,
            message: sanitizer!.sanitizeText(entry.message ?? ''),
            id: entry.id,
            duration: entry.duration,
            color: entry.color,
            metadata: entry.metadata,
          )
        : entry;
    final formatted = formatter.formatEntry(sanitizedEntry);
    _writeToFile(formatted);
  }

  @override
  void writeGroup(LogGroup group, List<LogEntry> entries) {
    final sanitizedGroup = sanitizer != null
        ? LogGroup(
            id: group.id,
            title: group.title,
            description: sanitizer!.sanitizeText(group.description),
          )
        : group;
    final sanitizedEntries = sanitizer != null
        ? entries
            .map(
              (e) => LogEntry(
                name: e.name,
                level: e.level,
                timestamp: e.timestamp,
                message: sanitizer!.sanitizeText(e.message ?? ''),
                id: e.id,
                duration: e.duration,
                color: e.color,
                metadata: e.metadata,
              ),
            )
            .toList()
        : entries;
    final formatted = formatter.formatGroup(sanitizedGroup, sanitizedEntries);
    _writeToFile(formatted);
  }

  void _writeToFile(String content) {
    _buffer.add(content);

    if (_buffer.length >= bufferSize) {
      unawaited(flush());
    }
  }

  @override
  Future<void> flush() async {
    if (_buffer.isEmpty || _isFlushing) return;

    _isFlushing = true;
    try {
      // Open file if not already open
      if (_currentFile == null) {
        _openCurrentFile();
      }

      // Copy buffer to avoid concurrent modification
      final linesToWrite = List<String>.from(_buffer);
      _buffer.clear();

      for (final line in linesToWrite) {
        final lineBytes = line.length;

        if (_currentFileSize + lineBytes > maxSizeBytes) {
          await _rotate();
        }

        _currentFile?.writeln(line);
        _currentFileSize += lineBytes;
      }

      await _currentFile?.flush();
    } finally {
      _isFlushing = false;
    }
  }

  Future<void> _rotate() async {
    // Close current file if open
    if (_currentFile != null) {
      try {
        await _currentFile!.close();
        // coverage:ignore-start
      } on Exception catch (_) {
        // Ignore close errors
      }
      // coverage:ignore-end
      _currentFile = null;
    }

    // Delete oldest file if we've hit the limit
    if (_currentFileIndex >= maxFiles) {
      final oldestFile = File('$basePath.${_currentFileIndex - maxFiles + 1}');
      if (oldestFile.existsSync()) {
        await oldestFile.delete();
      }
    }

    _currentFileIndex++;
    _currentFileSize = 0;
    _openCurrentFile();
  }

  /// Opens the current log file for writing.
  void _openCurrentFile() {
    final filePath =
        _currentFileIndex == 0 ? basePath : '$basePath.$_currentFileIndex';
    _currentFile = File(filePath).openWrite(mode: FileMode.append);
  }

  /// Disposes the output and closes the current file.
  Future<void> dispose() async {
    await flush();
    if (_currentFile != null) {
      try {
        await _currentFile!.close();
        // coverage:ignore-start
      } on Object catch (_) {
        // Ignore all close errors including StateError for bound streams
      }
      // coverage:ignore-end
      _currentFile = null;
    }
  }
}

/// Async logger that queues log entries for background processing
class AsyncLogger extends SimpleLogger {
  /// Creates an async logger with background processing.
  AsyncLogger({
    super.debugLabel,
    super.output,
    super.observer,
    super.filter,
    super.minimumLevel,
    super.sampleRate,
    super.groupTimeout,
    super.onError,
  }) {
    _startProcessing();
  }

  final _queue = StreamController<_LogTask>.broadcast();

  @override
  bool logEntry(LogEntry entry, {String? groupId}) {
    if (!_isEnabled) return false;
    if (entry.level < minimumLevel) return false;
    if (sampleRate < 1.0 && !_shouldSample()) return false;

    _queue.add(_LogTask.entry(entry, groupId));
    return true;
  }

  @override
  bool completeGroup(String groupId) {
    if (!_isEnabled) return false;
    _queue.add(_LogTask.completeGroup(groupId));
    return true;
  }

  /// Starts processing log tasks from the queue.
  void _startProcessing() {
    _queue.stream.listen((task) {
      try {
        if (task.isEntry) {
          super.logEntry(task.entry!, groupId: task.groupId);
        } else {
          super.completeGroup(task.groupId!);
        }
      } on Exception catch (e, st) {
        _handleError(e, st);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_queue.close());
    super.dispose();
  }
}

class _LogTask {
  _LogTask.entry(this.entry, this.groupId) : isEntry = true;
  _LogTask.completeGroup(this.groupId)
      : isEntry = false,
        entry = null;

  final bool isEntry;
  final LogEntry? entry;
  final String? groupId;
}

/// JSON output implementation with frame length support
class JsonOutput extends LogOutput {
  /// Creates a JSON output with optional formatting.
  const JsonOutput({
    super.sanitizer,
    this.prettyPrint = true,
    this.frameLength = 80,
    this.writer,
  });

  /// Whether to format JSON with indentation and newlines.
  final bool prettyPrint;

  /// Maximum line length for pretty-printed JSON.
  final int frameLength;

  /// Optional custom writer function for output.
  final void Function(String)? writer;

  // ANSI color codes for JSON syntax highlighting
  static const _syntaxColors = {
    'bracket': '\x1B[36m', // Cyan for brackets
    'key': '\x1B[34m', // Blue for keys
    'colon': '\x1B[37m', // White for colons
    'comma': '\x1B[37m', // White for commas
    'string': '\x1B[32m', // Green for string values
    'number': '\x1B[33m', // Yellow for numbers
    'boolean': '\x1B[35m', // Magenta for booleans
    'reset': '\x1B[0m', // Reset color
  };

  String _colorize(String text, String color) =>
      '$color$text${_syntaxColors['reset']}';

  @override
  void writeEntry(LogEntry entry) {
    final json = sanitizer?.sanitizeJson(entry.toJson()) ?? entry.toJson();
    const encoder = JsonEncoder.withIndent(' ');
    final jsonString = encoder.convert(json);
    if (!prettyPrint) {
      (writer ?? debugPrint)(jsonString);
      return;
    }
    final buffer = StringBuffer();
    _formatPrettyJson(jsonString, buffer);
    (writer ?? debugPrint)(buffer.toString());
  }

  @override
  void writeGroup(LogGroup group, List<LogEntry> entries) {
    final json = {
      'id': group.id,
      'title': group.title,
      'description':
          sanitizer?.sanitizeText(group.description) ?? group.description,
      'entries': entries
          .map((e) => sanitizer?.sanitizeJson(e.toJson()) ?? e.toJson())
          .toList(),
    };

    final encoder = JsonEncoder.withIndent(prettyPrint ? '  ' : null);
    final jsonString = encoder.convert(json);

    if (!prettyPrint) {
      (writer ?? debugPrint)(jsonString);
      return;
    }

    final buffer = StringBuffer();
    _formatPrettyJson(jsonString, buffer);
    (writer ?? debugPrint)(buffer.toString());
  }

  void _formatPrettyJson(String jsonString, StringBuffer buffer) {
    final lines = jsonString.split('\n');
    var indentLevel = 0;
    const indentSize = 2;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      // Adjust indent level based on braces
      if (line.startsWith('}') || line.startsWith(']')) indentLevel--;

      // Calculate indentation
      final indent = ' ' * (indentLevel * indentSize);

      // Handle different line types
      if (line.contains(':')) {
        final colonIndex = line.indexOf(':');
        final key = line.substring(0, colonIndex);
        final value = line.substring(colonIndex + 1).trim();

        // Write key and colon
        buffer
          ..write(indent)
          ..write(_colorize(key, _syntaxColors['key']!))
          ..write(_colorize(':', _syntaxColors['colon']!))
          ..write(' ');
        // Format value based on type
        if (value.startsWith('"')) {
          buffer.write(_colorize(value, _syntaxColors['string']!));
        } else if (value == 'true' || value == 'false' || value == 'null') {
          buffer.write(_colorize(value, _syntaxColors['boolean']!));
        } else if (RegExp(r'^-?\d+\.?\d*([eE][+-]?\d+)?$').hasMatch(value)) {
          buffer.write(_colorize(value, _syntaxColors['number']!));
        } else {
          buffer.write(value);
        }
        buffer.writeln();
      } else {
        // Handle brackets and braces
        buffer.write(indent);
        if (line.startsWith('{') ||
            line.startsWith('[') ||
            line.startsWith('}') ||
            line.startsWith(']')) {
          buffer.write(_colorize(line, _syntaxColors['bracket']!));
        } else {
          // coverage:ignore-start
          buffer.write(line);
          // coverage:ignore-end
        }
        buffer.writeln();
      }

      // Adjust indent level for next line
      if (line.endsWith('{') || line.endsWith('[')) indentLevel++;
    }
  }

  @override
  Future<void> flush() async {}
}

/// Multi-destination output
class MultiOutput extends LogOutput {
  /// Creates a multi-output that writes to multiple destinations.
  const MultiOutput(this.outputs);

  /// List of output destinations to write to.
  final List<LogOutput> outputs;

  @override
  void writeEntry(LogEntry entry) {
    for (final output in outputs) {
      output.writeEntry(entry);
    }
  }

  @override
  void writeGroup(LogGroup group, List<LogEntry> entries) {
    for (final output in outputs) {
      output.writeGroup(group, entries);
    }
  }

  @override
  Future<void> flush() async {
    await Future.wait(outputs.map((o) => o.flush()));
  }
}

// +++++++++++++++++++++++++++++++++++++++++++++++++++++++
// ==================== LOG FORMATTER ====================
// +++++++++++++++++++++++++++++++++++++++++++++++++++++++

/// Symbols used for drawing formatted log frames.
///
/// The logger creates beautiful box-style output using Unicode or ASCII
/// characters. You can use preset styles or customize individual symbols.
///
/// Example:
/// ```dart
/// // Use ASCII preset for maximum compatibility
/// final formatter = LogFormatter(
///   symbols: LogFormatterSymbols.ascii,
/// );
///
/// // Use minimal style
/// final formatter2 = LogFormatter(
///   symbols: LogFormatterSymbols.minimal,
/// );
///
/// // Customize from preset
/// final custom = LogFormatterSymbols.minimal.copyWith(
///   vertical: '│',
///   horizontal: '═',
/// );
/// ```
class LogFormatterSymbols {
  /// Creates custom symbols for log formatting.
  ///
  /// All parameters are optional and default to Unicode box-drawing characters.
  const LogFormatterSymbols({
    this.vertical = '║',
    this.horizontal = '═',
    this.topLeft = '╔',
    this.topRight = '╗',
    this.bottomLeft = '╚',
    this.bottomRight = '╝',
    this.innerVertical = '│',
    this.innerHorizontal = '─',
    this.innerTopLeft = '╭',
    this.innerTopRight = '╮',
    this.innerBottomLeft = '╰',
    this.innerBottomRight = '╯',
    this.stateStart = '━╌╮',
    this.stateNode = '├╾',
    this.stateEnd = '└╾',
  });

  /// ASCII-only symbols for maximum compatibility.
  ///
  /// Use this preset when Unicode box-drawing characters are not supported
  /// or when you need simple ASCII output.
  static const ascii = LogFormatterSymbols(
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

  /// Minimal style with simple box-drawing characters.
  ///
  /// A cleaner look using lighter Unicode characters.
  static const minimal = LogFormatterSymbols(
    vertical: '│',
    horizontal: '─',
    topLeft: '┌',
    topRight: '┐',
    bottomLeft: '└',
    bottomRight: '┘',
    innerTopLeft: '┌',
    innerTopRight: '┐',
    innerBottomLeft: '└',
    innerBottomRight: '┘',
    stateStart: '──>',
    stateNode: '├─',
    stateEnd: '└─',
  );

  /// Vertical border character.
  final String vertical;

  /// Horizontal border character.
  final String horizontal;

  /// Top-left corner character.
  final String topLeft;

  /// Top-right corner character.
  final String topRight;

  /// Bottom-left corner character.
  final String bottomLeft;

  /// Bottom-right corner character.
  final String bottomRight;

  /// Inner vertical border character.
  final String innerVertical;

  /// Inner horizontal border character.
  final String innerHorizontal;

  /// Inner top-left corner character.
  final String innerTopLeft;

  /// Inner top-right corner character.
  final String innerTopRight;

  /// Inner bottom-left corner character.
  final String innerBottomLeft;

  /// Inner bottom-right corner character.
  final String innerBottomRight;

  /// State transition start character.
  final String stateStart;

  /// State transition node character.
  final String stateNode;

  /// State transition end character.
  final String stateEnd;

  /// Create a copy with some symbols replaced.
  ///
  /// Useful for customizing preset styles.
  ///
  /// Example:
  /// ```dart
  /// final custom = LogFormatterSymbols.ascii.copyWith(
  ///   vertical: '║',
  ///   horizontal: '═',
  /// );
  /// ```
  LogFormatterSymbols copyWith({
    String? vertical,
    String? horizontal,
    String? topLeft,
    String? topRight,
    String? bottomLeft,
    String? bottomRight,
    String? innerVertical,
    String? innerHorizontal,
    String? innerTopLeft,
    String? innerTopRight,
    String? innerBottomLeft,
    String? innerBottomRight,
    String? stateStart,
    String? stateNode,
    String? stateEnd,
  }) {
    return LogFormatterSymbols(
      vertical: vertical ?? this.vertical,
      horizontal: horizontal ?? this.horizontal,
      topLeft: topLeft ?? this.topLeft,
      topRight: topRight ?? this.topRight,
      bottomLeft: bottomLeft ?? this.bottomLeft,
      bottomRight: bottomRight ?? this.bottomRight,
      innerVertical: innerVertical ?? this.innerVertical,
      innerHorizontal: innerHorizontal ?? this.innerHorizontal,
      innerTopLeft: innerTopLeft ?? this.innerTopLeft,
      innerTopRight: innerTopRight ?? this.innerTopRight,
      innerBottomLeft: innerBottomLeft ?? this.innerBottomLeft,
      innerBottomRight: innerBottomRight ?? this.innerBottomRight,
      stateStart: stateStart ?? this.stateStart,
      stateNode: stateNode ?? this.stateNode,
      stateEnd: stateEnd ?? this.stateEnd,
    );
  }
}

/// Formats log entries and groups with visual frames and colors.
///
/// The formatter automatically adapts to your terminal:
/// - Detects terminal width (can be overridden)
/// - Detects color support (respects NO_COLOR env var)
/// - Wraps text at word boundaries for readability
///
/// Example:
/// ```dart
/// // Auto-detect terminal settings
/// final formatter = LogFormatter();
///
/// // Manual configuration
/// final customFormatter = LogFormatter(
///   frameLength: 120,
///   symbols: LogFormatterSymbols.ascii,
///   enableColors: false,
/// );
///
/// // Disable auto-detection
/// final fixedFormatter = LogFormatter(
///   frameLength: 80,
///   autoDetectWidth: false,
/// );
/// ```
class LogFormatter {
  /// Creates a log formatter with optional customization.
  ///
  /// - [frameLength]: Width of the log frame. If null, auto-detects
  ///   terminal width.
  /// - [symbols]: Symbol set to use. Defaults to Unicode box-drawing
  ///   characters.
  /// - [autoDetectWidth]: Whether to auto-detect terminal width.
  ///   Defaults to true.
  /// - [enableColors]: Whether to use colors. If null, auto-detects
  ///   support.
  LogFormatter({
    int? frameLength,
    LogFormatterSymbols? symbols,
    bool autoDetectWidth = true,
    bool? enableColors,
  })  : frameLength =
            frameLength ?? (autoDetectWidth ? detectTerminalWidth() : 80),
        symbols = symbols ?? const LogFormatterSymbols(),
        _enableColors = enableColors ?? detectColorSupport();

  /// Maximum line width for formatting.
  final int frameLength;

  /// Symbols used for drawing borders and decorations.
  final LogFormatterSymbols symbols;
  final bool _enableColors;

  /// Detects terminal width from stdout.
  ///
  /// Returns a value clamped between 40 and 200 characters for readability.
  /// Falls back to 80 if detection fails.
  ///
  /// For testing, you can pass [hasTerminal] and [terminalColumns] to simulate
  /// different terminal configurations.
  static int detectTerminalWidth({
    bool? hasTerminal,
    int? terminalColumns,
  }) {
    try {
      final actualHasTerminal = hasTerminal ?? stdout.hasTerminal;
      if (actualHasTerminal) {
        final cols = terminalColumns ?? stdout.terminalColumns;
        // Clamp to reasonable range for readability
        return cols.clamp(40, 200);
      }
      // coverage:ignore-start
    } on Object catch (_) {
      // Terminal width detection failed (including UnsupportedError on web)
    }
    // coverage:ignore-end
    return 80;
  }

  /// Detects whether the terminal supports ANSI colors.
  ///
  /// Checks:
  /// - NO_COLOR environment variable (accessibility standard)
  /// - Whether stdout is a terminal with ANSI support
  ///
  /// Returns false by default for safety.
  ///
  /// For testing, you can pass [hasNoColor], [hasTerminal], and
  /// [supportsAnsiEscapes] to simulate different terminal configurations.
  static bool detectColorSupport({
    bool? hasNoColor,
    bool? hasTerminal,
    bool? supportsAnsiEscapes,
  }) {
    try {
      // Respect NO_COLOR environment variable
      final actualHasNoColor =
          hasNoColor ?? Platform.environment.containsKey('NO_COLOR');
      if (actualHasNoColor) {
        return false;
      }
      // Check if stdout supports ANSI escapes
      final actualHasTerminal = hasTerminal ?? stdout.hasTerminal;
      final actualSupportsAnsi =
          supportsAnsiEscapes ?? stdout.supportsAnsiEscapes;
      if (actualHasTerminal && actualSupportsAnsi) {
        return true;
      }
      // coverage:ignore-start
    } on Object catch (_) {
      // Color detection failed (including UnsupportedError on web)
    }
    // coverage:ignore-end
    return false;
  }

  /// Formats a single log entry into a string.
  String formatEntry(LogEntry entry) {
    final message = (entry.message ?? '') +
        (entry.duration != null
            ? ' (${entry.duration!.inMicroseconds / 1000} ms)'
            : '');
    final isEnd = entry.duration != null;
    final strBuffer = StringBuffer()
      ..write(symbols.vertical.padRight(symbols.stateStart.length))
      ..write(isEnd ? symbols.stateEnd : symbols.stateNode)
      ..write(' ')
      ..write(_colorize(entry.timestamp.toString(), null))
      ..write(' : ')
      ..write('[')
      ..write(_colorize(entry.level.name.toUpperCase(), null))
      ..write('] ')
      ..write(_colorize(message, entry.color))
      ..writeln();
    return strBuffer.toString();
  }

  /// Formats a log group with its entries into a string.
  String formatGroup(LogGroup group, List<LogEntry> entries) {
    final strBuffer = StringBuffer()
      ..writeln(
        '${symbols.topLeft}'
        '${symbols.horizontal * frameLength}'
        '${symbols.topRight}',
      );
    _formatGroupInfo(group: group, strBuffer: strBuffer);
    strBuffer
      ..writeln()
      ..writeAll(entries.map(formatEntry))
      ..writeln(
        '${symbols.bottomLeft}'
        '${symbols.horizontal * frameLength}'
        '${symbols.bottomRight}',
      );
    return strBuffer.toString();
  }

  void _formatGroupInfo({
    required LogGroup group,
    required StringBuffer strBuffer,
  }) {
    final titleChunks = _splitIntoChunks(group.title, frameLength - 10);
    final descriptionChunks = _splitIntoChunks(
      group.description,
      frameLength - 10,
    );

    // Title
    for (final titleStr in titleChunks) {
      strBuffer
        ..write(symbols.vertical.padRight(symbols.stateStart.length))
        ..write(_colorize(titleStr, '\x1B[1m'))
        ..writeln();
    }

    if (descriptionChunks.isNotEmpty) {
      // Description frame
      const descColor = '\x1B[2m';
      final innerWidth = frameLength - symbols.stateStart.length * 2;
      strBuffer
        ..write(symbols.vertical.padRight(symbols.stateStart.length))
        ..write(
          _colorize(
            '${symbols.innerTopLeft}'
            '${symbols.innerHorizontal * innerWidth}'
            '${symbols.innerTopRight}',
            descColor,
          ),
        )
        ..writeln();

      // Description content
      for (final descChunk in descriptionChunks) {
        strBuffer
          ..write(symbols.vertical.padRight(symbols.stateStart.length))
          ..write(_colorize('${symbols.innerVertical} $descChunk', descColor))
          ..writeln();
      }

      // Description bottom frame
      strBuffer
        ..write(symbols.vertical.padRight(symbols.stateStart.length))
        ..write(
          _colorize(
            '${symbols.innerBottomLeft}'
            '${symbols.innerHorizontal * innerWidth}'
            '${symbols.innerBottomRight}',
            descColor,
          ),
        )
        ..writeln();
    }

    // Progress line
    strBuffer
      ..write(symbols.vertical)
      ..write(symbols.stateStart);
  }

  String _colorize(String text, String? color) {
    if (color == null || !_enableColors) return text;
    const reset = '\x1B[0m';
    return '$color$text$reset';
  }

  Iterable<String> _splitIntoChunks(String string, int chunkSize) {
    final strings = string.split('\n');
    final chunks = <String>[];

    for (final text in strings) {
      var start = 0;
      while (start < text.length) {
        var end =
            start + chunkSize > text.length ? text.length : start + chunkSize;
        if (end < text.length) {
          final lastSpace = text.lastIndexOf(' ', end);
          // Only use lastSpace if it's greater than start
          // to avoid infinite loop
          if (lastSpace > start) {
            end = lastSpace;
          }
          // If no space found and word is too long, force split at chunkSize
        }
        chunks.add(text.substring(start, end).trim());
        // Ensure we always advance, even if end == start
        start = end < start + 1 ? start + 1 : end + 1;
      }
    }

    return chunks;
  }
}

/// {@template mz_core.SimpleLoggerX}
/// Convenience extension methods for [SimpleLogger].
///
/// [SimpleLoggerX] provides shorthand methods for logging at each severity
/// level without manually creating [LogEntry] objects. Each method
/// corresponds to a [LogLevel] and creates an entry with the current
/// timestamp.
///
/// ## Available Methods
///
/// * **trace**: Fine-grained debug information (LogLevel.trace)
/// * **debug**: Debug messages for development (LogLevel.debug)
/// * **info**: Informational messages (LogLevel.info)
/// * **warning**: Warning messages (LogLevel.warning)
/// * **error**: Error messages (LogLevel.error)
/// * **fatal**: Critical errors (LogLevel.fatal)
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Log messages at different severity levels:
///
/// ```dart
/// final logger = SimpleLogger(
///   output: ConsoleOutput(),
///   minimumLevel: LogLevel.debug,
/// );
///
/// logger.trace('Entering method');      // Fine-grained trace
/// logger.debug('Variable value: $x');   // Debug info
/// logger.info('Operation completed');   // Informational
/// logger.warning('Disk space low');     // Warning
/// logger.error('Request failed');       // Error
/// logger.fatal('Database unavailable'); // Critical
/// ```
/// {@end-tool}
///
/// ## With Named Entries
///
/// {@tool snippet}
/// Provide a name for searchable, categorized entries:
///
/// ```dart
/// logger.info('User login successful', name: 'UserAuth');
/// logger.error('Payment failed', name: 'PaymentError');
/// logger.debug('Cache hit', name: 'CacheStats');
/// ```
/// {@end-tool}
///
/// ## With Groups
///
/// {@tool snippet}
/// Add entries to a log group:
///
/// ```dart
/// logger.startGroup(LogGroup(id: 'api-call', title: 'API Request'));
///
/// logger.debug('Sending request', groupId: 'api-call');
/// logger.info('Response received', groupId: 'api-call');
/// logger.debug('Parsing response', groupId: 'api-call');
///
/// logger.completeGroup('api-call');
/// ```
/// {@end-tool}
///
/// ## Performance Tip
///
/// These convenience methods create [LogEntry] objects, which incurs a small
/// allocation cost. For performance-critical code with logging disabled, use
/// [SimpleLogger.guard] to avoid unnecessary object creation:
///
/// {@tool snippet}
/// Guard expensive logging:
///
/// ```dart
/// logger.guard(() {
///   final expensiveData = computeDebugInfo();
///   logger.debug('Debug: $expensiveData');
/// });
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [LogEntry], for the underlying entry structure
/// * [LogLevel], for severity level definitions
/// * [SimpleLogger.logEntry], for the base logging method
/// {@endtemplate}
extension SimpleLoggerX on SimpleLogger {
  /// Logs a trace-level message.
  ///
  /// Trace is the lowest severity level, used for fine-grained debug
  /// information like method entry/exit or variable values.
  ///
  /// Example:
  /// ```dart
  /// logger.trace('Entering calculateTotal()');
  /// ```
  ///
  /// Returns `true` if the entry was logged (not filtered), `false` otherwise.
  bool trace(
    String message, {
    String? name,
    String? groupId,
    String? id,
    Duration? duration,
    Map<String, dynamic>? metaData,
  }) {
    return logEntry(
      LogEntry(
        name: name ?? 'Trace',
        level: LogLevel.trace,
        timestamp: DateTime.timestamp(),
        message: message,
        id: id,
        duration: duration,
        metadata: metaData,
      ),
      groupId: groupId,
    );
  }

  /// Logs a debug-level message.
  ///
  /// Debug messages are for development and troubleshooting information.
  ///
  /// Example:
  /// ```dart
  /// logger.debug('User ID: $userId, Status: $status');
  /// ```
  ///
  /// Returns `true` if the entry was logged (not filtered), `false` otherwise.
  bool debug(
    String message, {
    String? name,
    String? groupId,
    String? id,
    Duration? duration,
    Map<String, dynamic>? metaData,
  }) {
    return logEntry(
      LogEntry(
        name: name ?? 'Debug',
        level: LogLevel.debug,
        timestamp: DateTime.timestamp(),
        message: message,
        id: id,
        duration: duration,
        metadata: metaData,
      ),
      groupId: groupId,
    );
  }

  /// Logs an info-level message.
  ///
  /// Info messages describe normal application operation and significant
  /// events.
  ///
  /// Example:
  /// ```dart
  /// logger.info('User logged in successfully');
  /// ```
  ///
  /// Returns `true` if the entry was logged (not filtered), `false` otherwise.
  bool info(
    String message, {
    String? name,
    String? groupId,
    String? id,
    Duration? duration,
    Map<String, dynamic>? metaData,
  }) {
    return logEntry(
      LogEntry(
        name: name ?? 'Info',
        level: LogLevel.info,
        timestamp: DateTime.timestamp(),
        message: message,
        id: id,
        duration: duration,
        metadata: metaData,
      ),
      groupId: groupId,
    );
  }

  /// Logs a warning-level message.
  ///
  /// Warning messages indicate potential problems that don't prevent operation
  /// but should be investigated.
  ///
  /// Example:
  /// ```dart
  /// logger.warning('Disk space running low: ${diskSpace}MB remaining');
  /// ```
  ///
  /// Returns `true` if the entry was logged (not filtered), `false` otherwise.
  bool warning(
    String message, {
    String? name,
    String? groupId,
    String? id,
    Duration? duration,
    Map<String, dynamic>? metaData,
  }) {
    return logEntry(
      LogEntry(
        name: name ?? 'Warning',
        level: LogLevel.warning,
        timestamp: DateTime.timestamp(),
        message: message,
        id: id,
        duration: duration,
        metadata: metaData,
      ),
      groupId: groupId,
    );
  }

  /// Logs an error-level message.
  ///
  /// Error messages describe failures that were handled or recovered from,
  /// but indicate something went wrong.
  ///
  /// Example:
  /// ```dart
  /// logger.error('Failed to save user data: $errorMessage');
  /// ```
  ///
  /// Returns `true` if the entry was logged (not filtered), `false` otherwise.
  bool error(
    String message, {
    String? name,
    String? groupId,
    String? id,
    Duration? duration,
    Map<String, dynamic>? metaData,
  }) {
    return logEntry(
      LogEntry(
        name: name ?? 'Error',
        level: LogLevel.error,
        timestamp: DateTime.timestamp(),
        message: message,
        id: id,
        duration: duration,
        metadata: metaData,
      ),
      groupId: groupId,
    );
  }

  /// Logs a fatal-level message.
  ///
  /// Fatal is the highest severity level, used for critical errors that
  /// require immediate attention and may cause application failure.
  ///
  /// Example:
  /// ```dart
  /// logger.fatal('Database connection lost - cannot continue');
  /// ```
  ///
  /// Returns `true` if the entry was logged (not filtered), `false` otherwise.
  bool fatal(
    String message, {
    String? name,
    String? groupId,
    String? id,
    Duration? duration,
    Map<String, dynamic>? metaData,
  }) {
    return logEntry(
      LogEntry(
        name: name ?? 'Fatal',
        level: LogLevel.fatal,
        timestamp: DateTime.timestamp(),
        message: message,
        id: id,
        duration: duration,
        metadata: metaData,
      ),
      groupId: groupId,
    );
  }
}
