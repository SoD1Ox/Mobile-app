/// Root of the Task-tracker UI.
///
/// Responsibilities:
///  * load saved JWT tokens on start and restore the session via /auth/me;
///  * switch between LoginScreen and the authenticated app shell;
///  * expose AppScope (ApiClient + current user) to the whole widget tree;
///  * global Material-3 theme so every screen shares one style.
library;

import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'app_state.dart';
import 'models/models.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'theme/glass.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TaskTrackerApp());
}

class TaskTrackerApp extends StatefulWidget {
  const TaskTrackerApp({super.key});

  @override
  State<TaskTrackerApp> createState() => _TaskTrackerAppState();
}

class _TaskTrackerAppState extends State<TaskTrackerApp> {
  final ApiClient _api = ApiClient();
  AppUser? _user;
  bool _bootstrapping = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await _api.loadTokens();
    if (_api.hasToken) {
      try {
        final me = await _api.me();
        _user = AppUser.fromJson(me);
      } catch (_) {
        // token invalid/expired — continue to login screen
        await _api.clearTokens();
      }
    }
    if (mounted) setState(() => _bootstrapping = false);
  }

  void _signedIn(AppUser u) => setState(() => _user = u);

  void _signedOut() => setState(() => _user = null);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildGlassTheme(),
      home: AppScope(
        api: _api,
        user: _user,
        onSignedOut: _signedOut,
        onUserUpdated: _signedIn,
        child: _bootstrapping
            ? const Scaffold(body: Center(child: CircularProgressIndicator()))
            : _user == null
                ? const LoginScreen()
                : const HomeScreen(),
      ),
      // The glass background is painted once here so it sits behind every
      // route (including pushed screens) without each screen re-wrapping it.
      builder: (context, child) => AppBackground(
        child: SafeArea(child: child ?? const SizedBox()),
      ),
    );
  }
}
