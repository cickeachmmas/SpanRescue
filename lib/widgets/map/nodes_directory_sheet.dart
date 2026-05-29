// ═══════════════════════════════════════════════════════
// nodes_directory_sheet.dart — قائمة الأجهزة
// Tactical Nodes Directory — طبق الأصل من الصور
// ═══════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/mesh_service.dart';
import '../../core/geo_utils.dart';
import '../../models/node_info.dart';
import '../../models/mesh_message.dart';
import '../../theme/app_theme.dart';

class NodesDirectorySheet extends StatelessWidget {
  const NodesDirectorySheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MeshService>(
      builder: (context, mesh, _) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0D0D0D),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                decoration: BoxDecoration(
                  color: AppTheme.textMuted,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // العنوان
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Tactical Nodes Directory',
                      style: TextStyle(
                        fontFamily: 'Rajdhani',
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const Divider(color: Color(0xFF1A1A1A), height: 1),

              // قائمة المنقذين
              if (mesh.rescuers.isNotEmpty) ...[
                _buildSectionHeader(
                  'Active Rescuers',
                  mesh.rescuers.length,
                  AppTheme.accentCyan,
                  Icons.medical_services,
                ),
                ...mesh.rescuers.map(
                  (n) => _NodeTile(
                    node: n,
                    distance: mesh.distanceTo(n),
                  ),
                ),
              ],

              // قائمة الضحايا
              if (mesh.victims.isNotEmpty) ...[
                _buildSectionHeader(
                  'Active Victims',
                  mesh.victims.length,
                  AppTheme.accentRed,
                  Icons.personal_injury,
                ),
                ...mesh.victims.map(
                  (n) => _NodeTile(
                    node: n,
                    distance: mesh.distanceTo(n),
                    isVictim: true,
                  ),
                ),
              ],

              // لا يوجد أجهزة
              if (mesh.onlineNodes.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.wifi_off,
                        color: AppTheme.textMuted,
                        size: 40,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'لا يوجد أجهزة متصلة',
                        style: TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(
    String title,
    int count,
    Color color,
    IconData icon,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(
            '$title ($count)',
            style: TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── بطاقة جهاز واحد ─────────────────────────────────
class _NodeTile extends StatelessWidget {
  final NodeInfo node;
  final double distance;
  final bool isVictim;

  const _NodeTile({
    required this.node,
    required this.distance,
    this.isVictim = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isVictim ? AppTheme.accentRed : AppTheme.accentCyan;
    final batteryColor = node.battery > 50
        ? AppTheme.accentGreen
        : node.battery > 20
            ? AppTheme.accentYellow
            : AppTheme.accentRed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // أيقونة الدور
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Icon(
              isVictim ? Icons.personal_injury : Icons.medical_services,
              color: color,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),

          // المعلومات
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.nodeId,
                  style: const TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  GeoUtils.formatDistance(distance),
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 10,
                    color: color,
                  ),
                ),
              ],
            ),
          ),

          // البطارية
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Text(
                    '${node.battery}%',
                    style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 11,
                      color: batteryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.battery_full,
                    color: batteryColor,
                    size: 14,
                  ),
                ],
              ),
              if (node.triageState != TriageState.none) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _triageColor(node.triageState).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    node.triageState.name.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 8,
                      color: _triageColor(node.triageState),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Color _triageColor(TriageState state) {
    switch (state) {
      case TriageState.red: return AppTheme.accentRed;
      case TriageState.yellow: return AppTheme.accentYellow;
      case TriageState.green: return AppTheme.accentGreen;
      default: return AppTheme.textSecondary;
    }
  }
}
