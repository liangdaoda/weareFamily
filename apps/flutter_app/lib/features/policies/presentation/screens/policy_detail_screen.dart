// Policy detail view for a single policy item.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wearefamily_app/core/api/api_client.dart';
import 'package:wearefamily_app/core/theme/app_colors.dart';
import 'package:wearefamily_app/core/theme/app_spacing.dart';
import 'package:wearefamily_app/shared/widgets/decorative_background.dart';
import 'package:wearefamily_app/shared/widgets/glass_card.dart';

class PolicyDetailScreen extends StatelessWidget {
  const PolicyDetailScreen({super.key, required this.policy});

  final Policy policy;

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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: '返回',
        ),
        title: const Text('保单详情', style: TextStyle(color: Colors.white)),
        centerTitle: false,
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

            return SingleChildScrollView(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Header(policy: policy),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.lg,
                    children: [
                      SizedBox(
                        width: isWide
                            ? (constraints.maxWidth - padding.horizontal - AppSpacing.lg) / 2
                            : double.infinity,
                        child: _BasicInfoCard(policy: policy),
                      ),
                      SizedBox(
                        width: isWide
                            ? (constraints.maxWidth - padding.horizontal - AppSpacing.lg) / 2
                            : double.infinity,
                        child: _PremiumCard(policy: policy),
                      ),
                      SizedBox(
                        width: isWide
                            ? (constraints.maxWidth - padding.horizontal - AppSpacing.lg) / 2
                            : double.infinity,
                        child: _ScheduleCard(policy: policy),
                      ),
                      SizedBox(
                        width: isWide
                            ? (constraints.maxWidth - padding.horizontal - AppSpacing.lg) / 2
                            : double.infinity,
                        child: _AiInsightCard(policy: policy),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.policy});

  final Policy policy;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            policy.productName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '保险公司: ${policy.insurerName}',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.white70),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _StatusChip(status: policy.status),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '保单号: ${policy.policyNo}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, curve: Curves.easeOutCubic);
  }
}

class _BasicInfoCard extends StatelessWidget {
  const _BasicInfoCard({required this.policy});

  final Policy policy;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '基础信息',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(label: '保险公司', value: policy.insurerName),
          _InfoRow(label: '产品名称', value: policy.productName),
          _InfoRow(label: '保单号', value: policy.policyNo),
          _InfoRow(label: '状态', value: _statusText(policy.status)),
        ],
      ),
    ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.08, curve: Curves.easeOutCubic);
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.policy});

  final Policy policy;

  @override
  Widget build(BuildContext context) {
    final monthly = policy.premium / 12.0;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '保费信息',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(
            label: '年缴保费',
            value: '${policy.premium.toStringAsFixed(2)} ${policy.currency}',
          ),
          _InfoRow(
            label: '月均保费',
            value: '${monthly.toStringAsFixed(2)} ${policy.currency}',
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '建议维持在可承受区间内，避免超支。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 160.ms).slideY(begin: 0.08, curve: Curves.easeOutCubic);
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.policy});

  final Policy policy;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '保障期限',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(label: '生效日期', value: _formatDate(policy.startDate)),
          _InfoRow(
            label: '到期日期',
            value: _formatDate(policy.endDate, emptyLabel: '长期/未知'),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.event_available, color: AppColors.mint, size: 18),
              const SizedBox(width: 6),
              Text(
                '请留意续期提醒',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.08, curve: Curves.easeOutCubic);
  }
}

class _AiInsightCard extends StatelessWidget {
  const _AiInsightCard({required this.policy});

  final Policy policy;

  @override
  Widget build(BuildContext context) {
    final score = policy.aiRiskScore;
    final scoreText = score == null ? '暂无评分' : score.toStringAsFixed(1);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI分析',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          _InfoRow(label: '风险评分', value: scoreText),
          _InfoRow(label: '建议', value: policy.aiNotes ?? '尚未生成建议'),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '需要更精细的风险评估，可上传更多保单与家庭成员信息。',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 240.ms).slideY(begin: 0.08, curve: Curves.easeOutCubic);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: const TextStyle(color: Colors.white70)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (status) {
      case 'active':
        color = AppColors.mint;
        break;
      case 'pending':
        color = AppColors.accent;
        break;
      case 'expired':
        color = AppColors.rose;
        break;
      default:
        color = Colors.white54;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(
        _statusText(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}

String _statusText(String status) {
  switch (status) {
    case 'active':
      return '生效中';
    case 'pending':
      return '待生效';
    case 'expired':
      return '已到期';
    default:
      return status.toUpperCase();
  }
}

String _formatDate(String? value, {String emptyLabel = '未知'}) {
  if (value == null || value.isEmpty) {
    return emptyLabel;
  }
  return value;
}
