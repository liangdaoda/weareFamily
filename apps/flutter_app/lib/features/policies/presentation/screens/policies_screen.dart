// Policy list view for broker/consumer roles.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wearefamily_app/core/api/api_client.dart';
import 'package:wearefamily_app/core/api/user_profile.dart';
import 'package:wearefamily_app/core/theme/app_spacing.dart';
import 'package:wearefamily_app/features/policies/presentation/widgets/policy_card.dart';

class PoliciesScreen extends StatelessWidget {
  const PoliciesScreen({
    super.key,
    required this.profile,
    required this.apiClient,
  });

  final UserProfile profile;
  final ApiClient apiClient;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Policy>>(
      future: apiClient.fetchPolicies(profile),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: Colors.white));
        }

        if (snapshot.hasError) {
          return Center(child: Text('加载失败: ${snapshot.error}', style: const TextStyle(color: Colors.white70)));
        }

        final policies = snapshot.data ?? [];
        if (policies.isEmpty) {
          return const Center(child: Text('暂无保单', style: TextStyle(color: Colors.white70)));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.lg),
          itemBuilder: (context, index) {
            return PolicyCard(policy: policies[index])
                .animate()
                .fadeIn(delay: (index * 80).ms)
                .slideY(begin: 0.1, curve: Curves.easeOutCubic);
          },
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
          itemCount: policies.length,
        );
      },
    );
  }
}

