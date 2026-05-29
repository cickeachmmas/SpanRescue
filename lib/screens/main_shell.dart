// ═══════════════════════════════════════════════════════
// main_shell.dart — الهيكل الرئيسي مع Bottom Navigation
// طبق الأصل من الصور تماماً
// ═══════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/mesh_service.dart';
import '../theme/app_theme.dart';
import 'mesh_map_screen.dart';
import 'chat_screen.dart';
import 'topology_screen.dart';
import 'logs_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with TickerProviderStateMixin {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    MeshMapScreen(),
    ChatScreen(),
    TopologyScreen(),
    LogsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        border: Border(
          top: BorderSide(
            color: AppTheme.accentCyan.withOpacity(0.12),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              _navItem(0, Icons.radar,         Icons.radar,         'Mesh'),
              _navItem(1, Icons.chat_bubble_outline, Icons.chat_bubble, 'Chat', showBadge: true),
              _navItem(2, Icons.share,          Icons.share,         'Topology'),
              _navItem(3, Icons.menu,           Icons.menu,          'Logs'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    int index,
    IconData icon,
    IconData activeIcon,
    String label, {
    bool showBadge = false,
  }) {
    final isActive = _currentIndex == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // أيقونة مع Badge اختياري
            Stack(
              clipBehavior: Clip.none,
              children: [
                // هالة عند التفعيل
                if (isActive)
                  Container(
                    width: 36,
                    height: 30,
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      activeIcon,
                      color: AppTheme.accentCyan,
                      size: 20,
                    ),
                  )
                else
                  SizedBox(
                    width: 36,
                    height: 30,
                    child: Icon(
                      icon,
                      color: AppTheme.textMuted,
                      size: 20,
                    ),
                  ),

                // Badge رسائل غير مقروءة
                if (showBadge && !isActive)
                  Consumer<MeshService>(
                    builder: (_, mesh, __) {
                      if (mesh.unreadCount == 0) return const SizedBox();
                      return Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 16,
                          height: 16,
                          decoration: const BoxDecoration(
                            color: AppTheme.accentRed,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              mesh.unreadCount > 9
                                  ? '9+'
                                  : '${mesh.unreadCount}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),

            const SizedBox(height: 3),

            Text(
              label,
              style: TextStyle(
                fontFamily: 'Rajdhani',
                fontSize: 11,
                fontWeight:
                    isActive ? FontWeight.w700 : FontWeight.w400,
                color: isActive
                    ? AppTheme.accentCyan
                    : AppTheme.textMuted,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
