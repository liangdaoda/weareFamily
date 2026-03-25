// Shared language and theme settings sheet.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:wearefamily_app/core/i18n/locale_text.dart';
import 'package:wearefamily_app/core/theme/app_spacing.dart';
import 'package:wearefamily_app/core/theme/app_visual_tokens.dart';

class PreferencesSheet extends StatelessWidget {
  const PreferencesSheet({
    super.key,
    required this.locale,
    required this.themeMode,
    required this.onLocaleChanged,
    required this.onThemeModeChanged,
  });

  final Locale locale;
  final ThemeMode themeMode;
  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  static Future<void> show(
    BuildContext context, {
    required Locale locale,
    required ThemeMode themeMode,
    required ValueChanged<Locale> onLocaleChanged,
    required ValueChanged<ThemeMode> onThemeModeChanged,
  }) {
    return showCupertinoModalPopup<void>(
      context: context,
      barrierDismissible: true,
      builder: (sheetContext) {
        return PreferencesSheet(
          locale: locale,
          themeMode: themeMode,
          onLocaleChanged: onLocaleChanged,
          onThemeModeChanged: onThemeModeChanged,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.visualTokens;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: tokens.sheetBackground,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: tokens.cardBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        context.tr('显示设置', 'Display Settings'),
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: tokens.textPrimary),
                      ),
                    ),
                    CupertinoButton(
                      minimumSize: const Size(30, 30),
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Icon(
                        CupertinoIcons.xmark_circle_fill,
                        color: tokens.textTertiary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  context.tr('语言', 'Language'),
                  style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.xs),
                _SegmentWrap(
                  child: CupertinoSlidingSegmentedControl<Locale>(
                    groupValue: locale.languageCode == 'en'
                        ? const Locale('en')
                        : const Locale('zh'),
                    backgroundColor: tokens.accentSoftBg,
                    thumbColor: tokens.accentBorder.withValues(alpha: 0.42),
                    children: {
                      const Locale('zh'): Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        child: Text(
                          '中文',
                          style: TextStyle(color: tokens.textPrimary),
                        ),
                      ),
                      const Locale('en'): Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        child: Text(
                          'English',
                          style: TextStyle(color: tokens.textPrimary),
                        ),
                      ),
                    },
                    onValueChanged: (value) {
                      if (value != null) {
                        Navigator.of(context).pop();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          onLocaleChanged(value);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  context.tr('主题', 'Theme'),
                  style: TextStyle(color: tokens.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: AppSpacing.xs),
                _SegmentWrap(
                  child: CupertinoSlidingSegmentedControl<ThemeMode>(
                    groupValue: themeMode,
                    backgroundColor: tokens.accentSoftBg,
                    thumbColor: tokens.accent.withValues(alpha: 0.92),
                    children: {
                      ThemeMode.system: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 7,
                        ),
                        child: Text(
                          context.tr('跟随系统', 'System'),
                          style: TextStyle(color: tokens.textPrimary),
                        ),
                      ),
                      ThemeMode.light: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 7,
                        ),
                        child: Text(
                          context.tr('浅色', 'Light'),
                          style: TextStyle(color: tokens.textPrimary),
                        ),
                      ),
                      ThemeMode.dark: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 7,
                        ),
                        child: Text(
                          context.tr('深色', 'Dark'),
                          style: TextStyle(color: tokens.textPrimary),
                        ),
                      ),
                    },
                    onValueChanged: (value) {
                      if (value != null) {
                        Navigator.of(context).pop();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          onThemeModeChanged(value);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SegmentWrap extends StatelessWidget {
  const _SegmentWrap({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: double.infinity, child: child);
  }
}
