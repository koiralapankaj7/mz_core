# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.1] - 2026-01-09

### Added

- Initial release
- `dispose_notifier` lint rule - ensures ChangeNotifier instances are disposed in State classes
- `remove_listener` lint rule - ensures listeners are removed in dispose method
- `controller_listen_in_callback` lint rule - warns about Controller lookups without `listen: false`
- Quick fixes for all lint rules
- Support for `// ignore_for_file:` and `// ignore:` comments to suppress rules
- 100% test coverage on all lint rules
