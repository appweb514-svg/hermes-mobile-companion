import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../chat/chat_screen.dart';
import '../studio/studio_screen.dart';
import '../terminal/terminal_screen.dart';
import '../kanban/kanban_screen.dart';
import '../subagents/subagents_screen.dart';
import '../hud/hud_screen.dart';
import '../settings/settings_screen.dart';
import '../../shared/widgets/server_status_badge.dart';

/// Provider for the current tab index.
final currentTabProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentIndex = ref.watch(currentTabProvider);

    return Scaffold(
      body: Column(
        children: [
          // ---- Top safe area + server status ----
          SizedBox(height: MediaQuery.of(context).padding.top + 2),
          Padding(
            padding: const EdgeInsets.only(right: 12, bottom: 2),
            child: Align(
              alignment: Alignment.topRight,
              child: SizedBox(
                height: 26,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ServerStatusBadge(),
                ),
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: currentIndex,
              children: const [
                ChatScreen(),
                StudioScreen(),
                KanbanScreen(),
                SubagentsScreen(),
                TerminalScreen(),
                HudScreen(),
                SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(currentTabProvider.notifier).state = index;
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_awesome_mosaic_outlined),
            selectedIcon: Icon(Icons.auto_awesome_mosaic),
            label: 'Studio',
          ),
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Board',
          ),
          NavigationDestination(
            icon: Icon(Icons.account_tree_outlined),
            selectedIcon: Icon(Icons.account_tree),
            label: 'Agents',
          ),
          NavigationDestination(
            icon: Icon(Icons.terminal_outlined),
            selectedIcon: Icon(Icons.terminal),
            label: 'Terminal',
          ),
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'HUD',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}
