// Policy list view for broker/consumer roles.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wearefamily_app/core/api/api_client.dart';
import 'package:wearefamily_app/core/api/user_profile.dart';
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
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (snapshot.hasError) {
          return Center(child: Text('加载失败: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
        }

        final policies = snapshot.data ?? [];
        final filtered = _applyFilter(policies, widget.filter);
        if (filtered.isEmpty) {
          return Center(
            child: Text(
              widget.filter.type == PolicyFilterType.all ? '暂无保单' : '暂无符合条件的保单',
              style: const TextStyle(color: Colors.white70),
            ),
          );
        }

        final topInset = widget.showAppBar ? AppSpacing.lg : AppSpacing.lg + 52;

        return ListView.separated(
          padding: EdgeInsets.fromLTRB(AppSpacing.lg, topInset, AppSpacing.lg, AppSpacing.lg),
          itemBuilder: (context, index) {
            final policy = filtered[index];
            return PolicyCard(
              policy: policy,
              onTap: () => _openPolicyDetail(policy),
            )
                .animate()
                .fadeIn(delay: (index * 80).ms)
                .slideY(begin: 0.1, curve: Curves.easeOutCubic);
          },
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemCount: filtered.length,
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
        title: Text(widget.filter.title, style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            onPressed: _openPolicyCreate,
            icon: const Icon(Icons.add_circle_outline),
            tooltip: '新建保单',
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
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.06),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
              child: PolicyDetailScreen(policy: policy),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 220),
      ),
    );
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
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保单已创建')),
      );
    }
  }
}

enum PolicyFilterType { all, active, expiringSoon }

class PolicyListFilter {
  const PolicyListFilter({
    required this.type,
    required this.title,
  });

  final PolicyFilterType type;
  final String title;

  const PolicyListFilter.all()
      : type = PolicyFilterType.all,
        title = '全部保单';

  const PolicyListFilter.active()
      : type = PolicyFilterType.active,
        title = '生效中保单';

  const PolicyListFilter.expiringSoon()
      : type = PolicyFilterType.expiringSoon,
        title = '30天内到期';
}

class _CreatePolicyButton extends StatelessWidget {
  const _CreatePolicyButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.add, size: 18),
      label: const Text('新建保单'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.white.withOpacity(0.16),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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


