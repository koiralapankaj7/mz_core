import 'package:flutter/material.dart';
import 'package:mz_core_example/screens/controller_demo_screen.dart';
import 'package:mz_core_example/screens/logger_demo_screen.dart';
import 'package:mz_core_example/screens/rate_limiting_demo_screen.dart';
import 'package:mz_core_example/screens/collections_demo_screen.dart';
import 'package:mz_core_example/screens/extensions_demo_screen.dart';

void main() {
  runApp(const MzCoreExampleApp());
}

class MzCoreExampleApp extends StatelessWidget {
  const MzCoreExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mz_core Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('mz_core Feature Demos'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _FeatureCard(
            title: 'State Management',
            description:
                'Controller with key-based notifications, '
                'priorities, and predicates',
            icon: Icons.settings_input_component,
            color: Colors.blue,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ControllerDemoScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _FeatureCard(
            title: 'Logging System',
            description: 'SimpleLogger with levels, groups, and outputs',
            icon: Icons.description,
            color: Colors.green,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => const LoggerDemoScreen()),
            ),
          ),
          const SizedBox(height: 16),
          _FeatureCard(
            title: 'Rate Limiting',
            description: 'Debouncing and throttling utilities',
            icon: Icons.speed,
            color: Colors.orange,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const RateLimitingDemoScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _FeatureCard(
            title: 'Observable Collections',
            description: 'ListenableList and ListenableSet',
            icon: Icons.list,
            color: Colors.purple,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const CollectionsDemoScreen(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _FeatureCard(
            title: 'Extension Methods',
            description: 'Utilities for Iterable, List, Set, String, and more',
            icon: Icons.extension,
            color: Colors.teal,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => const ExtensionsDemoScreen(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}
