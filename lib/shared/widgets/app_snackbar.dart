import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/error_messages.dart';

/// App-wide snackbar helpers so error/info messaging stays consistent and
/// never leaks raw exception text to the user.
///
/// - [showErrorSnack] runs any thrown error through [friendlyError] and tints
///   the bar with the negative colour. Use it in every `catch` that reaches
///   the UI instead of `Text('Failed: $e')`.
/// - [showSnack] is the general success/info toast.

void showErrorSnack(BuildContext context, Object? error) {
  if (!context.mounted) return;
  final c = context.c;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          friendlyError(error),
          style: const TextStyle(
              fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
        backgroundColor: c.negative,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

void showSnack(
  BuildContext context,
  String message, {
  bool isError = false,
  Duration duration = const Duration(seconds: 3),
}) {
  if (!context.mounted) return;
  final c = context.c;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
              fontFamily: 'Inter', fontWeight: FontWeight.w600),
        ),
        backgroundColor: isError ? c.negative : null,
        behavior: SnackBarBehavior.floating,
        duration: duration,
      ),
    );
}
