// coverage:ignore-file
// Fixes require an analysis server context to test, which is not available
// in unit tests. These are tested through integration tests with the IDE.

import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/source_range.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

/// A quick fix that adds a `removeListener` call to the `dispose()` method.
///
/// This fix is triggered by the `remove_listener` lint rule when an
/// `addListener` call is detected without a matching `removeListener` in
/// `dispose()`.
///
/// ## Example
///
/// Before fix:
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   _controller.addListener(_onChanged);
/// }
///
/// @override
/// void dispose() {
///   super.dispose();
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
///
/// @override
/// void dispose() {
///   _controller.removeListener(_onChanged);
///   super.dispose();
/// }
/// ```
class AddRemoveListenerCall extends ResolvedCorrectionProducer {
  static const _fixKind = FixKind(
    'mz_lints.fix.addRemoveListenerCall',
    50,
    "Add 'removeListener' call to dispose()",
  );

  static const _multiFixKind = FixKind(
    'mz_lints.fix.addRemoveListenerCall.multi',
    50,
    "Add all missing 'removeListener' calls in file",
  );

  /// Creates an [AddRemoveListenerCall] fix producer.
  AddRemoveListenerCall({required super.context});

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

  /// Computes and applies the fix by adding a `removeListener` call.
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

    // Build the target string
    String? targetStr;
    if (target is SimpleIdentifier) {
      targetStr = target.name;
    } else if (target is PrefixedIdentifier) {
      targetStr = '${target.prefix.name}.${target.identifier.name}';
    } else if (target is PropertyAccess) {
      targetStr = _buildTargetString(target);
    }
    if (targetStr == null) return;

    // Determine the remove method name
    final removeMethod = methodName == 'addStatusListener'
        ? 'removeStatusListener'
        : 'removeListener';

    // Find the containing class
    final classDeclaration = node.thisOrAncestorOfType<ClassDeclaration>();
    if (classDeclaration == null) return;

    // Find or create dispose method
    MethodDeclaration? disposeMethod;
    for (final member in classDeclaration.members) {
      if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
        disposeMethod = member;
        break;
      }
    }

    if (disposeMethod == null) {
      // Add a new dispose method
      final lastMember = classDeclaration.members.lastOrNull;
      if (lastMember == null) return;

      await builder.addDartFileEdit(file, (builder) {
        builder.addInsertion(lastMember.end, (builder) {
          builder.writeln();
          builder.writeln();
          builder.writeln('  @override');
          builder.writeln('  void dispose() {');
          builder.writeln('    $targetStr.$removeMethod($callbackName);');
          builder.writeln('    super.dispose();');
          builder.write('  }');
        });
      });
    } else {
      // Add to existing dispose method
      final body = disposeMethod.body;
      if (body is! BlockFunctionBody) return;

      final block = body.block;

      // Find super.dispose() call to insert before it
      ExpressionStatement? superDisposeStatement;
      for (final statement in block.statements) {
        if (statement is ExpressionStatement) {
          final expr = statement.expression;
          if (expr is MethodInvocation &&
              expr.methodName.name == 'dispose' &&
              expr.target is SuperExpression) {
            superDisposeStatement = statement;
            break;
          }
        }
      }

      await builder.addDartFileEdit(file, (builder) {
        if (superDisposeStatement != null) {
          // Insert before super.dispose() - get indent from that line
          final lineStart = _getLineStart(superDisposeStatement.offset);
          final indent = unitResult.content.substring(
            lineStart,
            superDisposeStatement.offset,
          );
          builder.addInsertion(superDisposeStatement.offset, (builder) {
            builder.write('$targetStr.$removeMethod($callbackName);');
            builder.writeln();
            builder.write(indent);
          });
        } else if (block.statements.isNotEmpty) {
          // No super.dispose(), insert after last statement
          final lastStatement = block.statements.last;
          final lineStart = _getLineStart(lastStatement.offset);
          final indent = unitResult.content.substring(
            lineStart,
            lastStatement.offset,
          );
          builder.addInsertion(lastStatement.end, (builder) {
            builder.writeln();
            builder.write('$indent$targetStr.$removeMethod($callbackName);');
          });
        } else {
          // Empty dispose method, insert before closing brace
          final lineStart = _getLineStart(block.rightBracket.offset);
          final braceIndent = unitResult.content.substring(
            lineStart,
            block.rightBracket.offset,
          );
          // Statement indent is typically brace indent + 2 spaces
          final stmtIndent = '$braceIndent  ';
          builder.addInsertion(block.rightBracket.offset, (builder) {
            builder.write(
              '$stmtIndent$targetStr.$removeMethod($callbackName);',
            );
            builder.writeln();
          });
        }
      });
    }
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

  String? _buildTargetString(PropertyAccess access) {
    final target = access.target;
    String? prefix;
    if (target is SimpleIdentifier) {
      prefix = target.name;
    } else if (target is PropertyAccess) {
      prefix = _buildTargetString(target);
    } else if (target is PrefixedIdentifier) {
      prefix = '${target.prefix.name}.${target.identifier.name}';
    }
    if (prefix == null) return null;
    return '$prefix.${access.propertyName.name}';
  }
}

