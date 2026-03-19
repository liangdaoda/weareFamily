// UI card for a single policy record.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:wearefamily_app/core/api/api_client.dart';
import 'package:wearefamily_app/core/i18n/locale_text.dart';
import 'package:wearefamily_app/core/theme/app_colors.dart';
import 'package:wearefamily_app/core/theme/app_spacing.dart';
import 'package:wearefamily_app/shared/widgets/glass_card.dart';

class PolicyCard extends StatelessWidget {
  const PolicyCard({
    super.key,
    required this.policy,
    this.onTap,
    this.onDelete,
  });

  final Policy policy;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final aiSummary = policy.aiInsight?.summary ?? policy.aiNotes;

    final content = GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  policy.productName,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: Colors.white),
                ),
              ),
              if (onDelete != null)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: IconButton(
                    onPressed: onDelete,
                    tooltip: context.tr('删除保单', 'Delete policy'),
                    icon: const Icon(
                      CupertinoIcons.delete_simple,
                      color: Colors.white70,
                      size: 18,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              _StatusChip(status: policy.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${context.tr('保险公司', 'Insurer')}: ${policy.insurerName}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            '${context.tr('保单号', 'Policy No.')}: ${policy.policyNo}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          Text(
            '${context.tr('保费', 'Premium')}: ${policy.premium.toStringAsFixed(2)} ${policy.currency}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          if (policy.aiInsight != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${context.tr('保障评分', 'Protection')}: ${policy.aiInsight!.protectionScore}/100 · '
              '${context.tr('风险评分', 'Risk')}: ${policy.aiInsight!.riskScore}/100',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ] else if (policy.aiRiskScore != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${context.tr('风险评分', 'Risk score')}: ${policy.aiRiskScore!.toStringAsFixed(1)}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
            ),
          ],
          if (aiSummary != null && aiSummary.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              aiSummary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          if (onTap != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(context.tr('查看详情', 'View details'),
                    style: const TextStyle(color: Colors.white70)),
                const SizedBox(width: 6),
                const Icon(CupertinoIcons.chevron_right,
                    size: 14, color: Colors.white70),
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
        borderRadius: BorderRadius.circular(9),
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
    String label;
    switch (status) {
      case 'active':
        color = AppColors.mint;
        label = context.tr('生效中', 'Active');
        break;
      case 'pending':
        color = AppColors.accent;
        label = context.tr('待生效', 'Pending');
        break;
      case 'expired':
        color = AppColors.rose;
        label = context.tr('已到期', 'Expired');
        break;
      case 'cancelled':
        color = Colors.white60;
        label = context.tr('已终止', 'Cancelled');
        break;
      default:
        color = Colors.white54;
        label = status.toUpperCase();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style:
            TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}
