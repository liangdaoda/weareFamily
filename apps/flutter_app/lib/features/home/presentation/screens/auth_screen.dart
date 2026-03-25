// Authentication screen with Cupertino-style role selection and login.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wearefamily_app/config/app_config.dart';
import 'package:wearefamily_app/core/api/api_client.dart';
import 'package:wearefamily_app/core/api/user_profile.dart';
import 'package:wearefamily_app/core/i18n/locale_text.dart';
import 'package:wearefamily_app/core/theme/app_colors.dart';
import 'package:wearefamily_app/core/theme/app_spacing.dart';
import 'package:wearefamily_app/core/theme/app_visual_tokens.dart';
import 'package:wearefamily_app/shared/widgets/decorative_background.dart';
import 'package:wearefamily_app/shared/widgets/glass_card.dart';
import 'package:wearefamily_app/shared/widgets/preferences_sheet.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.apiClient,
    required this.onAuthenticated,
    required this.locale,
    required this.themeMode,
    required this.onLocaleChanged,
    required this.onThemeModeChanged,
  });

  final ApiClient apiClient;
  final ValueChanged<AuthSession> onAuthenticated;
  final Locale locale;
  final ThemeMode themeMode;
  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController(text: 'broker@example.com');
  final _passwordController = TextEditingController(text: 'demo1234');
  final _confirmController = TextEditingController();

  UserRole _role = UserRole.broker;
  bool _isRegister = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _openPreferences() {
    return PreferencesSheet.show(
      context,
      locale: widget.locale,
      themeMode: widget.themeMode,
      onLocaleChanged: widget.onLocaleChanged,
      onThemeModeChanged: widget.onThemeModeChanged,
    );
  }

  Future<void> _handleLogin() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await widget.apiClient.login(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        tenantId: AppConfig.tenantId,
      );
      widget.onAuthenticated(session);
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleRegister() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await widget.apiClient.register(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        role: _role,
        tenantId: AppConfig.tenantId,
      );
      widget.onAuthenticated(session);
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _handleSso() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await widget.apiClient.ssoLogin(
        provider: 'demo',
        subject: 'demo-${_role.name}',
        email: _emailController.text.trim(),
        name: _role == UserRole.broker ? 'Demo Broker' : 'Demo Consumer',
        role: _role,
        tenantId: AppConfig.tenantId,
      );
      widget.onAuthenticated(session);
    } catch (error) {
      setState(() {
        _error = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _switchRole(UserRole role) {
    setState(() {
      _role = role;
      _emailController.text = role == UserRole.broker
          ? 'broker@example.com'
          : 'consumer@example.com';
    });
  }

  void _switchMode(bool isRegister) {
    setState(() {
      _isRegister = isRegister;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = _isRegister;
    final tokens = context.visualTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: DecorativeBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final horizontalPadding = isWide ? 96.0 : 18.0;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding, vertical: 26),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: CupertinoButton(
                        minimumSize: const Size(30, 30),
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        onPressed: _openPreferences,
                        child: Icon(
                          CupertinoIcons.settings_solid,
                          color: tokens.textSecondary,
                          size: 20,
                        ),
                      ),
                    ),
                    _HeroHeader(isWide: isWide),
                    const SizedBox(height: AppSpacing.xl),
                    GlassCard(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isRegister
                                ? context.tr('创建新账户', 'Create Account')
                                : context.tr('欢迎回来', 'Welcome Back'),
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(color: tokens.textPrimary),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _AuthModeToggle(
                              isRegister: isRegister, onChanged: _switchMode),
                          const SizedBox(height: AppSpacing.sm),
                          _RoleToggle(role: _role, onChanged: _switchRole),
                          const SizedBox(height: AppSpacing.md),
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                if (isRegister) ...[
                                  _InputField(
                                    controller: _nameController,
                                    label: context.tr('姓名', 'Name'),
                                    icon: CupertinoIcons.person,
                                    validator: _validateName,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                ],
                                _InputField(
                                  controller: _emailController,
                                  label: context.tr('邮箱', 'Email'),
                                  icon: CupertinoIcons.mail,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: _validateEmail,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                _InputField(
                                  controller: _passwordController,
                                  label: context.tr('密码', 'Password'),
                                  icon: CupertinoIcons.lock,
                                  obscureText: true,
                                  validator: isRegister
                                      ? _validateStrongPassword
                                      : _validatePassword,
                                ),
                                if (isRegister) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  _InputField(
                                    controller: _confirmController,
                                    label:
                                        context.tr('确认密码', 'Confirm Password'),
                                    icon: CupertinoIcons.lock_rotation,
                                    obscureText: true,
                                    validator: _validateConfirmPassword,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AnimatedSwitcher(
                            duration: 180.ms,
                            child: _error == null
                                ? const SizedBox.shrink()
                                : Text(
                                    _error!,
                                    key: ValueKey(_error),
                                    style:
                                        const TextStyle(color: AppColors.rose),
                                  ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: CupertinoButton.filled(
                                  onPressed: _loading
                                      ? null
                                      : isRegister
                                          ? _handleRegister
                                          : _handleLogin,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 11),
                                  borderRadius: BorderRadius.circular(9),
                                  child: _loading
                                      ? CupertinoActivityIndicator(
                                          radius: 9,
                                          color: isDark
                                              ? Colors.white
                                              : AppColors.ink,
                                        )
                                      : Text(
                                          isRegister
                                              ? context.tr(
                                                  '注册并进入', 'Register & Enter')
                                              : context.tr('登录', 'Sign In'),
                                          style: TextStyle(
                                            color: isDark
                                                ? Colors.white
                                                : AppColors.ink,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                ),
                              ),
                              if (!isRegister) ...[
                                const SizedBox(width: AppSpacing.sm),
                                CupertinoButton(
                                  onPressed: _loading ? null : _handleSso,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 11),
                                  borderRadius: BorderRadius.circular(9),
                                  color: tokens.accentSoftBg,
                                  child: Text(
                                    context.tr('演示SSO', 'Demo SSO'),
                                    style: TextStyle(color: tokens.textPrimary),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            '${context.tr('租户', 'Tenant')}: ${AppConfig.tenantId} · API: ${AppConfig.apiBaseUrl}',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: tokens.textSecondary),
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(duration: 520.ms)
                        .slideY(begin: 0.12, curve: Curves.easeOutCubic),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.tr('邮箱不能为空', 'Email is required');
    }
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value.trim())) {
      return context.tr('邮箱格式不正确', 'Invalid email format');
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.tr('密码不能为空', 'Password is required');
    }
    if (value.trim().length < 6) {
      return context.tr('密码至少6位', 'Password must be at least 6 chars');
    }
    return null;
  }

  String? _validateStrongPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.tr('密码不能为空', 'Password is required');
    }
    final trimmed = value.trim();
    if (trimmed.length < 8) {
      return context.tr('密码至少8位', 'Password must be at least 8 chars');
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(trimmed) ||
        !RegExp(r'\d').hasMatch(trimmed)) {
      return context.tr(
          '密码需包含字母和数字', 'Password must include letters and numbers');
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.tr('请再次输入密码', 'Please confirm password');
    }
    if (value.trim() != _passwordController.text.trim()) {
      return context.tr('两次输入密码不一致', 'Passwords do not match');
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return context.tr('姓名不能为空', 'Name is required');
    }
    final trimmed = value.trim();
    if (trimmed.length < 2 || trimmed.length > 20) {
      return context.tr('姓名长度需为2-20个字符', 'Name must be 2-20 characters');
    }
    return null;
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    final titleStyle = Theme.of(context).textTheme.displayLarge?.copyWith(
          color: tokens.textPrimary,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.tr('家庭保单AI管家', 'Family Policy AI Assistant'),
          style: titleStyle,
        ).animate().fadeIn(duration: 520.ms).slideY(begin: 0.1),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: isWide ? 520 : double.infinity,
          child: Text(
            context.tr(
              '面向经纪人与家庭用户的跨端保障平台，集中查看风险、到期与家庭保障结构。',
              'A cross-platform protection hub for brokers and families.',
            ),
            style: Theme.of(context)
                .textTheme
                .bodyLarge
                ?.copyWith(color: tokens.textSecondary),
          ),
        ).animate().fadeIn(duration: 520.ms, delay: 120.ms),
      ],
    );
  }
}

class _RoleToggle extends StatelessWidget {
  const _RoleToggle({required this.role, required this.onChanged});

  final UserRole role;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    final locale = Localizations.localeOf(context);

    return CupertinoSlidingSegmentedControl<UserRole>(
      groupValue: role,
      backgroundColor: tokens.accentSoftBg,
      thumbColor: tokens.accentBorder.withValues(alpha: 0.42),
      children: {
        UserRole.broker: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(UserRole.broker.displayNameFor(locale),
              style: TextStyle(color: tokens.textPrimary)),
        ),
        UserRole.consumer: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(UserRole.consumer.displayNameFor(locale),
              style: TextStyle(color: tokens.textPrimary)),
        ),
      },
      onValueChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

class _AuthModeToggle extends StatelessWidget {
  const _AuthModeToggle({required this.isRegister, required this.onChanged});

  final bool isRegister;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final thumbTextColor = isDark ? Colors.white : AppColors.ink;
    return CupertinoSlidingSegmentedControl<bool>(
      groupValue: isRegister,
      backgroundColor: tokens.accentSoftBg,
      thumbColor: tokens.accent.withValues(alpha: 0.92),
      children: {
        false: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            context.tr('登录', 'Login'),
            style:
                TextStyle(color: thumbTextColor, fontWeight: FontWeight.w700),
          ),
        ),
        true: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            context.tr('注册', 'Register'),
            style:
                TextStyle(color: thumbTextColor, fontWeight: FontWeight.w700),
          ),
        ),
      },
      onValueChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final secondary = Theme.of(context).colorScheme.secondary;
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: TextStyle(color: onSurface),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: onSurface.withValues(alpha: 0.72)),
        prefixIcon:
            Icon(icon, color: onSurface.withValues(alpha: 0.72), size: 18),
        filled: true,
        fillColor: onSurface.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide:
              BorderSide(color: secondary.withValues(alpha: 0.8), width: 1.2),
        ),
      ),
    );
  }
}
