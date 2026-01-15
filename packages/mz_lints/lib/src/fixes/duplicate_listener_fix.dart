// coverage:ignore-file
// Fixes require an analysis server context to test, which is not available
// in unit tests. These are tested through integration tests with the IDE.

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// A quick fix that removes a duplicate `addListener` call.
///
/// This fix is triggered by the `duplicate_listener` lint rule when the same
/// listener is added multiple times without removal.
///
/// ## Example
///
/// Before fix:
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   _controller.addListener(_onChanged);
///   _controller.addListener(_onChanged); // duplicate - will be removed
/// }
/// ```
///
/// After fix:
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   _controller.addListener(_onChanged);
/// }
/// ```
class RemoveDuplicateListener extends ResolvedCorrectionProducer {
  static const _fixKind = FixKind(
    'mz_lints.fix.removeDuplicateListener',
    50,
    'Remove duplicate addListener call',
  );

  static const _multiFixKind = FixKind(
    'mz_lints.fix.removeDuplicateListener.multi',
    50,
    'Remove all duplicate addListener calls in file',
  );

  /// Creates a [RemoveDuplicateListener] fix producer.
  RemoveDuplicateListener({required super.context});

  /// This fix can be applied to multiple occurrences in a single file.
  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.acrossSingleFile;

  /// The kind of fix for single application.
  @override
  FixKind get fixKind => _fixKind;

  /// The kind of fix for batch application across a file.
  @override
  FixKind get multiFixKind => _multiFixKind;

  /// Computes and applies the fix by removing the duplicate addListener call.
  @override
  Future<void> compute(ChangeBuilder builder) async {
    // The node should be the MethodInvocation (addListener call)
    final node = this.node;
    if (node is! MethodInvocation) return;

    final methodName = node.methodName.name;
    if (methodName != 'addListener' && methodName != 'addStatusListener') {
      return;
    }

    // Find the containing statement
    final statement = node.thisOrAncestorOfType<ExpressionStatement>();
    if (statement == null) return;

    // Calculate the range to delete including the newline
    final content = unitResult.content;
    var startOffset = statement.offset;
    var endOffset = statement.end;

    // Include leading whitespace
    while (startOffset > 0 && content[startOffset - 1] == ' ') {
      startOffset--;
    }

    // Include newline at start of line if present
    if (startOffset > 0 && content[startOffset - 1] == '\n') {
      startOffset--;
    }

    // If there's a trailing newline, include it
    if (endOffset < content.length && content[endOffset] == '\n') {
      endOffset++;
    }

    await builder.addDartFileEdit(file, (builder) {
      builder.addDeletion(SourceRange(startOffset, endOffset - startOffset));
    });
  }
}

/// A quick fix that adds a `removeListener` call before the duplicate
/// `addListener` call.
///
/// This fix is triggered by the `duplicate_listener` lint rule when a listener
/// is added in `didUpdateWidget` or `didChangeDependencies` without first
/// removing the previous listener.
///
/// ## Example
///
/// Before fix:
/// ```dart
/// @override
/// void didUpdateWidget(MyWidget oldWidget) {
///   super.didUpdateWidget(oldWidget);
///   widget.controller.addListener(_onChanged);
/// }
/// ```
///
/// After fix:
/// ```dart
/// @override
/// void didUpdateWidget(MyWidget oldWidget) {
///   super.didUpdateWidget(oldWidget);
///   oldWidget.controller.removeListener(_onChanged);
///   widget.controller.addListener(_onChanged);
/// }
/// ```
class AddRemoveBeforeAdd extends ResolvedCorrectionProducer {
  static const _fixKind = FixKind(
    'mz_lints.fix.addRemoveBeforeAdd',
    49,
    "Add 'removeListener' call before addListener",
  );

  static const _multiFixKind = FixKind(
    'mz_lints.fix.addRemoveBeforeAdd.multi',
    49,
    "Add all missing 'removeListener' calls before addListener in file",
  );

  /// Creates an [AddRemoveBeforeAdd] fix producer.
  AddRemoveBeforeAdd({required super.context});

  /// This fix can be applied to multiple occurrences in a single file.
  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.acrossSingleFile;

  /// The kind of fix for single application.
  @override
  FixKind get fixKind => _fixKind;

  /// The kind of fix for batch application across a file.
  @override
  FixKind get multiFixKind => _multiFixKind;

  /// Computes and applies the fix by adding removeListener before addListener.
  @override
  Future<void> compute(ChangeBuilder builder) async {
    // The node should be the MethodInvocation (addListener call)
    final node = this.node;
    if (node is! MethodInvocation) return;

    final methodName = node.methodName.name;
    if (methodName != 'addListener' && methodName != 'addStatusListener') {
      return;
    }

    // Get the target and callback
    final target = node.target;
    final args = node.argumentList.arguments;
    if (args.isEmpty) return;

    final callback = args.first;
    String? callbackName;
    if (callback is SimpleIdentifier) {
      callbackName = callback.name;
    } else if (callback is PrefixedIdentifier) {
      callbackName = callback.identifier.name;
    }
    if (callbackName == null) return;

    // Build the target string for removeListener
    final targetStr = _buildTargetString(target);
    if (targetStr == null) return;

    // For didUpdateWidget, try to replace 'widget.' with 'oldWidget.'
    String removeTargetStr = targetStr;
    if (targetStr.startsWith('widget.')) {
      removeTargetStr = targetStr.replaceFirst('widget.', 'oldWidget.');
    }

    // Determine the remove method name
    final removeMethod = methodName == 'addStatusListener'
        ? 'removeStatusListener'
        : 'removeListener';

    // Find the containing statement
    final statement = node.thisOrAncestorOfType<ExpressionStatement>();
    if (statement == null) return;

    // Get the indent from the current line
    final lineStart = _getLineStart(statement.offset);
    final indent = unitResult.content.substring(lineStart, statement.offset);

    await builder.addDartFileEdit(file, (builder) {
      builder.addInsertion(statement.offset, (builder) {
        builder.write('$removeTargetStr.$removeMethod($callbackName);');
        builder.writeln();
        builder.write(indent);
      });
    });
  }

  /// Gets the offset of the start of the line containing [offset].
  int _getLineStart(int offset) {
    final content = unitResult.content;
    int lineStart = offset;
    while (lineStart > 0 && content[lineStart - 1] != '\n') {
      lineStart--;
    }
    return lineStart;
  }

  String? _buildTargetString(Expression? target) {
    if (target == null) return null;
    if (target is SimpleIdentifier) {
      return target.name;
    }
    if (target is PrefixedIdentifier) {
      return '${target.prefix.name}.${target.identifier.name}';
    }
    if (target is PropertyAccess) {
      final prefix = _buildTargetString(target.target);
      if (prefix == null) return target.propertyName.name;
      return '$prefix.${target.propertyName.name}';
    }
    return null;
  }
}
