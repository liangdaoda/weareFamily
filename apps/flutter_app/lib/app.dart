// Root MaterialApp with themes and entry gate.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wearefamily_app/config/app_config.dart';
import 'package:wearefamily_app/core/api/api_client.dart';
import 'package:wearefamily_app/core/api/user_profile.dart';
import 'package:wearefamily_app/core/theme/app_theme.dart';
import 'package:wearefamily_app/features/home/presentation/screens/auth_screen.dart';
import 'package:wearefamily_app/features/home/presentation/screens/home_shell.dart';

class WeAreFamilyApp extends StatefulWidget {
  const WeAreFamilyApp({super.key});

  @override
  State<WeAreFamilyApp> createState() => _WeAreFamilyAppState();
}

class _WeAreFamilyAppState extends State<WeAreFamilyApp> {
  Locale _locale = const Locale('zh');
  ThemeMode _themeMode = ThemeMode.system;

  void _setLocale(Locale locale) {
    setState(() {
      _locale =
          locale.languageCode == 'en' ? const Locale('en') : const Locale('zh');
    });
  }

  void _setThemeMode(ThemeMode themeMode) {
    setState(() {
      _themeMode = themeMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WeAreFamily',
      locale: _locale,
      supportedLocales: const [
        Locale('zh'),
        Locale('en'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      debugShowCheckedModeBanner: false,
      home: AuthGate(
        locale: _locale,
        themeMode: _themeMode,
        onLocaleChanged: _setLocale,
        onThemeModeChanged: _setThemeMode,
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    required this.locale,
    required this.themeMode,
    required this.onLocaleChanged,
    required this.onThemeModeChanged,
  });

  final Locale locale;
  final ThemeMode themeMode;
  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;

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
    _apiClient.setLanguage(widget.locale.languageCode);
  }

  @override
  void didUpdateWidget(covariant AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locale.languageCode != widget.locale.languageCode) {
      _apiClient.setLanguage(widget.locale.languageCode);
    }
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
        locale: widget.locale,
        themeMode: widget.themeMode,
        onLocaleChanged: widget.onLocaleChanged,
        onThemeModeChanged: widget.onThemeModeChanged,
      );
    }

    return HomeShell(
      apiClient: _apiClient,
      profile: _profile!,
      onLogout: _handleLogout,
      locale: widget.locale,
      themeMode: widget.themeMode,
      onLocaleChanged: widget.onLocaleChanged,
      onThemeModeChanged: widget.onThemeModeChanged,
    );
  }
}
