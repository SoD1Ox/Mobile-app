/// Global app state: API client + current user.  Provided via InheritedWidget.
library;

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/models.dart';

class AppScope extends InheritedWidget {
  final ApiClient api;
  final AppUser? user;
  final VoidCallback onSignedOut;
  final ValueChanged<AppUser> onUserUpdated;

  const AppScope({
    super.key,
    required this.api,
    required this.user,
    required this.onSignedOut,
    required this.onUserUpdated,
    required super.child,
  });

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.user != user || oldWidget.api != api;
}

/// Small helper to show readable error snack-bars everywhere.
void showError(BuildContext context, Object error) {
  final msg = error is ApiException
      ? error.message
      : error is Exception
          ? '$error'
          : 'Неизвестная ошибка';
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.red.shade700,
      behavior: SnackBarBehavior.floating,
    ));
}

void showInfo(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
    ));
}
