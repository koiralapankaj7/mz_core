// coverage:ignore-file
// Fixes require an analysis server context to test, which is not available
// in unit tests. These are tested through integration tests with the IDE.

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// A quick fix that adds `listen: false` to Controller lookup calls.
///
/// This fix is triggered by the `controller_listen_in_callback` lint rule
/// when `Controller.ofType` or `Controller.maybeOfType` is called from a
/// callback without specifying `listen: false`.
///
/// ## Example
///
/// Before fix:
/// ```dart
/// onPressed: () {
///   final ctrl = Controller.ofType<MyController>(context);
/// }
/// ```
///
/// After fix:
/// ```dart
/// onPressed: () {
///   final ctrl = Controller.ofType<MyController>(context, listen: false);
/// }
/// ```
class AddListenFalse extends ResolvedCorrectionProducer {
  static const _fixKind = FixKind(
    'mz_lints.fix.addListenFalse',
    50, // priority
    "Add 'listen: false'",
  );

  static const _multiFixKind = FixKind(
    'mz_lints.fix.addListenFalse.multi',
    50,
    "Add 'listen: false' to all Controller lookups in callbacks",
  );

  /// Creates an [AddListenFalse] fix producer.
  AddListenFalse({required super.context});

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

  /// Computes and applies the fix by inserting `listen: false` argument.
  @override
  Future<void> compute(ChangeBuilder builder) async {
    // Find the MethodInvocation node
    final node = this.node;
    if (node is! SimpleIdentifier) return;

    final parent = node.parent;
    if (parent is! MethodInvocation) return;

    final args = parent.argumentList;
    final rightParen = args.rightParenthesis;

    await builder.addDartFileEdit(file, (builder) {
      // Check if there are existing arguments
      if (args.arguments.isEmpty) {
        // No arguments - should have context, so add after it
        // Actually, ofType/maybeOfType always has context as first arg
        // So we need to add the named parameter after
        final lastArg = args.arguments.lastOrNull;
        if (lastArg != null) {
          builder.addSimpleInsertion(lastArg.end, ', listen: false');
        } else {
          // Shouldn't happen, but just in case
          builder.addSimpleInsertion(rightParen.offset, 'listen: false');
        }
      } else {
        // Has arguments, add after the last one
        final lastArg = args.arguments.last;
        builder.addSimpleInsertion(lastArg.end, ', listen: false');
      }
    });
  }
}
