// Policy creation form for manual policy entry.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wearefamily_app/core/api/api_client.dart';
import 'package:wearefamily_app/core/api/user_profile.dart';
import 'package:wearefamily_app/core/theme/app_colors.dart';
import 'package:wearefamily_app/core/theme/app_spacing.dart';
import 'package:wearefamily_app/shared/widgets/decorative_background.dart';
import 'package:wearefamily_app/shared/widgets/glass_card.dart';

class PolicyCreateScreen extends StatefulWidget {
  const PolicyCreateScreen({super.key, required this.profile, required this.apiClient});

  final UserProfile profile;
  final ApiClient apiClient;

  @override
  State<PolicyCreateScreen> createState() => _PolicyCreateScreenState();
}

class _PolicyCreateScreenState extends State<PolicyCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _policyNoController = TextEditingController();
  final _insurerController = TextEditingController();
  final _productController = TextEditingController();
  final _premiumController = TextEditingController();
  final _currencyController = TextEditingController(text: 'CNY');
  final _startDateController = TextEditingController();
  final _endDateController = TextEditingController();
  final _notesController = TextEditingController();

  String? _familyId;
  String _status = 'active';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _policyNoController.dispose();
    _insurerController.dispose();
    _productController.dispose();
    _premiumController.dispose();
    _currencyController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('新建保单', style: TextStyle(color: Colors.white)),
      ),
      body: DecorativeBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final padding = EdgeInsets.fromLTRB(
              isWide ? 64 : AppSpacing.lg,
              kToolbarHeight + MediaQuery.of(context).padding.top + AppSpacing.lg,
              isWide ? 64 : AppSpacing.lg,
              AppSpacing.lg,
            );

            return FutureBuilder<List<Family>>(
              future: widget.apiClient.fetchFamilies(widget.profile),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.accent));
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text('加载家庭失败: ${snapshot.error}', style: const TextStyle(color: Colors.white70)),
                  );
                }

                final families = snapshot.data ?? [];
                if (families.isEmpty) {
                  return const Center(
                    child: Text('请先创建家庭档案后再添加保单。', style: TextStyle(color: Colors.white70)),
                  );
                }

                _familyId ??= families.first.id;

                return SingleChildScrollView(
                  padding: padding,
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '手动录入保单信息',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          '适用于纸质保单或非标准 PDF 场景。',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _SectionTitle('基础信息'),
                              const SizedBox(height: AppSpacing.sm),
                              DropdownButtonFormField<String>(
                                value: _familyId,
                                decoration: _inputDecoration('所属家庭'),
                                items: families
                                    .map((family) => DropdownMenuItem(
                                          value: family.id,
                                          child: Text(family.name),
                                        ))
                                    .toList(),
                                onChanged: (value) => setState(() => _familyId = value),
                                validator: (value) => value == null ? '请选择家庭' : null,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              TextFormField(
                                controller: _policyNoController,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration('保单号'),
                                validator: _requiredValidator('保单号'),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              TextFormField(
                                controller: _insurerController,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration('保险公司'),
                                validator: _requiredValidator('保险公司'),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              TextFormField(
                                controller: _productController,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration('产品名称'),
                                validator: _requiredValidator('产品名称'),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _SectionTitle('保费与状态'),
                              const SizedBox(height: AppSpacing.sm),
                              TextFormField(
                                controller: _premiumController,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration('年缴保费（数字）'),
                                keyboardType: TextInputType.number,
                                validator: _premiumValidator,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              TextFormField(
                                controller: _currencyController,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration('币种（默认 CNY）'),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              DropdownButtonFormField<String>(
                                value: _status,
                                decoration: _inputDecoration('状态'),
                                items: const [
                                  DropdownMenuItem(value: 'active', child: Text('生效中')),
                                  DropdownMenuItem(value: 'pending', child: Text('待生效')),
                                  DropdownMenuItem(value: 'expired', child: Text('已到期')),
                                  DropdownMenuItem(value: 'cancelled', child: Text('已终止')),
                                ],
                                onChanged: (value) => setState(() => _status = value ?? 'active'),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _SectionTitle('保障期限'),
                              const SizedBox(height: AppSpacing.sm),
                              _DateField(
                                controller: _startDateController,
                                label: '生效日期（必填）',
                                onPick: () => _pickDate(_startDateController),
                                validator: _requiredValidator('生效日期'),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              _DateField(
                                controller: _endDateController,
                                label: '到期日期（选填）',
                                onPick: () => _pickDate(_endDateController),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              _SectionTitle('备注'),
                              const SizedBox(height: AppSpacing.sm),
                              TextFormField(
                                controller: _notesController,
                                style: const TextStyle(color: Colors.white),
                                decoration: _inputDecoration('补充说明（选填）'),
                                maxLines: 3,
                              ),
                            ],
                          ),
                        ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08),
                        const SizedBox(height: AppSpacing.lg),
                        if (_error != null)
                          Text(_error!, style: const TextStyle(color: AppColors.rose)),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submitting ? null : _handleSubmit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: AppColors.ink,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _submitting
                                ? const SizedBox(
                                    height: 18,
                                    width: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Text('保存保单'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String? Function(String?) _requiredValidator(String label) {
    return (String? value) {
      if (value == null || value.trim().isEmpty) {
        return '$label不能为空';
      }
      return null;
    };
  }

  String? _premiumValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return '请输入保费';
    }
    final parsed = double.tryParse(value.trim());
    if (parsed == null || parsed <= 0) {
      return '保费必须为大于0的数字';
    }
    return null;
  }

  Future<void> _pickDate(TextEditingController controller) async {
    final now = DateTime.now();
    final initial = _tryParseDate(controller.text) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year - 50),
      lastDate: DateTime(now.year + 50),
    );
    if (picked != null) {
      controller.text = _formatDate(picked);
    }
  }

  DateTime? _tryParseDate(String value) {
    if (value.trim().isEmpty) {
      return null;
    }
    try {
      return DateTime.parse(value.trim());
    } catch (_) {
      return null;
    }
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  Future<void> _handleSubmit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }

    if (_familyId == null) {
      setState(() => _error = '请选择家庭');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final premium = double.parse(_premiumController.text.trim());
      final created = await widget.apiClient.createPolicy(
        profile: widget.profile,
        familyId: _familyId!,
        policyNo: _policyNoController.text.trim(),
        insurerName: _insurerController.text.trim(),
        productName: _productController.text.trim(),
        premium: premium,
        currency: _currencyController.text.trim().isEmpty
            ? 'CNY'
            : _currencyController.text.trim().toUpperCase(),
        status: _status,
        startDate: _startDateController.text.trim(),
        endDate: _endDateController.text.trim().isEmpty ? null : _endDateController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(created);
    } catch (error) {
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.controller,
    required this.label,
    required this.onPick,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final VoidCallback onPick;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(label).copyWith(
        suffixIcon: const Icon(Icons.date_range, color: Colors.white70),
      ),
      validator: validator,
      onTap: onPick,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white70),
    filled: true,
    fillColor: Colors.white.withOpacity(0.08),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
  );
}
