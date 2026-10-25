import 'package:flutter/material.dart';

/// Shows [message] with an Undo action, replacing any snackbar on screen.
///
/// Times out like a normal snackbar, except with a screen reader on, where
/// it stays until dismissed so there is time to reach the action.
void showUndoSnack(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
}) {
  final messenger = ScaffoldMessenger.of(context);
  final screenReader = MediaQuery.accessibleNavigationOf(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 6),
      persist: screenReader,
      action: SnackBarAction(label: 'Undo', onPressed: onUndo),
    ));
}
