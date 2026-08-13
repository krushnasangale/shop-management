import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flashbill/theme/adaptive.dart';

class AppDestination {
  const AppDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.badge,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? badge;
}

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({
    super.key,
    required this.index,
    required this.destinations,
    required this.onSelect,
  });

  final int index;
  final List<AppDestination> destinations;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    if (Adaptive.isCupertino) {
      return CupertinoTabBar(
        currentIndex: index,
        onTap: onSelect,
        items: [
          for (final dest in destinations)
            BottomNavigationBarItem(
              icon: _NavIcon(
                icon: dest.icon,
                badge: dest.badge,
              ),
              activeIcon: _NavIcon(
                icon: dest.selectedIcon,
                badge: dest.badge,
              ),
              label: dest.label,
            ),
        ],
      );
    }

    final scheme = Theme.of(context).colorScheme;
    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: onSelect,
      destinations: [
        for (final dest in destinations)
          NavigationDestination(
            icon: _NavIcon(icon: dest.icon, badge: dest.badge),
            selectedIcon: _NavIcon(
              icon: dest.selectedIcon,
              badge: dest.badge,
              selected: true,
            ),
            label: dest.label,
          ),
      ],
      surfaceTintColor: scheme.surface,
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.icon,
    this.badge,
    this.selected = false,
  });

  final IconData icon;
  final String? badge;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final child = Icon(icon, size: selected ? 24 : 22);
    if (badge == null || badge!.isEmpty) return child;
    return Badge(label: Text(badge!), child: child);
  }
}
