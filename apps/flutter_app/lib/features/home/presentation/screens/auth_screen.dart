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
        name: _role == UserRole.broker ? '演示经纪人' : '演示家庭用户',
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

  void _switchMode(bool isRegister) {
    setState(() {
      _isRegister = isRegister;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = _isRegister;

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
                            isRegister ? '创建新账号' : '欢迎回来',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          _AuthModeToggle(isRegister: isRegister, onChanged: _switchMode),
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
                                    label: '姓名',
                                    icon: Icons.badge_outlined,
                                    validator: _validateName,
                                  ),
                                  const SizedBox(height: AppSpacing.sm),
                                ],
                                _InputField(
                                  controller: _emailController,
                                  label: '邮箱',
                                  icon: Icons.alternate_email,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: _validateEmail,
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                _InputField(
                                  controller: _passwordController,
                                  label: '密码',
                                  icon: Icons.lock_outline,
                                  obscureText: true,
                                  validator: isRegister ? _validateStrongPassword : _validatePassword,
                                ),
                                if (isRegister) ...[
                                  const SizedBox(height: AppSpacing.sm),
                                  _InputField(
                                    controller: _confirmController,
                                    label: '确认密码',
                                    icon: Icons.lock_reset_outlined,
                                    obscureText: true,
                                    validator: _validateConfirmPassword,
                                  ),
                                ],
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
                                  onPressed: _loading
                                      ? null
                                      : isRegister
                                          ? _handleRegister
                                          : _handleLogin,
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
                                      : Text(isRegister ? '注册并进入' : '登录'),
                                ),
                              ),
                              if (!isRegister) ...[
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
                                  child: const Text('演示SSO'),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            '租户: ${AppConfig.tenantId} · API: ${AppConfig.apiBaseUrl}',
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

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '邮箱不能为空';
    }
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(value.trim())) {
      return '邮箱格式不正确';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '密码不能为空';
    }
    if (value.trim().length < 6) {
      return '密码至少6位';
    }
    return null;
  }

  String? _validateStrongPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '密码不能为空';
    }
    final trimmed = value.trim();
    if (trimmed.length < 8) {
      return '密码至少8位';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(trimmed) || !RegExp(r'\d').hasMatch(trimmed)) {
      return '密码需包含字母和数字';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请再次输入密码';
    }
    if (value.trim() != _passwordController.text.trim()) {
      return '两次输入的密码不一致';
    }
    return null;
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '姓名不能为空';
    }
    final trimmed = value.trim();
    if (trimmed.length < 2 || trimmed.length > 20) {
      return '姓名长度需为2-20个字符';
    }
    return null;
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
          '家庭保单AI管家',
          style: titleStyle,
        ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.15),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: isWide ? 520 : double.infinity,
          child: Text(
            '面向经纪人与家庭的保障中枢，实时洞察风险与续期节奏。',
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

class _AuthModeToggle extends StatelessWidget {
  const _AuthModeToggle({required this.isRegister, required this.onChanged});

  final bool isRegister;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _ModeChip(
            label: '登录',
            selected: !isRegister,
            onTap: () => onChanged(false),
          ),
          _ModeChip(
            label: '注册',
            selected: isRegister,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: 200.ms,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.mint : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? AppColors.ink : Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
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
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white),
      validator: validator,
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
