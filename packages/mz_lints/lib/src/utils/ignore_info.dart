import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

/// Utility class for checking if a lint rule should be ignored.
///
/// Supports the standard Dart ignore comment formats:
/// - `// ignore_for_file: rule1, rule2` - ignores rules for the entire file
/// - `// ignore: rule1, rule2` - ignores rules for the next line
class IgnoreInfo {
  /// The set of rules ignored for the entire file.
  final Set<String> _ignoredForFile;

  /// Map of line numbers to sets of ignored rules on that line.
  final Map<int, Set<String>> _ignoredOnLine;

  IgnoreInfo._({
    required Set<String> ignoredForFile,
    required Map<int, Set<String>> ignoredOnLine,
  }) : _ignoredForFile = ignoredForFile,
       _ignoredOnLine = ignoredOnLine;

  /// Creates an [IgnoreInfo] from a [CompilationUnit].
  factory IgnoreInfo.fromUnit(CompilationUnit unit) {
    final ignoredForFile = <String>{};
    final ignoredOnLine = <int, Set<String>>{};

    // Get all comments from the compilation unit
    final token = unit.beginToken;
    var currentToken = token;

    while (currentToken != currentToken.next &&
        currentToken.type.toString() != 'EOF') {
      // Check preceding comments
      _processCommentsForToken(
        currentToken.precedingComments,
        unit,
        ignoredForFile,
        ignoredOnLine,
      );
      currentToken = currentToken.next!;
    }

    // Also check the EOF token's preceding comments
    _processCommentsForToken(
      currentToken.precedingComments,
      unit,
      ignoredForFile,
      ignoredOnLine,
    );

    return IgnoreInfo._(
      ignoredForFile: ignoredForFile,
      ignoredOnLine: ignoredOnLine,
    );
  }

  /// Process all comments attached to a token.
  static void _processCommentsForToken(
    Token? comment,
    CompilationUnit unit,
    Set<String> ignoredForFile,
    Map<int, Set<String>> ignoredOnLine,
  ) {
    var currentComment = comment;
    while (currentComment != null) {
      final commentText = currentComment.lexeme;
      final line = unit.lineInfo.getLocation(currentComment.offset).lineNumber;
      _parseComment(commentText, line, ignoredForFile, ignoredOnLine);
      currentComment = currentComment.next;
    }
  }

  /// Parses a single comment for ignore directives.
  static void _parseComment(
    String commentText,
    int commentLine,
    Set<String> ignoredForFile,
    Map<int, Set<String>> ignoredOnLine,
  ) {
    // Remove comment markers
    var text = commentText.trim();
    if (text.startsWith('//')) {
      text = text.substring(2).trim();
    } else if (text.startsWith('/*')) {
      text = text.substring(2);
      if (text.endsWith('*/')) {
        text = text.substring(0, text.length - 2);
      }
      text = text.trim();
    }

    // Check for ignore_for_file
    if (text.startsWith('ignore_for_file:')) {
      final rules = text.substring('ignore_for_file:'.length);
      _parseRules(rules, ignoredForFile);
    }
    // Check for ignore (applies to next line)
    else if (text.startsWith('ignore:')) {
      final rules = text.substring('ignore:'.length);
      final lineRules = ignoredOnLine.putIfAbsent(commentLine + 1, () => {});
      _parseRules(rules, lineRules);
    }
  }

  /// Parses comma-separated rule names from a string.
  static void _parseRules(String rulesText, Set<String> rules) {
    final ruleNames = rulesText.split(',');
    for (final rule in ruleNames) {
      final trimmed = rule.trim();
      if (trimmed.isNotEmpty) {
        rules.add(trimmed);
      }
    }
  }

  /// Returns true if the given [ruleName] should be ignored for the entire
  /// file.
  bool isIgnoredForFile(String ruleName) {
    return _ignoredForFile.contains(ruleName);
  }

  /// Returns true if the given [ruleName] should be ignored at the given
  /// [line].
  ///
  /// This checks both file-level ignores and line-level ignores.
  bool isIgnoredAtLine(String ruleName, int line) {
    if (_ignoredForFile.contains(ruleName)) {
      return true;
    }
    final lineIgnores = _ignoredOnLine[line];
    if (lineIgnores != null && lineIgnores.contains(ruleName)) {
      return true;
    }
    return false;
  }

  /// Returns true if the given [ruleName] should be ignored at the given
  /// [node].
  ///
  /// Uses the node's offset to determine the line number.
  bool isIgnoredAtNode(String ruleName, AstNode node, CompilationUnit unit) {
    final line = unit.lineInfo.getLocation(node.offset).lineNumber;
    return isIgnoredAtLine(ruleName, line);
  }
}
