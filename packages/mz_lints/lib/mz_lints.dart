/// Custom lint rules for Flutter apps using mz_core.
///
/// This library provides analyzer plugin rules that help prevent common
/// mistakes when working with Flutter's state management patterns:
///
/// - [ControllerListenInCallback] - Warns when `Controller.ofType` is called
///   from a callback without `listen: false`.
/// - [DisposeNotifier] - Ensures `ChangeNotifier` subclasses are properly
///   disposed in `State` classes.
/// - [RemoveListener] - Verifies that `addListener` calls have matching
///   `removeListener` calls in `dispose()`.
/// - [DuplicateListener] - Warns when the same listener is added multiple
///   times without removal.
///
/// ## Usage
///
/// Add mz_lints to your `analysis_options.yaml`:
///
/// ```yaml
/// analyzer:
///   plugins:
///     - mz_lints
/// ```
///
/// The rules are registered as warnings and enabled by default.
library;

import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:mz_lints/src/fixes/controller_listen_fix.dart';
import 'package:mz_lints/src/fixes/dispose_notifier_fix.dart';
import 'package:mz_lints/src/fixes/duplicate_listener_fix.dart';
import 'package:mz_lints/src/fixes/remove_listener_fix.dart';
import 'package:mz_lints/src/rules/controller_listen_in_callback.dart';
import 'package:mz_lints/src/rules/dispose_notifier.dart';
import 'package:mz_lints/src/rules/duplicate_listener.dart';
import 'package:mz_lints/src/rules/remove_listener.dart';

/// The plugin instance that the Dart analysis server uses.
///
/// This singleton is automatically discovered and loaded by the analyzer
/// when mz_lints is listed in the `analyzer.plugins` section of
/// `analysis_options.yaml`.
final plugin = MzLintsPlugin();

/// An analyzer plugin that provides custom lint rules for mz_core.
///
/// This plugin registers warning-level lint rules that detect common
/// mistakes in Flutter state management:
///
/// - Missing `listen: false` in callbacks
/// - Undisposed `ChangeNotifier` instances
/// - Missing `removeListener` calls
/// - Duplicate `addListener` calls without removal
///
/// Each rule includes quick fixes to automatically resolve the issues.
class MzLintsPlugin extends Plugin {
  /// The unique identifier for this plugin.
  @override
  String get name => 'mz_lints';

  /// Registers all lint rules and their associated quick fixes.
  ///
  /// The rules are registered as warnings, meaning they are enabled by default
  /// without requiring explicit configuration in `analysis_options.yaml`.
  @override
  void register(PluginRegistry registry) {
    // Register as warning rules (enabled by default, no need to list in linter)
    registry.registerWarningRule(ControllerListenInCallback());
    registry.registerWarningRule(DisposeNotifier());
    registry.registerWarningRule(DuplicateListener());
    registry.registerWarningRule(RemoveListener());

    // Register quick fixes for controller_listen_in_callback
    registry.registerFixForRule(
      ControllerListenInCallback.code,
      AddListenFalse.new,
    );

    // Register quick fixes for dispose_notifier
    registry.registerFixForRule(DisposeNotifier.code, AddDisposeMethod.new);
    registry.registerFixForRule(DisposeNotifier.code, AddDisposeCall.new);

    // Register quick fixes for duplicate_listener
    registry.registerFixForRule(
      DuplicateListener.code,
      RemoveDuplicateListener.new,
    );
    registry.registerFixForRule(DuplicateListener.code, AddRemoveBeforeAdd.new);

    // Register quick fixes for remove_listener
    registry.registerFixForRule(RemoveListener.code, AddRemoveListenerCall.new);
    registry.registerFixForRule(
      RemoveListener.code,
      UseAutoDisposeListener.new,
    );

    // To register as lint (must be explicitly enabled), use:
    // registry.registerLintRule(MyRule());

    // To register an assist (not tied to a diagnostic), use:
    // registry.registerAssist(MyAssist.new);
  }
}
