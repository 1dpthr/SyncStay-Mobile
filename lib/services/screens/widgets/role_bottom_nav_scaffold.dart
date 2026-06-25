import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../app_state.dart';
import 'syncstay_app_bar.dart';

class RoleNavItem {
  final String label;
  final IconData icon;
  const RoleNavItem({required this.label, required this.icon});
}

/// Reusable dashboard shell with bottom navigation for Admin, Owner, Warden.
class RoleBottomNavScaffold extends StatefulWidget {
  final String title;
  final List<RoleNavItem> items;
  final List<Widget> pages;
  final Widget? header;
  final Widget? floatingActionButton;
  final bool showThemeToggle;
  final bool showNotifications;
  final bool showLogout;

  const RoleBottomNavScaffold({
    super.key,
    required this.title,
    required this.items,
    required this.pages,
    this.header,
    this.floatingActionButton,
    this.showThemeToggle = true,
    this.showNotifications = true,
    this.showLogout = true,
  }) : assert(items.length == pages.length);

  @override
  State<RoleBottomNavScaffold> createState() => _RoleBottomNavScaffoldState();
}

class _RoleBottomNavScaffoldState extends State<RoleBottomNavScaffold> {
  late PageController _pageController;
  int _lastDashboardTabJumpToken = 0;

  @override
  void initState() {
    super.initState();
    final state = Provider.of<AppState>(context, listen: false);
    final index = state.selectedNavIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: index);
    _lastDashboardTabJumpToken = state.dashboardTabJumpToken;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToTab(int index, AppState state) {
    state.setSelectedNavIndex(index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Widget _buildAppDrawer(BuildContext context, AppState state) {
    final user = state.currentUser!;
    final displayName = user.name.isNotEmpty ? user.name : user.studentId.split('@')[0];

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            accountEmail: Text('$syncStayAppName · ${syncStaySiteLabel(user.role)}\n${user.studentId}'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                displayName[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 32,
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          ...List.generate(widget.items.length, (index) {
            final item = widget.items[index];
            final active = state.selectedNavIndex == index;
            return ListTile(
              leading: Icon(
                item.icon,
                color: active ? Theme.of(context).colorScheme.primary : null,
              ),
              title: Text(
                item.label,
                style: TextStyle(
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: active ? Theme.of(context).colorScheme.primary : null,
                ),
              ),
              selected: active,
              onTap: () {
                Navigator.pop(context);
                _goToTab(index, state);
              },
            );
          }),
          const Divider(),
          if (widget.showThemeToggle)
            ListTile(
              leading: Icon(state.isDarkMode ? Icons.dark_mode : Icons.light_mode),
              title: Text(state.isDarkMode ? 'Dark Mode' : 'Light Mode'),
              onTap: () {
                state.toggleTheme();
                Navigator.pop(context);
              },
            ),
          if (widget.showNotifications)
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.pop(context);
                _showNotifications(state);
              },
            ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () {
              state.logout();
              Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
            },
          ),
        ],
      ),
    );
  }

  void _showNotifications(AppState state) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          final notifications = state.getNotificationsForCurrentUser();
          return Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ),
              ),
              Expanded(
                child: notifications.isEmpty
                    ? const Center(child: Text('No notifications yet.'))
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: notifications.length,
                        itemBuilder: (context, i) {
                          final n = notifications[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: Text(n.message),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (state.currentUser?.isAccountBlocked == true) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) {
              Navigator.pushReplacementNamed(context, '/blocked-account');
            }
          });
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final activeIndex = state.selectedNavIndex.clamp(0, widget.items.length - 1);
        final pageTitle = widget.items[activeIndex].label;

        if (state.dashboardTabJumpToken != _lastDashboardTabJumpToken) {
          _lastDashboardTabJumpToken = state.dashboardTabJumpToken;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted || !_pageController.hasClients) return;
            _pageController.animateToPage(
              activeIndex,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            );
          });
        }

        return Scaffold(
          drawer: _buildAppDrawer(context, state),
          appBar: syncStayAppBar(
            context,
            screenTitle: pageTitle,
            actions: [
              if (widget.showThemeToggle)
                IconButton(
                  icon: Icon(state.isDarkMode ? Icons.dark_mode : Icons.light_mode),
                  onPressed: state.toggleTheme,
                  tooltip: 'Toggle theme',
                ),
              if (widget.showNotifications)
                IconButton(
                  icon: const Icon(Icons.notifications_outlined),
                  onPressed: () => _showNotifications(state),
                  tooltip: 'Notifications',
                ),
              if (widget.showLogout)
                IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () {
                    state.logout();
                    Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
                  },
                  tooltip: 'Logout',
                ),
            ],
          ),
          body: Column(
            children: [
              if (widget.header != null) widget.header!,
              Expanded(
                child: PageView(
                  controller: _pageController,
                  onPageChanged: state.setSelectedNavIndex,
                  physics: const BouncingScrollPhysics(),
                  children: widget.pages,
                ),
              ),
            ],
          ),
          floatingActionButton: widget.floatingActionButton,
          bottomNavigationBar: SafeArea(
            top: false,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                children: List.generate(widget.items.length, (index) {
                  final item = widget.items[index];
                  final active = activeIndex == index;
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => _goToTab(index, state),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                        decoration: BoxDecoration(
                          color: active
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.12)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.icon,
                              size: 22,
                              color: active ? Theme.of(context).colorScheme.primary : Colors.grey,
                            ),
                            const SizedBox(height: 3),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                item.label,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: active ? FontWeight.bold : FontWeight.w500,
                                  color: active ? Theme.of(context).colorScheme.primary : Colors.grey,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }
}
