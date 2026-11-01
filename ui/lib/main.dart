/// Root of the «Кадровое агентство» (staffing agency) UI.
///
/// Responsibilities:
///  * load saved JWT tokens on start and restore the session via /auth/me;
///  * switch between LoginScreen and the authenticated app shell;
///  * expose AppScope (ApiClient + current user) to the whole widget tree;
///  * global glass Material-3 theme + the app-wide liquid-glass backdrop
///    stack (GlassRoot) shared by every screen.
library;

import 'package:flutter/material.dart';

import 'api/api_client.dart';
import 'app_state.dart';
import 'models/models.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'theme/glass.dart';
import 'theme/glass_stack.dart';

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
      title: 'Кадровое агентство',
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
      // One app-wide backdrop: aurora gradient at the bottom, page tree in
      // the middle, a single live-blur frosted overlay strip on top that the
      // current screen fills via FrostedHeader. Painted once per frame —
      // screens never re-wrap the background themselves.
      builder: (context, child) => GlassRoot(
        child: SafeArea(child: child ?? const SizedBox()),
      ),
    );
  }
}
