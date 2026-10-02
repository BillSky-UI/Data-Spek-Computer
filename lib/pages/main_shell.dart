import 'package:flutter/material.dart';

import '../services/settings_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/cloud_status_banner.dart';
import '../widgets/clickable.dart';
import 'dashboard_page.dart';
import 'device_list_page.dart';

class MainShell extends StatefulWidget {
  final SettingsController settings;
  const MainShell({super.key, required this.settings});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Scaffold(
      body: Column(
        children: [
          const CloudStatusBanner(),
          Expanded(
            child: _index == 0
                // Key baru memaksa refresh data saat berpindah tab.
                ? DeviceListPage(key: UniqueKey(), settings: widget.settings)
                : DashboardPage(key: UniqueKey(), settings: widget.settings),
          ),
        ],
      ),
      bottomNavigationBar: Clickable(
        child: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: c.surface,
        indicatorColor: c.accent.withValues(alpha: 0.25),
        height: 68,
        destinations: [
          NavigationDestination(
            icon: Icon(Icons.devices_other, color: c.textMuted),
            selectedIcon: Icon(Icons.devices_other, color: c.accent),
            label: 'Daftar Perangkat',
          ),
          // Dashboard di posisi paling kanan (tab terakhir).
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined, color: c.textMuted),
            selectedIcon: Icon(Icons.dashboard, color: c.accent),
            label: 'Dashboard',
          ),
        ],
        ),
      ),
    );
  }
}