import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:mz_lints/main.dart';
import 'package:test/test.dart';

void main() {
  group('MzLintsPlugin', () {
    test('plugin has correct name', () {
      expect(plugin.name, equals('mz_lints'));
    });

    test('plugin is a Plugin instance', () {
      expect(plugin, isA<Plugin>());
    });

    test('register does not throw', () {
      final mockRegistry = _MockPluginRegistry();
      expect(() => plugin.register(mockRegistry), returnsNormally);
    });

    test('registers four warning rules', () {
      final mockRegistry = _MockPluginRegistry();
      plugin.register(mockRegistry);
      expect(mockRegistry.warningRulesCount, equals(4));
    });

    test('registers fixes for rules', () {
      final mockRegistry = _MockPluginRegistry();
      plugin.register(mockRegistry);
      // 1 fix for controller_listen_in_callback
      // 2 fixes for dispose_notifier
      // 2 fixes for duplicate_listener
      // 2 fixes for remove_listener
      expect(mockRegistry.fixesCount, equals(7));
    });
  });
}

class _MockPluginRegistry implements PluginRegistry {
  int warningRulesCount = 0;
  int lintRulesCount = 0;
  int fixesCount = 0;
  int assistsCount = 0;

  @override
  void registerWarningRule(dynamic rule) {
    warningRulesCount++;
  }

  @override
  void registerLintRule(dynamic rule) {
    lintRulesCount++;
  }

  @override
  void registerFixForRule(dynamic code, dynamic producer) {
    fixesCount++;
  }

  @override
  void registerAssist(dynamic producer) {
    assistsCount++;
  }
}
