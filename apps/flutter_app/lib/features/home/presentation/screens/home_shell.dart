// Adaptive shell with navigation rail or bottom navigation.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:wearefamily_app/core/api/api_client.dart';
import 'package:wearefamily_app/core/api/user_profile.dart';
import 'package:wearefamily_app/core/theme/app_colors.dart';
import 'package:wearefamily_app/core/theme/app_spacing.dart';
import 'package:wearefamily_app/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:wearefamily_app/features/family/presentation/screens/family_center_screen.dart';
import 'package:wearefamily_app/features/policies/presentation/screens/policies_screen.dart';
import 'package:wearefamily_app/shared/widgets/decorative_background.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.apiClient,
    required this.profile,
    required this.onLogout,
  });

  final ApiClient apiClient;
  final UserProfile profile;
  final VoidCallback onLogout;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(profile: widget.profile, apiClient: widget.apiClient),
      PoliciesScreen(profile: widget.profile, apiClient: widget.apiClient),
      FamilyCenterScreen(profile: widget.profile, apiClient: widget.apiClient),
    ];

    return Scaffold(
      body: DecorativeBackground(
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isRail = constraints.maxWidth >= 900;
              if (isRail) {
                return Row(
                  children: [
                    NavigationRail(
                      backgroundColor: Colors.transparent,
                      selectedIconTheme: const IconThemeData(color: AppColors.accent),
                      unselectedIconTheme: const IconThemeData(color: Colors.white70),
                      selectedLabelTextStyle: const TextStyle(color: AppColors.accent),
                      unselectedLabelTextStyle: const TextStyle(color: Colors.white70),
                      labelType: NavigationRailLabelType.all,
                      destinations: const [
                        NavigationRailDestination(
                          icon: Icon(Icons.dashboard_outlined),
                          selectedIcon: Icon(Icons.dashboard),
                          label: Text('看板'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.policy_outlined),
                          selectedIcon: Icon(Icons.policy),
                          label: Text('保单'),
                        ),
                        NavigationRailDestination(
                          icon: Icon(Icons.groups_outlined),
                          selectedIcon: Icon(Icons.groups),
                          label: Text('家庭中心'),
                        ),
                      ],
                      selectedIndex: _currentIndex,
                      onDestinationSelected: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        child: Column(
                          children: [
                            const CircleAvatar(
                              radius: 24,
                              backgroundColor: AppColors.mint,
                              child: Icon(Icons.shield, color: AppColors.ink),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              widget.profile.displayName,
                              style: const TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      trailing: IconButton(
                        onPressed: widget.onLogout,
                        icon: const Icon(Icons.logout, color: Colors.white70),
                        tooltip: '退出登录',
                      ),
                    ),
                    const VerticalDivider(width: 1, color: Colors.white24),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: AnimatedSwitcher(
                          duration: 250.ms,
                          child: screens[_currentIndex],
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Column(
                children: [
                  _MobileHeader(profile: widget.profile, onLogout: widget.onLogout),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: 250.ms,
                      child: screens[_currentIndex],
                    ),
                  ),
                  _MobileNavBar(
                    currentIndex: _currentIndex,
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

class _MobileHeader extends StatelessWidget {
  const _MobileHeader({required this.profile, required this.onLogout});

  final UserProfile profile;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.accent,
            child: Icon(Icons.shield, color: AppColors.ink),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(profile.displayName, style: const TextStyle(color: Colors.white)),
                Text(
                  profile.role.displayName,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onLogout,
            icon: const Icon(Icons.logout, color: Colors.white70),
          ),
        ],
      ),
    );
  }
}

class _MobileNavBar extends StatelessWidget {
  const _MobileNavBar({required this.currentIndex, required this.onChanged});

  final int currentIndex;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onChanged,
      backgroundColor: const Color(0xFF0F1C2E),
      selectedItemColor: AppColors.accent,
      unselectedItemColor: Colors.white70,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.dashboard),
          label: '看板',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.policy),
          label: '保单',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.groups),
          label: '家庭中心',
        ),
      ],
    );
  }
}


