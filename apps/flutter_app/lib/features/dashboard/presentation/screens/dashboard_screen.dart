// Dashboard view showing summary metrics and analytics charts.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wearefamily_app/core/api/api_client.dart';
import 'package:wearefamily_app/core/api/user_profile.dart';
import 'package:wearefamily_app/core/i18n/locale_text.dart';
import 'package:wearefamily_app/core/theme/app_colors.dart';
import 'package:wearefamily_app/core/theme/app_spacing.dart';
import 'package:wearefamily_app/features/policies/presentation/screens/policies_screen.dart';
import 'package:wearefamily_app/shared/widgets/glass_card.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    super.key,
    required this.profile,
    required this.apiClient,
  });

  final UserProfile profile;
  final ApiClient apiClient;

  static const double _nationalMonthlyIncome = 3000;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardSummary>(
      future: apiClient.fetchDashboardSummary(profile),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.accent));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              '${context.tr('加载失败', 'Load failed')}: ${snapshot.error}',
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }

        final summary = snapshot.data;
        if (summary == null) {
          return Center(
            child: Text(context.tr('暂无数据', 'No data'),
                style: const TextStyle(color: Colors.white70)),
          );
        }

        final monthlyPremium = summary.metrics.premiumTotal / 12.0;
        final premiumRatio = monthlyPremium / _nationalMonthlyIncome;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 900;
            void openPolicyList(PolicyListFilter filter) {
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.05),
                          end: Offset.zero,
                        ).animate(
                          CurvedAnimation(
                              parent: animation, curve: Curves.easeOutCubic),
                        ),
                        child: PoliciesScreen(
                          profile: profile,
                          apiClient: apiClient,
                          filter: filter,
                          showAppBar: true,
                        ),
                      ),
                    );
                  },
                  transitionDuration: const Duration(milliseconds: 320),
                  reverseTransitionDuration: const Duration(milliseconds: 220),
                ),
              );
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.tr('家庭保障概览', 'Family Protection Overview'),
                    style: Theme.of(context)
                        .textTheme
                        .displayMedium
                        ?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${context.tr('租户', 'Tenant')}: ${summary.tenantId} · ${context.tr('角色', 'Role')}: '
                    '${profile.role.displayNameFor(Localizations.localeOf(context))}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                  if (summary.metrics.expiringSoon > 0) ...[
                    const SizedBox(height: AppSpacing.md),
                    _ExpiryAlertBanner(
                      expiringSoonCount: summary.metrics.expiringSoon,
                      onTap: () =>
                          openPolicyList(const PolicyListFilter.expiringSoon()),
                    ).animate().fadeIn(delay: 70.ms).slideY(begin: 0.08),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.lg,
                    runSpacing: AppSpacing.lg,
                    children: [
                      SizedBox(
                        width: isWide
                            ? (constraints.maxWidth - AppSpacing.lg) / 2
                            : double.infinity,
                        child: _PolicySummaryCard(
                          total: summary.metrics.totalPolicies,
                          active: summary.metrics.activePolicies,
                          expiringSoon: summary.metrics.expiringSoon,
                          onTapTotal: () =>
                              openPolicyList(const PolicyListFilter.all()),
                          onTapActive: () =>
                              openPolicyList(const PolicyListFilter.active()),
                          onTapExpiring: () => openPolicyList(
                              const PolicyListFilter.expiringSoon()),
                        ),
                      ).animate().fadeIn(delay: 80.ms).slideY(begin: 0.1),
                      SizedBox(
                        width: isWide
                            ? (constraints.maxWidth - AppSpacing.lg) / 2
                            : double.infinity,
                        child: _PremiumSummaryCard(
                            totalPremium: summary.metrics.premiumTotal),
                      ).animate().fadeIn(delay: 140.ms).slideY(begin: 0.1),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (constraints.maxWidth >= 1100)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                            child: _RiskRadarCard(
                                summary: summary, premiumRatio: premiumRatio)),
                        const SizedBox(width: AppSpacing.lg),
                        Expanded(
                          child: _IncomeBarCard(
                            monthlyPremium: monthlyPremium,
                            premiumRatio: premiumRatio,
                          ),
                        ),
                      ],
                    )
                  else ...[
                    _RiskRadarCard(
                        summary: summary, premiumRatio: premiumRatio),
                    const SizedBox(height: AppSpacing.lg),
                    _IncomeBarCard(
                        monthlyPremium: monthlyPremium,
                        premiumRatio: premiumRatio),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _ExpiryAlertBanner extends StatelessWidget {
  const _ExpiryAlertBanner({
    required this.expiringSoonCount,
    required this.onTap,
  });

  final int expiringSoonCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    final isChinese = locale.startsWith('zh');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: const LinearGradient(
              colors: [Color(0xFFF55A3C), Color(0xFFFF9A5F)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x66F55A3C),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.notification_important_rounded,
                    color: Colors.white),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    isChinese
                        ? '你有 $expiringSoonCount 份保单将在30天内到期，点击查看并处理续保。'
                        : '$expiringSoonCount policies expire within 30 days. Tap to review renewals.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    context.tr('立即查看', 'Review now'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PolicySummaryCard extends StatelessWidget {
  const _PolicySummaryCard({
    required this.total,
    required this.active,
    required this.expiringSoon,
    required this.onTapTotal,
    required this.onTapActive,
    required this.onTapExpiring,
  });

  final int total;
  final int active;
  final int expiringSoon;
  final VoidCallback onTapTotal;
  final VoidCallback onTapActive;
  final VoidCallback onTapExpiring;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '保单概览',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 520;
              final items = [
                _PolicyMetricTile(
                  label: '保单总数',
                  value: total.toDouble(),
                  icon: Icons.policy,
                  onTap: onTapTotal,
                ),
                _PolicyMetricTile(
                  label: '生效中',
                  value: active.toDouble(),
                  icon: Icons.verified,
                  onTap: onTapActive,
                ),
                _PolicyMetricTile(
                  label: '30天内到期',
                  value: expiringSoon.toDouble(),
                  icon: Icons.warning_amber,
                  onTap: onTapExpiring,
                ),
              ];

              if (isWide) {
                return Row(
                  children: items
                      .map((item) => Expanded(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              child: item,
                            ),
                          ))
                      .toList(),
                );
              }

              return Column(
                children: items
                    .map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: item,
                        ))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PolicyMetricTile extends StatelessWidget {
  const _PolicyMetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final double value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        borderRadius: BorderRadius.circular(9),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                child: Icon(icon, color: AppColors.accent, size: 18),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                    const SizedBox(height: 4),
                    _AnimatedMetricValue(
                      value: value,
                      formatter: _formatInt,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _PremiumSummaryCard extends StatelessWidget {
  const _PremiumSummaryCard({required this.totalPremium});

  final double totalPremium;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '年度保费合计',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          _AnimatedMetricValue(
            value: totalPremium,
            formatter: _formatCurrency,
            style: Theme.of(context)
                .textTheme
                .displaySmall
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '用于评估家庭保障预算的总量级。',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _AnimatedMetricValue extends StatelessWidget {
  const _AnimatedMetricValue({
    required this.value,
    required this.formatter,
    this.style,
  });

  final double value;
  final String Function(double) formatter;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    // Count-up animation on each entry to highlight growth.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, current, _) {
        return Text(
          formatter(current),
          style: style,
        );
      },
    );
  }
}

class _RiskRadarCard extends StatelessWidget {
  const _RiskRadarCard({
    required this.summary,
    required this.premiumRatio,
  });

  final DashboardSummary summary;
  final double premiumRatio;

  @override
  Widget build(BuildContext context) {
    final coverage = _safeRatio(
        summary.metrics.activePolicies, summary.metrics.totalPolicies);
    final renewalPressure =
        _safeRatio(summary.metrics.expiringSoon, summary.metrics.totalPolicies);
    final premiumPressure = premiumRatio.clamp(0.0, 1.0);
    final riskIndex = (coverage + renewalPressure + premiumPressure) / 3.0;

    final values = [coverage, renewalPressure, premiumPressure, riskIndex];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI风险雷达',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 260,
            child: RadarChart(
              RadarChartData(
                dataSets: [
                  RadarDataSet(
                    borderColor: AppColors.accent,
                    fillColor: AppColors.accent.withValues(alpha: 0.25),
                    entryRadius: 2,
                    dataEntries: values
                        .map((value) =>
                            RadarEntry(value: (value * 5).clamp(0, 5)))
                        .toList(),
                  ),
                ],
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData: const BorderSide(color: Colors.white24),
                titleTextStyle:
                    const TextStyle(color: Colors.white70, fontSize: 12),
                tickBorderData: const BorderSide(color: Colors.white12),
                ticksTextStyle:
                    const TextStyle(color: Colors.white38, fontSize: 10),
                titlePositionPercentageOffset: 0.16,
                getTitle: (index, angle) {
                  switch (index) {
                    case 0:
                      return const RadarChartTitle(text: '覆盖度');
                    case 1:
                      return const RadarChartTitle(text: '续期压力');
                    case 2:
                      return const RadarChartTitle(text: '保费负担');
                    case 3:
                      return const RadarChartTitle(text: '风险指数');
                    default:
                      return const RadarChartTitle(text: '');
                  }
                },
                tickCount: 5,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '风险指数 ${_formatPercent(riskIndex)} · 保费负担 ${_formatPercent(premiumPressure)}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 120.ms).slideY(begin: 0.08);
  }

  double _safeRatio(int part, int total) {
    if (total <= 0) {
      return 0;
    }
    return (part / total).clamp(0.0, 1.0);
  }

  String _formatPercent(double value) {
    return '${(value * 100).toStringAsFixed(1)}%';
  }
}

// Shared formatters for animated dashboard metrics.
String _formatInt(double value) => value.round().toString();

String _formatCurrency(double value) => value.toStringAsFixed(2);

class _IncomeBarCard extends StatelessWidget {
  const _IncomeBarCard({
    required this.monthlyPremium,
    required this.premiumRatio,
  });

  final double monthlyPremium;
  final double premiumRatio;

  @override
  Widget build(BuildContext context) {
    final ratioText = (premiumRatio * 100).toStringAsFixed(1);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '保费与收入对比',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '用户月均保费占全国月均收入的 $ratioText%',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.center,
                maxY: _maxY(monthlyPremium),
                gridData: FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '对比',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barsSpace: 12,
                    barRods: [
                      BarChartRodData(
                        toY: _IncomeBarCard._nationalIncome,
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                        color: AppColors.mint,
                      ),
                      BarChartRodData(
                        toY: monthlyPremium,
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                        color: AppColors.accent,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: const [
              _LegendDot(color: AppColors.mint, label: '全国月均收入'),
              SizedBox(width: AppSpacing.md),
              _LegendDot(color: AppColors.accent, label: '用户月均保费'),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.08);
  }

  double _maxY(double premium) {
    final base = _nationalIncome > premium ? _nationalIncome : premium;
    return base * 1.25;
  }

  static const double _nationalIncome = DashboardScreen._nationalMonthlyIncome;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      ],
    );
  }
}
