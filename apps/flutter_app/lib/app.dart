// Root MaterialApp with themes and entry gate.
import 'package:flutter/material.dart';
import 'package:wearefamily_app/config/app_config.dart';
import 'package:wearefamily_app/core/api/api_client.dart';
import 'package:wearefamily_app/core/api/user_profile.dart';
import 'package:wearefamily_app/core/theme/app_theme.dart';
import 'package:wearefamily_app/features/home/presentation/screens/auth_screen.dart';
import 'package:wearefamily_app/features/home/presentation/screens/home_shell.dart';

class WeAreFamilyApp extends StatelessWidget {
  const WeAreFamilyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeAreFamily',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final ApiClient _apiClient;
  AuthSession? _session;
  UserProfile? _profile;

  @override
  void initState() {
    super.initState();
    _apiClient = ApiClient(baseUrl: AppConfig.apiBaseUrl);
  }

  @override
  void dispose() {
    _apiClient.dispose();
    super.dispose();
  }

  void _handleAuthenticated(AuthSession session) {
    setState(() {
      _session = session;
      _profile = UserProfile.fromAuthUser(session.user);
      _apiClient.setAccessToken(session.accessToken);
    });
  }

  void _handleLogout() {
    setState(() {
      _session = null;
      _profile = null;
      _apiClient.setAccessToken(null);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null || _profile == null) {
      return AuthScreen(
        apiClient: _apiClient,
        onAuthenticated: _handleAuthenticated,
      );
    }

    return HomeShell(
      apiClient: _apiClient,
      profile: _profile!,
      onLogout: _handleLogout,
    );
  }
}


