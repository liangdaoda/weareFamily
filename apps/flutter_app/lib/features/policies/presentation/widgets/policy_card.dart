// UI card for a single policy record.
import 'package:flutter/material.dart';
import 'package:wearefamily_app/core/api/api_client.dart';
import 'package:wearefamily_app/core/theme/app_colors.dart';
import 'package:wearefamily_app/core/theme/app_spacing.dart';
import 'package:wearefamily_app/shared/widgets/glass_card.dart';

class PolicyCard extends StatelessWidget {
  const PolicyCard({
    super.key,
    required this.policy,
    this.onTap,
  });

  final Policy policy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  policy.productName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white),
                ),
              ),
              _StatusChip(status: policy.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('保险公司: ${policy.insurerName}', style: const TextStyle(color: Colors.white70)),
          Text('保单号: ${policy.policyNo}', style: const TextStyle(color: Colors.white70)),
          Text(
            '保费: ${policy.premium.toStringAsFixed(2)} ${policy.currency}',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (policy.aiRiskScore != null)
            Text(
              'AI 风险评分: ${policy.aiRiskScore!.toStringAsFixed(1)}',
              style: const TextStyle(color: Colors.white),
            ),
          if (policy.aiNotes != null)
            Text('AI 建议: ${policy.aiNotes}', style: const TextStyle(color: Colors.white70)),
          if (onTap != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: const [
                Text('查看详情', style: TextStyle(color: Colors.white70)),
                SizedBox(width: 6),
                Icon(Icons.arrow_forward, size: 16, color: Colors.white70),
              ],
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: content,
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
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}


