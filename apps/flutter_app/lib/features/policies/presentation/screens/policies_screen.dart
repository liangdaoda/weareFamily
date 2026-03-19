// Policy list view for broker/consumer roles.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wearefamily_app/core/api/api_client.dart';
import 'package:wearefamily_app/core/api/user_profile.dart';
import 'package:wearefamily_app/core/i18n/locale_text.dart';
import 'package:wearefamily_app/core/theme/app_spacing.dart';
import 'package:wearefamily_app/features/policies/presentation/screens/policy_create_screen.dart';
import 'package:wearefamily_app/features/policies/presentation/screens/policy_detail_screen.dart';
import 'package:wearefamily_app/features/policies/presentation/widgets/policy_card.dart';
import 'package:wearefamily_app/shared/widgets/decorative_background.dart';

class PoliciesScreen extends StatefulWidget {
  const PoliciesScreen({
    super.key,
    required this.profile,
    required this.apiClient,
    this.filter = const PolicyListFilter.all(),
    this.showAppBar = false,
  });

  final UserProfile profile;
  final ApiClient apiClient;
  final PolicyListFilter filter;
  final bool showAppBar;

  @override
  State<PoliciesScreen> createState() => _PoliciesScreenState();
}

class _PoliciesScreenState extends State<PoliciesScreen> {
  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<List<Policy>>(
      future: widget.apiClient.fetchPolicies(widget.profile),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white));
        }

        if (snapshot.hasError) {
          return Center(
            child: Text(
              '${context.tr('加载失败', 'Load failed')}: ${snapshot.error}',
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }

        final policies = snapshot.data ?? [];
        final filtered = _applyFilter(policies, widget.filter);
        final expiringPolicies = _sortByNearestEndDate(
          policies.where(_isExpiringSoon).toList(),
        );
        // Show reminder on the "all" view to avoid repeated alerts in filtered lists.
        final showExpiringReminder =
            widget.filter.type == PolicyFilterType.all &&
                expiringPolicies.isNotEmpty;
        if (filtered.isEmpty) {
          return Center(
            child: Text(
              widget.filter.type == PolicyFilterType.all
                  ? context.tr('暂无保单', 'No policies yet')
                  : context.tr('暂无符合条件的保单', 'No matching policies'),
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }

        final topInset = widget.showAppBar ? AppSpacing.lg : AppSpacing.lg + 52;
        final reminderPreviewPolicies =
            expiringPolicies.take(3).toList(growable: false);

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(
              AppSpacing.lg, topInset, AppSpacing.lg, AppSpacing.lg),
          itemBuilder: (context, index) {
            if (showExpiringReminder && index == 0) {
              return _ExpiringReminderCard(
                policies: reminderPreviewPolicies,
                totalCount: expiringPolicies.length,
                onTapPolicy: _openPolicyDetail,
              )
                  .animate()
                  .fadeIn(delay: 40.ms)
                  .slideY(begin: 0.08, curve: Curves.easeOutCubic);
            }

            final policyIndex = showExpiringReminder ? index - 1 : index;
            final policy = filtered[policyIndex];
            return PolicyCard(
              policy: policy,
              onTap: () => _openPolicyDetail(policy),
              onDelete: () => _confirmAndDeletePolicy(policy),
            )
                .animate()
                .fadeIn(delay: ((policyIndex + 1) * 80).ms)
                .slideY(begin: 0.1, curve: Curves.easeOutCubic);
          },
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemCount: filtered.length + (showExpiringReminder ? 1 : 0),
        );
      },
    );

    final body = Stack(
      children: [
        content,
        if (!widget.showAppBar)
          Positioned(
            right: AppSpacing.lg,
            top: AppSpacing.lg,
            child: _CreatePolicyButton(onPressed: _openPolicyCreate),
          ),
      ],
    );

    if (!widget.showAppBar) {
      return body;
    }

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
        title: Text(widget.filter.title(context),
            style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            onPressed: _openPolicyCreate,
            icon: const Icon(CupertinoIcons.add_circled),
            tooltip: context.tr('新建保单', 'Create policy'),
          ),
        ],
      ),
      body: DecorativeBackground(
        child: Padding(
          padding: EdgeInsets.only(
            top: kToolbarHeight + MediaQuery.of(context).padding.top,
          ),
          child: body,
        ),
      ),
    );
  }

  void _openPolicyDetail(Policy policy) {
    Navigator.of(context)
        .push<bool>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
              child: PolicyDetailScreen(
                policy: policy,
                onDeletePolicy: () => _confirmAndDeletePolicy(policy),
              ),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 220),
      ),
    )
        .then((deleted) {
      if (deleted == true && mounted) {
        setState(() {});
      }
    });
  }

  Future<bool> _confirmAndDeletePolicy(Policy policy) async {
    final confirmed = await showCupertinoDialog<bool>(
      context: context,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(context.tr('删除保单', 'Delete policy')),
        content: Text(
          context.tr('确认删除该保单？删除后将无法恢复。',
              'Delete this policy? This action cannot be undone.'),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.tr('取消', 'Cancel')),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.tr('删除', 'Delete')),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return false;
    }

    try {
      await widget.apiClient.deletePolicy(
        profile: widget.profile,
        policyId: policy.id,
      );

      if (!mounted) {
        return true;
      }

      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('保单已删除', 'Policy deleted')),
        ),
      );
      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.tr('删除失败', 'Delete failed')}: $error'),
        ),
      );
      return false;
    }
  }

  Future<void> _openPolicyCreate() async {
    final created = await Navigator.of(context).push<Policy>(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                  parent: animation, curve: Curves.easeOutCubic)),
              child: PolicyCreateScreen(
                profile: widget.profile,
                apiClient: widget.apiClient,
              ),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 220),
      ),
    );

    if (!mounted) {
      return;
    }

    if (created != null) {
      setState(() {});
      final aiScore =
          created.aiInsight?.riskScore ?? created.aiRiskScore?.round();
      final aiSummary = created.aiInsight?.summary ?? created.aiNotes ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${context.tr('保单已创建', 'Policy created')}'
            '${aiScore == null ? '' : '\n${context.tr('AI风险评分', 'AI risk score')}: $aiScore/100'}'
            '${aiSummary.isEmpty ? '' : '\n$aiSummary'}',
          ),
        ),
      );
    }
  }
}

