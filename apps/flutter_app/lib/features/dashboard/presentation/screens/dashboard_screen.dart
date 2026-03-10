// Dashboard view showing summary metrics and insights.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wearefamily_app/core/api/api_client.dart';
import 'package:wearefamily_app/core/api/user_profile.dart';
import 'package:wearefamily_app/core/theme/app_colors.dart';
import 'package:wearefamily_app/core/theme/app_spacing.dart';
import 'package:wearefamily_app/shared/widgets/glass_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.profile,
    required this.apiClient,
  });

  final UserProfile profile;
  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardSummary>(
      future: apiClient.fetchDashboardSummary(profile),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.accent));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('加载失败: ${snapshot.error}', style: const TextStyle(color: Colors.white70)),
          );
        }

        final summary = snapshot.data;
        if (summary == null) {
          return const Center(child: Text('暂无数据', style: TextStyle(color: Colors.white70)));
        }

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            final metrics = [
              _MetricData('保单总数', summary.metrics.totalPolicies.toString(), Icons.policy),
              _MetricData('生效中保单', summary.metrics.activePolicies.toString(), Icons.verified),
              _MetricData('30天内到期', summary.metrics.expiringSoon.toString(), Icons.warning_amber),
              _MetricData('年度保费合计', summary.metrics.premiumTotal.toStringAsFixed(2), Icons.paid),
            ];

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Coverage Command',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Tenant: ${summary.tenantId} · ${profile.role.displayName}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.lg,
                    children: metrics
                        .asMap()
                        .entries
                        .map((entry) => SizedBox(
                              width: isWide ? (constraints.maxWidth - AppSpacing.lg) / 2 : double.infinity,
                              child: _MetricCard(data: entry.value),
                            ).animate().fadeIn(delay: (entry.key * 100).ms).slideY(begin: 0.1))
                        .toList(),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Risk Pulse',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _RiskBar(
                          label: '保障覆盖度',
                          value: _clamp(summary.metrics.activePolicies / (summary.metrics.totalPolicies + 1)),
                          color: AppColors.mint,
                        ),
                        _RiskBar(
                          label: '续期压力',
                          value: _clamp(summary.metrics.expiringSoon / (summary.metrics.totalPolicies + 1)),
                          color: AppColors.accent,
                        ),
                        _RiskBar(
                          label: '家庭风险系数',
                          value: 0.42,
                          color: AppColors.rose,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.15),
                ],
              ),
            );
          },
        );
      },
    );
  }

  double _clamp(num value) {
    if (value.isNaN) {
      return 0;
    }
    return value.clamp(0, 1).toDouble();
  }
}

class _MetricData {
  const _MetricData(this.title, this.value, this.icon);

  final String title;
  final String value;
  final IconData icon;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.data});

  final _MetricData data;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.white.withOpacity(0.12),
            child: Icon(data.icon, color: AppColors.accent),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.title,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text(
                  data.value,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RiskBar extends StatelessWidget {
  const _RiskBar({required this.label, required this.value, required this.color});

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}

