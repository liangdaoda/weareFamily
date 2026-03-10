// Authentication screen with role selection and login.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wearefamily_app/config/app_config.dart';
import 'package:wearefamily_app/core/api/api_client.dart';
import 'package:wearefamily_app/core/api/user_profile.dart';
import 'package:wearefamily_app/core/theme/app_colors.dart';
import 'package:wearefamily_app/core/theme/app_spacing.dart';
import 'package:wearefamily_app/shared/widgets/decorative_background.dart';
import 'package:wearefamily_app/shared/widgets/glass_card.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({
    super.key,
    required this.apiClient,
    required this.onAuthenticated,
  });

  final ApiClient apiClient;
  final ValueChanged<AuthSession> onAuthenticated;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController(text: 'broker@example.com');
  final _passwordController = TextEditingController(text: 'demo1234');
  UserRole _role = UserRole.broker;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
      _emailController.text =
          role == UserRole.broker ? 'broker@example.com' : 'consumer@example.com';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecorativeBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 900;
              final horizontalPadding = isWide ? 120.0 : 24.0;

              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 36),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroHeader(isWide: isWide),
                    const SizedBox(height: AppSpacing.xl),
                    GlassCard(
                      padding: const EdgeInsets.all(28),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Welcome back',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _RoleToggle(role: _role, onChanged: _switchRole),
                          const SizedBox(height: AppSpacing.md),
                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                _InputField(
                                  controller: _emailController,
                                  label: 'Email',
                                  icon: Icons.alternate_email,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                _InputField(
                                  controller: _passwordController,
                                  label: 'Password',
                                  icon: Icons.lock_outline,
                                  obscureText: true,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AnimatedSwitcher(
                            duration: 200.ms,
                            child: _error == null
                                ? const SizedBox.shrink()
                                : Text(
                                    _error!,
                                    key: ValueKey(_error),
                                    style: const TextStyle(color: AppColors.rose),
                                  ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: AppColors.ink,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Sign In'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              OutlinedButton(
                                onPressed: _loading ? null : _handleSso,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: BorderSide(color: Colors.white.withOpacity(0.3)),
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text('SSO Demo'),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Tenant: ${AppConfig.tenantId} · API: ${AppConfig.apiBaseUrl}',
                            style: Theme.of(context)
                                .textTheme
                                .labelLarge
                                ?.copyWith(color: Colors.white70),
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.2, curve: Curves.easeOutCubic),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _HeroHeader extends StatelessWidget {
  const _HeroHeader({required this.isWide});

  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.displayLarge?.copyWith(color: Colors.white);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'WeAreFamily',
          style: titleStyle,
        ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.15),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: isWide ? 520 : double.infinity,
          child: Text(
            'AI-powered policy intelligence for brokers and families. A calm command center that keeps every household covered.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
          ),
        ).animate().fadeIn(duration: 600.ms, delay: 120.ms),
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
    return Wrap(
      spacing: AppSpacing.sm,
      children: UserRole.values.take(2).map((option) {
        final selected = option == role;
        return ChoiceChip(
          label: Text(option.displayName),
          selected: selected,
          selectedColor: AppColors.mint,
          labelStyle: TextStyle(color: selected ? AppColors.ink : Colors.white70),
          backgroundColor: Colors.white.withOpacity(0.08),
          onSelected: (_) => onChanged(option),
        );
      }).toList(),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField({
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Required';
        }
        return null;
      },
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        prefixIcon: Icon(icon, color: Colors.white70),
        filled: true,
        fillColor: Colors.white.withOpacity(0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

