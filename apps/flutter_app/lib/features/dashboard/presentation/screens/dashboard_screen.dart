// Dashboard view showing summary metrics and analytics charts.
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wearefamily_app/core/api/api_client.dart';
import 'package:wearefamily_app/core/api/user_profile.dart';
import 'package:wearefamily_app/core/i18n/locale_text.dart';
import 'package:wearefamily_app/core/theme/app_spacing.dart';
import 'package:wearefamily_app/core/theme/app_visual_tokens.dart';
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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DashboardSummary>(
      future: apiClient.fetchDashboardSummary(profile),
      builder: (context, snapshot) {
        final tokens = context.visualTokens;
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(color: tokens.accent),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              '${context.tr('加载失败', 'Load failed')}: ${snapshot.error}',
              style: TextStyle(color: tokens.textSecondary),
            ),
          );
        }

        final summary = snapshot.data;
        if (summary == null) {
          return Center(
            child: Text(context.tr('暂无数据', 'No data'),
                style: TextStyle(color: tokens.textSecondary)),
          );
        }

        final monthlyPremium = summary.metrics.monthlyPremium;
        final premiumRatio = summary.metrics.premiumIncomeRatio;
        final benchmarkMonthlyIncome = summary.benchmark.monthlyIncome;

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
                        ?.copyWith(color: tokens.textPrimary),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${context.tr('租户', 'Tenant')}: ${summary.tenantId} · ${context.tr('角色', 'Role')}: '
                    '${profile.role.displayNameFor(Localizations.localeOf(context))}',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: tokens.textSecondary),
                  ),
                  if (summary.benchmark.stale) ...[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      context.tr(
                        '收入基准数据可能过期，当前使用最近快照。',
                        'Benchmark data may be stale. Using latest snapshot.',
                      ),
                      style: TextStyle(
                        color: tokens.warning,
                        fontSize: 12,
                      ),
                    ),
                  ],
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
                            benchmarkMonthlyIncome: benchmarkMonthlyIncome,
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
                      premiumRatio: premiumRatio,
                      benchmarkMonthlyIncome: benchmarkMonthlyIncome,
                    ),
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
    final tokens = context.visualTokens;
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
            gradient: LinearGradient(
              colors: [tokens.danger, tokens.warning],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: tokens.danger.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.notification_important_rounded,
                    color: tokens.textPrimary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    isChinese
                        ? '你有 $expiringSoonCount 份保单将在30天内到期，点击查看并处理续保。'
                        : '$expiringSoonCount policies expire within 30 days. Tap to review renewals.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: tokens.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: tokens.accentSoftBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    context.tr('立即查看', 'Review now'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: tokens.textPrimary,
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
    final tokens = context.visualTokens;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '保单概览',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: tokens.textPrimary),
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
    final tokens = context.visualTokens;
    return Material(
      color: tokens.cardBackground.withValues(alpha: 0.7),
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
                backgroundColor: tokens.accentSoftBg,
                child: Icon(
                  icon,
                  color: tokens.accent,
                  size: 18,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: TextStyle(
                            color: tokens.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    _AnimatedMetricValue(
                      value: value,
                      formatter: _formatInt,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(color: tokens.textPrimary),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: tokens.textTertiary, size: 18),
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
    final tokens = context.visualTokens;
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '年度保费合计',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: tokens.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          _AnimatedMetricValue(
            value: totalPremium,
            formatter: _formatCurrency,
            style: Theme.of(context)
                .textTheme
                .displaySmall
                ?.copyWith(color: tokens.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '用于评估家庭保障预算的总量级。',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: tokens.textSecondary),
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
    final tokens = context.visualTokens;
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
                ?.copyWith(color: tokens.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 260,
            child: RadarChart(
              RadarChartData(
                dataSets: [
                  RadarDataSet(
                    borderColor: tokens.chartPrimary,
                    fillColor: tokens.chartPrimary.withValues(alpha: 0.25),
                    entryRadius: 2,
                    dataEntries: values
                        .map((value) =>
                            RadarEntry(value: (value * 5).clamp(0, 5)))
                        .toList(),
                  ),
                ],
                radarBackgroundColor: Colors.transparent,
                borderData: FlBorderData(show: false),
                radarBorderData: BorderSide(color: tokens.chartGrid),
                titleTextStyle:
                    TextStyle(color: tokens.chartLabel, fontSize: 12),
                tickBorderData: BorderSide(color: tokens.chartGrid),
                ticksTextStyle: TextStyle(
                    color: tokens.chartLabel.withValues(alpha: 0.7),
                    fontSize: 10),
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
            style: TextStyle(color: tokens.textSecondary),
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
    required this.benchmarkMonthlyIncome,
  });

  final double monthlyPremium;
  final double premiumRatio;
  final double benchmarkMonthlyIncome;

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
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
                ?.copyWith(color: tokens.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '用户月均保费占基准月收入的 $ratioText%',
            style: TextStyle(color: tokens.textSecondary),
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
                            style: TextStyle(
                                color: tokens.textSecondary, fontSize: 12),
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
                        toY: benchmarkMonthlyIncome,
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                        color: tokens.chartReference,
                      ),
                      BarChartRodData(
                        toY: monthlyPremium,
                        width: 18,
                        borderRadius: BorderRadius.circular(6),
                        color: tokens.chartPrimary,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                '${context.tr('基准月收入', 'Benchmark monthly income')}: ${benchmarkMonthlyIncome.toStringAsFixed(2)}',
                style: TextStyle(color: tokens.textSecondary, fontSize: 11),
              ),
              const SizedBox(width: AppSpacing.md),
              _LegendDot(color: tokens.chartReference, label: 'Benchmark'),
              const SizedBox(width: AppSpacing.md),
              _LegendDot(color: tokens.chartPrimary, label: 'Premium'),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 180.ms).slideY(begin: 0.08);
  }

  double _maxY(double premium) {
    final base =
        benchmarkMonthlyIncome > premium ? benchmarkMonthlyIncome : premium;
    return base * 1.25;
  }
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
            style: TextStyle(
              color: context.visualTokens.textSecondary,
              fontSize: 12,
            )),
      ],
    );
  }
}
