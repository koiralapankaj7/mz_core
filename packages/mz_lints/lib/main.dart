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

/// The plugin instance that the analysis server will use.
final plugin = MzLintsPlugin();

/// A plugin that provides custom lint rules for mz_utils.
class MzLintsPlugin extends Plugin {
  @override
  String get name => 'mz_lints';

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