enum PolicyFilterType { all, active, expiringSoon }

class PolicyListFilter {
  const PolicyListFilter({required this.type});

  final PolicyFilterType type;

  const PolicyListFilter.all() : type = PolicyFilterType.all;

  const PolicyListFilter.active() : type = PolicyFilterType.active;

  const PolicyListFilter.expiringSoon() : type = PolicyFilterType.expiringSoon;

  String title(BuildContext context) {
    switch (type) {
      case PolicyFilterType.all:
        return context.tr('全部保单', 'All policies');
      case PolicyFilterType.active:
        return context.tr('生效中保单', 'Active policies');
      case PolicyFilterType.expiringSoon:
        return context.tr('30天内到期', 'Expiring in 30 days');
    }
  }
}

class _CreatePolicyButton extends StatelessWidget {
  const _CreatePolicyButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(CupertinoIcons.add, size: 18),
      label: Text(context.tr('新建保单', 'Create policy')),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withValues(alpha: 0.16),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    );
  }
}

class _ExpiringReminderCard extends StatelessWidget {
  const _ExpiringReminderCard({
    required this.policies,
    required this.totalCount,
    required this.onTapPolicy,
  });

  final List<Policy> policies;
  final int totalCount;
  final ValueChanged<Policy> onTapPolicy;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode.toLowerCase();
    final isChinese = locale.startsWith('zh');

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFC46A), Color(0xFFFF8A65)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x66FF8A65),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(CupertinoIcons.bell_fill, color: Colors.white),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    context.tr('即将到期提醒', 'Expiry reminder'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              isChinese
                  ? '30天内有 $totalCount 份保单即将到期，请尽快处理续保。'
                  : '$totalCount policies will expire within 30 days. Please prepare renewals.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ...policies.map(
              (policy) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _ExpiringPolicyTile(
                  policy: policy,
                  onTap: () => onTapPolicy(policy),
                ),
              ),
            ),
            if (totalCount > policies.length)
              Text(
                isChinese
                    ? '还有 ${totalCount - policies.length} 份保单到期提醒，点击上方保单可查看详情。'
                    : '${totalCount - policies.length} more policies are nearing expiry.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ExpiringPolicyTile extends StatelessWidget {
  const _ExpiringPolicyTile({
    required this.policy,
    required this.onTap,
  });

  final Policy policy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const Icon(CupertinoIcons.time_solid,
                  color: Colors.white, size: 18),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      policy.productName.isEmpty
                          ? policy.policyNo
                          : policy.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _expiryDateText(context, policy),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _daysLeftText(context, policy),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(width: 2),
              const Icon(CupertinoIcons.chevron_right,
                  color: Colors.white70, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

List<Policy> _applyFilter(List<Policy> policies, PolicyListFilter filter) {
  switch (filter.type) {
    case PolicyFilterType.active:
      return policies.where((policy) => policy.status == 'active').toList();
    case PolicyFilterType.expiringSoon:
      return policies.where(_isExpiringSoon).toList();
    case PolicyFilterType.all:
      return policies;
  }
}

List<Policy> _sortByNearestEndDate(List<Policy> policies) {
  policies.sort((left, right) {
    final leftDate = _parseDate(left.endDate);
    final rightDate = _parseDate(right.endDate);
    if (leftDate == null && rightDate == null) {
      return 0;
    }
    if (leftDate == null) {
      return 1;
    }
    if (rightDate == null) {
      return -1;
    }
    return leftDate.compareTo(rightDate);
  });
  return policies;
}

int? _daysUntilExpiry(Policy policy) {
  final endDate = _parseDate(policy.endDate);
  if (endDate == null) {
    return null;
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return endDate.difference(today).inDays;
}

String _daysLeftText(BuildContext context, Policy policy) {
  final days = _daysUntilExpiry(policy);
  if (days == null) {
    return context.tr('到期日未知', 'Unknown');
  }
  if (days <= 0) {
    return context.tr('今日到期', 'Due today');
  }

  final locale = Localizations.localeOf(context).languageCode.toLowerCase();
  if (locale.startsWith('zh')) {
    return '剩余 $days 天';
  }
  return '$days day${days == 1 ? '' : 's'} left';
}

String _expiryDateText(BuildContext context, Policy policy) {
  final endDate = _parseDate(policy.endDate);
  if (endDate == null) {
    return context.tr('到期日: 未知', 'Expiry: unknown');
  }
  final month = endDate.month.toString().padLeft(2, '0');
  final day = endDate.day.toString().padLeft(2, '0');
  return '${context.tr('到期日: ', 'Expiry: ')}${endDate.year}-$month-$day';
}

bool _isExpiringSoon(Policy policy) {
  final endDate = _parseDate(policy.endDate);
  if (endDate == null) {
    return false;
  }
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final diff = endDate.difference(today).inDays;
  return diff >= 0 && diff <= 30;
}

DateTime? _parseDate(String? value) {
  if (value == null || value.trim().isEmpty) {
    return null;
  }
  try {
    return DateTime.parse(value);
  } catch (_) {
    return null;
  }
}
