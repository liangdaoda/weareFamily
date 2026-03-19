// Adaptive shell with Cupertino-first navigation patterns.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:wearefamily_app/core/api/api_client.dart';
import 'package:wearefamily_app/core/api/user_profile.dart';
import 'package:wearefamily_app/core/i18n/locale_text.dart';
import 'package:wearefamily_app/core/theme/app_colors.dart';
import 'package:wearefamily_app/core/theme/app_spacing.dart';
import 'package:wearefamily_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:wearefamily_app/features/family/presentation/screens/family_center_screen.dart';
import 'package:wearefamily_app/features/policies/presentation/screens/policies_screen.dart';
import 'package:wearefamily_app/shared/widgets/decorative_background.dart';
import 'package:wearefamily_app/shared/widgets/preferences_sheet.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.apiClient,
    required this.profile,
    required this.onLogout,
    required this.locale,
    required this.themeMode,
    required this.onLocaleChanged,
    required this.onThemeModeChanged,
  });

  final ApiClient apiClient;
  final UserProfile profile;
  final VoidCallback onLogout;
  final Locale locale;
  final ThemeMode themeMode;
  final ValueChanged<Locale> onLocaleChanged;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  Future<void> _openPreferences() {
    return PreferencesSheet.show(
      context,
      locale: widget.locale,
      themeMode: widget.themeMode,
      onLocaleChanged: widget.onLocaleChanged,
      onThemeModeChanged: widget.onThemeModeChanged,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(profile: widget.profile, apiClient: widget.apiClient),
      PoliciesScreen(profile: widget.profile, apiClient: widget.apiClient),
      FamilyCenterScreen(profile: widget.profile, apiClient: widget.apiClient),
    ];

    final navDashboard = context.tr('看板', 'Dashboard');
    final navPolicies = context.tr('保单', 'Policies');
    final navFamily = context.tr('家庭', 'Family');

    return Scaffold(
      body: DecorativeBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 960;
              if (isWide) {
                return Row(
                  children: [
                    _DesktopSidebar(
                      profile: widget.profile,
                      locale: widget.locale,
                      currentIndex: _currentIndex,
                      dashboardLabel: navDashboard,
                      policiesLabel: navPolicies,
                      familyLabel: navFamily,
                      onChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      onOpenPreferences: _openPreferences,
                      onLogout: widget.onLogout,
                    ),
                    Container(
                        width: 1, color: Colors.white.withValues(alpha: 0.16)),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: IndexedStack(
                          index: _currentIndex,
                          children: screens,
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  _MobileHeader(
                    profile: widget.profile,
                    locale: widget.locale,
                    onOpenPreferences: _openPreferences,
                    onLogout: widget.onLogout,
                  ),
                  Expanded(
                    child: IndexedStack(
                      index: _currentIndex,
                      children: screens,
                    ),
                  ),
                  _MobileNavBar(
                    currentIndex: _currentIndex,
                    dashboardLabel: navDashboard,
                    policiesLabel: navPolicies,
                    familyLabel: navFamily,
                    onChanged: (index) {
                      setState(() {
                        _currentIndex = index;
                      });
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _DesktopSidebar extends StatelessWidget {
  const _DesktopSidebar({
    required this.profile,
    required this.locale,
    required this.currentIndex,
    required this.dashboardLabel,
    required this.policiesLabel,
    required this.familyLabel,
    required this.onChanged,
    required this.onOpenPreferences,
    required this.onLogout,
  });

  final UserProfile profile;
  final Locale locale;
  final int currentIndex;
  final String dashboardLabel;
  final String policiesLabel;
  final String familyLabel;
  final ValueChanged<int> onChanged;
  final VoidCallback onOpenPreferences;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return SizedBox(
      width: 248,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(CupertinoIcons.shield_fill,
                          color: AppColors.ink, size: 18),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(profile.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white)),
                          Text(profile.role.displayNameFor(locale),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.bodySmall
                                  ?.copyWith(color: Colors.white70)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                _SidebarItem(
                  label: dashboardLabel,
                  icon: CupertinoIcons.chart_pie_fill,
                  selected: currentIndex == 0,
                  onTap: () => onChanged(0),
                ),
                _SidebarItem(
                  label: policiesLabel,
                  icon: CupertinoIcons.doc_text_fill,
                  selected: currentIndex == 1,
                  onTap: () => onChanged(1),
                ),
                _SidebarItem(
                  label: familyLabel,
                  icon: CupertinoIcons.person_2_fill,
                  selected: currentIndex == 2,
                  onTap: () => onChanged(2),
                ),
                const Spacer(),
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  alignment: Alignment.centerLeft,
                  onPressed: onOpenPreferences,
                  child: Text(
                    context.tr('显示设置', 'Display settings'),
                    style:
                        textTheme.bodyMedium?.copyWith(color: Colors.white70),
                  ),
                ),
                CupertinoButton(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  alignment: Alignment.centerLeft,
                  onPressed: onLogout,
                  child: Text(
                    context.tr('退出登录', 'Sign out'),
                    style:
                        textTheme.bodyMedium?.copyWith(color: Colors.white70),
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

class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg =
        selected ? Colors.white.withValues(alpha: 0.18) : Colors.transparent;
    final fg = selected ? AppColors.accent : Colors.white70;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(9),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: AppSpacing.sm),
                Text(label,
                    style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({
    required this.profile,
    required this.locale,
    required this.onOpenPreferences,
    required this.onLogout,
  });

  final UserProfile profile;
  final Locale locale;
  final VoidCallback onOpenPreferences;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(CupertinoIcons.shield_fill,
                color: AppColors.ink, size: 18),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w600),
                ),
                Text(
                  profile.role.displayNameFor(locale),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          CupertinoButton(
            minimumSize: const Size(32, 32),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: onOpenPreferences,
            child: const Icon(CupertinoIcons.settings_solid,
                color: Colors.white70, size: 20),
          ),
          CupertinoButton(
            minimumSize: const Size(32, 32),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            onPressed: onLogout,
            child: const Icon(CupertinoIcons.square_arrow_right,
                color: Colors.white70, size: 20),
          ),
        ],
      ),
    );
  }
}

class _MobileNavBar extends StatelessWidget {
  const _MobileNavBar({
    required this.currentIndex,
    required this.dashboardLabel,
    required this.policiesLabel,
    required this.familyLabel,
    required this.onChanged,
  });

  final int currentIndex;
  final String dashboardLabel;
  final String policiesLabel;
  final String familyLabel;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
        ),
      ),
      child: CupertinoTheme(
        data: CupertinoTheme.of(context).copyWith(
          barBackgroundColor: const Color(0xCC0E1A2B),
        ),
        child: CupertinoTabBar(
          currentIndex: currentIndex,
          onTap: onChanged,
          activeColor: AppColors.accent,
          inactiveColor: Colors.white70,
          backgroundColor: const Color(0xCC0E1A2B),
          iconSize: 20,
          items: [
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.chart_bar_alt_fill),
              label: dashboardLabel,
            ),
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.doc_on_doc_fill),
              label: policiesLabel,
            ),
            BottomNavigationBarItem(
              icon: const Icon(CupertinoIcons.person_2_fill),
              label: familyLabel,
            ),
          ],
        ),
      ),
    );
  }
}
