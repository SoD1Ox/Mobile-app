/// Global app state: API client + current user + theme controller.
/// Provided via InheritedWidget.
library;

import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/models.dart';
import '../theme/theme_controller.dart';
import 'notifications.dart';

class AppScope extends InheritedWidget {
  final ApiClient api;
  final AppUser? user;
  final ThemeController theme;
  final NotificationStore notifications;
  final VoidCallback onSignedOut;
  final ValueChanged<AppUser> onUserUpdated;

  const AppScope({
    super.key,
    required this.api,
    required this.user,
    required this.theme,
    required this.notifications,
    required this.onSignedOut,
    required this.onUserUpdated,
    required super.child,
  });

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  /// Non-subscribing lookup.  Used inside long-lived tab widgets so that a
  /// rebuild of the scope (e.g. after user update) does not force every tab
  /// to recreate its state.
  static AppScope read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope oldWidget) =>
      oldWidget.user != user ||
      oldWidget.api != api ||
      oldWidget.theme != theme ||
      oldWidget.notifications != notifications;
}

/// Small helper to show readable error snack-bars everywhere.
void showError(BuildContext context, Object error) {
  final msg = error is ApiException
      ? error.message
      : error.toString().isEmpty
          ? 'Неизвестная ошибка'
          : error.toString();
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
