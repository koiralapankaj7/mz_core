/// A collection of Flutter and Dart utilities for common development
/// tasks.
///
/// This package provides utilities for:
/// - **Auto-disposal**: Automatically manage resource cleanup
/// - **Controllers**: Base controller classes with lifecycle management
/// - **Extensions**: Useful extensions for Iterable, List, Set, and more
/// - **Listenable Iterables**: Observable collections
/// - **Logging**: Flexible logging system with multiple outputs
/// - **Throttling/Debouncing**: Rate limiting utilities
///
/// ## Getting Started
///
/// Import the package:
/// ```dart
/// import 'package:mz_core/mz_core.dart';
/// ```
///
/// ## Examples
///
/// ### Using SimpleLogger
/// ```dart
/// final logger = SimpleLogger(
///   outputs: [ConsoleOutput()],
///   formatter: LogFormatter(),
/// );
/// logger.info('Application started');
/// ```
///
/// ### Using Extensions
/// ```dart
/// final list = [1, 2, 3, 4, 5];
/// final removed = list.removeFirstWhere((n) => n > 3); // Returns 4
/// ```
///
/// ### Using Throttler
/// ```dart
/// final throttler = Throttler(Duration(milliseconds: 500));
/// throttler.call(() => print('Throttled action'));
/// ```
library;

export 'src/auto_dispose.dart';
export 'src/controller.dart';
export 'src/debouncer.dart';
export 'src/event_manager.dart';
export 'src/extensions.dart';
export 'src/listenables.dart';
export 'src/logger.dart';
export 'src/memoizer.dart';
export 'src/throttler.dart';
export 'src/watcher.dart';
