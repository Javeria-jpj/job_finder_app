import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/applications_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/app_logo.dart';
import 'applications/applications_screen.dart';
import 'jobs/job_search_screen.dart';
import 'jobs/jobs_feed_screen.dart';
import 'profile/profile_screen.dart';

/// Shell for the signed-in app: Home, Search, Applications, Profile.
///
/// A [NavigationBar] on phones, a [NavigationRail] on wide layouts.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;

  static const _tabs = [
    JobsFeedScreen(),
    JobSearchScreen(),
    ApplicationsScreen(),
    ProfileScreen(),
  ];

  static const _destinations = <(IconData, IconData, String)>[
    (Icons.home_outlined, Icons.home, 'Home'),
    (Icons.search, Icons.search, 'Search'),
    (Icons.assignment_outlined, Icons.assignment, 'Applications'),
    (Icons.person_outline, Icons.person, 'Profile'),
  ];

  void _select(int index) => setState(() => _index = index);

  @override
  Widget build(BuildContext context) {
    // IndexedStack keeps each tab's scroll position and search text alive.
    final body = IndexedStack(index: _index, children: _tabs);
    final applicationCount = context.watch<ApplicationsController>().count;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= AppBreakpoints.wide) {
          return Scaffold(
            body: Row(
              children: [
                _Rail(
                  index: _index,
                  onSelected: _select,
                  applicationCount: applicationCount,
                ),
                const VerticalDivider(width: 1),
                Expanded(child: body),
              ],
            ),
          );
        }

        return Scaffold(
          body: body,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: _select,
            backgroundColor: AppColors.surfaceContainerLowest,
            indicatorColor: AppColors.secondaryContainer,
            surfaceTintColor: Colors.transparent,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: [
              for (var i = 0; i < _destinations.length; i++)
                NavigationDestination(
                  icon: _badged(i, applicationCount, Icon(_destinations[i].$1)),
                  selectedIcon: _badged(
                    i,
                    applicationCount,
                    Icon(_destinations[i].$2),
                  ),
                  label: _destinations[i].$3,
                ),
            ],
          ),
        );
      },
    );
  }

  /// Shows the open-application count on the Applications tab only.
  Widget _badged(int index, int count, Widget icon) {
    if (index != 2 || count == 0) return icon;
    return Badge.count(count: count, child: icon);
  }
}

class _Rail extends StatelessWidget {
  const _Rail({
    required this.index,
    required this.onSelected,
    required this.applicationCount,
  });

  final int index;
  final ValueChanged<int> onSelected;
  final int applicationCount;

  /// The rail would otherwise size itself to the widest label
  /// ("Applications"), which made it far wider than it needs to be.
  static const double _width = 112;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(fontSize: 11, letterSpacing: 0);

    return SizedBox(
      width: _width,
      child: NavigationRail(
        selectedIndex: index,
        onDestinationSelected: onSelected,
        labelType: NavigationRailLabelType.all,
        backgroundColor: AppColors.surfaceContainerLowest,
        indicatorColor: AppColors.secondaryContainer,
        minWidth: _width,
        selectedLabelTextStyle: labelStyle?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
        unselectedLabelTextStyle: labelStyle,
        leading: const Padding(
          padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: AppLogo.full(width: 88),
        ),
        destinations: [
          const NavigationRailDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: Text('Home'),
          ),
          const NavigationRailDestination(
            icon: Icon(Icons.search),
            label: Text('Search'),
          ),
          NavigationRailDestination(
            icon: applicationCount == 0
                ? const Icon(Icons.assignment_outlined)
                : Badge.count(
                    count: applicationCount,
                    child: const Icon(Icons.assignment_outlined),
                  ),
            selectedIcon: const Icon(Icons.assignment),
            label: const Text('Applications'),
          ),
          const NavigationRailDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: Text('Profile'),
          ),
        ],
      ),
    );
  }
}
