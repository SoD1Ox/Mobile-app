/// Root of the «Кадровое агентство» (staffing agency) UI.
///
/// Responsibilities:
///  * load saved JWT tokens on start and restore the session via /auth/me;
///  * switch between LoginScreen and the authenticated app shell;
///  * expose AppScope (ApiClient + current user) to the whole widget tree;
///  * global Material-3 theme + the app-wide lightweight visual backdrop
///    stack (GlassRoot) shared by every screen.
library;

import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'app_state.dart';
import 'models/models.dart';
import 'notifications.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'theme/glass.dart';
import 'theme/glass_stack.dart';
import 'theme/theme_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StaffingAgencyApp());
}

class StaffingAgencyApp extends StatefulWidget {
  const StaffingAgencyApp({super.key});

  @override
  State<StaffingAgencyApp> createState() => _StaffingAgencyAppState();
}

class _StaffingAgencyAppState extends State<StaffingAgencyApp> {
  final ApiClient _api = ApiClient();
  final NotificationStore _notifications = NotificationStore();
  ThemeController? _theme;
  AppUser? _user;
  bool _bootstrapping = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final theme = await ThemeController.load();
    await _api.loadTokens();
    if (_api.hasToken) {
      try {
        final me = await _api.me();
        _user = AppUser.fromJson(me);
        _onUserReady(_user!);
      } catch (_) {
        // token invalid/expired — continue to login screen
        await _api.clearTokens();
      }
    }
    if (mounted) {
      setState(() {
        _theme = theme;
        _bootstrapping = false;
      });
    }
  }

  void _onUserReady(AppUser u) {
    _notifications.currentUser = u.username;
    _notifications.loadFor(u.username);
  }

  void _signedIn(AppUser u) {
    _onUserReady(u);
    setState(() => _user = u);
  }

  void _signedOut() => setState(() => _user = null);

  @override
  Widget build(BuildContext context) {
    if (_bootstrapping || _theme == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: buildGlassTheme(),
        home: const Scaffold(body: Center(child: CircularProgressIndicator())),
        builder: (context, child) =>
            GlassRoot(child: SafeArea(child: child ?? const SizedBox())),
      );
    }
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _theme!,
      builder: (_, mode, __) => MaterialApp(
        title: 'Кадровое агентство',
        debugShowCheckedModeBanner: false,
        themeMode: mode,
        theme: buildGlassTheme(brightness: Brightness.light),
        darkTheme: buildGlassTheme(brightness: Brightness.dark),
        home: _user == null ? const LoginScreen() : const HomeScreen(),
        // One app-wide gradient behind the page tree. Mobile uses flat,
        // opaque surfaces for speed and contrast.
        // screens never re-wrap the background themselves.
        // Keep app state above the Navigator. Routes opened with push() are
        // siblings of `home`, so a provider nested inside `home` is invisible
        // to registration, company, vacancy, and other detail screens.
        builder: (context, child) => AppScope(
          api: _api,
          user: _user,
          theme: _theme!,
          notifications: _notifications,
          onSignedOut: _signedOut,
          onUserUpdated: _signedIn,
          child: GlassRoot(
            child: SafeArea(child: child ?? const SizedBox()),
          ),
        ),
      ),
    );
  }
}