/// A quick fix that replaces `addListener` with `addAutoDisposeListener`.
///
/// This fix is an alternative to [AddRemoveListenerCall] that uses the
/// mz_utils auto-dispose pattern instead of manual listener management.
///
/// ## Example
///
/// Before fix:
/// ```dart
/// _controller.addListener(_onChanged);
/// ```
///
/// After fix:
/// ```dart
/// addAutoDisposeListener(_controller, _onChanged);
/// ```
///
/// **Note:** This requires the `addAutoDisposeListener` extension method
/// from mz_utils to be available in the current scope.
class UseAutoDisposeListener extends ResolvedCorrectionProducer {
  static const _fixKind = FixKind(
    'mz_lints.fix.useAutoDisposeListener',
    49,
    "Use 'addAutoDisposeListener' instead",
  );

  static const _multiFixKind = FixKind(
    'mz_lints.fix.useAutoDisposeListener.multi',
    49,
    "Use 'addAutoDisposeListener' everywhere in file",
  );

  /// Creates a [UseAutoDisposeListener] fix producer.
  UseAutoDisposeListener({required super.context});

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

  /// Computes and applies the fix by replacing with `addAutoDisposeListener`.
  @override
  Future<void> compute(ChangeBuilder builder) async {
    // The node should be the MethodInvocation (addListener call)
    final node = this.node;
    if (node is! MethodInvocation) return;

    final methodName = node.methodName.name;
    if (methodName != 'addListener') return;

    // Get the target and callback
    final target = node.target;
    final args = node.argumentList.arguments;
    if (args.isEmpty) return;

    final callback = args.first;

    // Build the target string
    String? targetStr;
    if (target is SimpleIdentifier) {
      targetStr = target.name;
    } else if (target is PrefixedIdentifier) {
      targetStr = '${target.prefix.name}.${target.identifier.name}';
    } else if (target is PropertyAccess) {
      targetStr = _buildTargetString(target);
    }
    if (targetStr == null) return;

    // Get the callback source
    final callbackSource = callback.toSource();

    // Find the containing statement
    final statement = node.thisOrAncestorOfType<ExpressionStatement>();
    if (statement == null) return;

    await builder.addDartFileEdit(file, (builder) {
      builder.addReplacement(SourceRange(statement.offset, statement.length), (
        builder,
      ) {
        builder.write('addAutoDisposeListener($targetStr, $callbackSource);');
      });
    });
  }

  String? _buildTargetString(PropertyAccess access) {
    final target = access.target;
    String? prefix;
    if (target is SimpleIdentifier) {
      prefix = target.name;
    } else if (target is PropertyAccess) {
      prefix = _buildTargetString(target);
    } else if (target is PrefixedIdentifier) {
      prefix = '${target.prefix.name}.${target.identifier.name}';
    }
    if (prefix == null) return null;
    return '$prefix.${access.propertyName.name}';
  }
}
