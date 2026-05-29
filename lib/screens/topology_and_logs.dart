// ═══════════════════════════════════════════════════════
// topology_screen.dart — Screen 3: شبكة الاتصال
// رسم حي للـ Mesh Network — طبق الأصل من الصور
// ═══════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dev_tools_screen.dart';

import '../core/mesh_service.dart';
import '../core/geo_utils.dart';
import '../models/node_info.dart';
import '../models/mesh_message.dart';
import '../theme/app_theme.dart';
import '../widgets/simulation/simulation_sheet.dart';

class TopologyScreen extends StatefulWidget {
  const TopologyScreen({super.key});

  @override
  State<TopologyScreen> createState() => _TopologyScreenState();
}

class _TopologyScreenState extends State<TopologyScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgPrimary,
        title: const Text(
          'Tactical AODV Topology',
          style: TextStyle(
            fontFamily: 'Rajdhani',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: 1,
          ),
        ),
        elevation: 0,
        actions: [
          Consumer<MeshService>(
            builder: (_, mesh, __) {
              return IconButton(
                icon: Icon(
                  mesh.simulationActive
                      ? Icons.stop_circle_outlined
                      : Icons.play_circle,
                  color: AppTheme.accentCyan,
                ),
                tooltip: mesh.simulationActive ? 'إيقاف المحاكاة' : 'تشغيل المحاكاة',
                onPressed: () => _showSimulationSheet(context, mesh),
              );
            },
          ),
        ],
      ),
      body: Consumer<MeshService>(
        builder: (context, mesh, _) {
          return _InteractiveTopology(
            mesh: mesh,
            pulseValue: _pulseController.value,
            onNodeTap: (node) => _showNodeInfoSheet(context, node, mesh),
          );
        },
      ),
    );
  }


  void _showNodeInfoSheet(
    BuildContext context,
    NodeInfo node,
    MeshService mesh,
  ) {
    final distance = mesh.distanceTo(node);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _NodeDetailSheet(node: node, distance: distance),
    );
  }

  void _showSimulationSheet(BuildContext context, MeshService mesh) {
    showSimulationSheet(context, mesh);
  }
}

class _InteractiveTopology extends StatefulWidget {
  final MeshService mesh;
  final double pulseValue;
  final void Function(NodeInfo) onNodeTap;

  const _InteractiveTopology({required this.mesh, required this.pulseValue, required this.onNodeTap});

  @override
  State<_InteractiveTopology> createState() => _InteractiveTopologyState();
}

class _InteractiveTopologyState extends State<_InteractiveTopology> {
  double _zoom = 1.0;
  Offset _pan = Offset.zero;
  Offset? _lastFocal;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onScaleStart: (details) {
        _lastFocal = details.focalPoint;
      },
      onScaleUpdate: (details) {
        setState(() {
          _zoom = (_zoom * details.scale).clamp(0.5, 2.0);
          if (_lastFocal != null) {
            _pan += details.focalPoint - _lastFocal!;
            _lastFocal = details.focalPoint;
          }
        });
      },
      onScaleEnd: (_) {
        _lastFocal = null;
      },
      onTapDown: (details) {
        // detect tap on local node center first
        final size = MediaQuery.of(context).size;
        final center = Offset(size.width / 2, size.height / 2) + _pan;
        final localTapRadius = 32.0 * _zoom;
        if ((center - details.localPosition).distance < localTapRadius) {
          widget.onNodeTap(NodeInfo(
            nodeId: widget.mesh.myNodeId,
            groupId: widget.mesh.simulatedLocalGroupId ?? widget.mesh.myGroupId,
            role: widget.mesh.myRole,
            triageState: widget.mesh.myTriageState,
            medicalState: widget.mesh.myTriageState == TriageState.red
                ? MedicalState.red
                : MedicalState.none,
            location: widget.mesh.myLocation,
            battery: widget.mesh.myBattery,
            lastSeenTimestamp: DateTime.now().millisecondsSinceEpoch,
            discoveredVia: null,
            hopCount: 0,
            isGroupOwner: widget.mesh.isGroupOwner,
            isBridgeNode: widget.mesh.isGroupOwner,
            ipAddress: widget.mesh.myIpAddress,
          ));
          return;
        }

        // detect node under tap
        for (final node in widget.mesh.onlineNodes) {
          final pos = _TopologyPainter(
            nodes: widget.mesh.onlineNodes,
            myNodeId: widget.mesh.myNodeId,
            pulseValue: widget.pulseValue,
            zoom: _zoom,
            pan: _pan,
            localGroupId: widget.mesh.simulatedLocalGroupId,
          )._nodePosition(node, center);
          final hitRadius = 36.0 * _zoom;
          if ((pos - details.localPosition).distance < hitRadius) {
            widget.onNodeTap(node);
            return;
          }
        }
      },
      child: CustomPaint(
        painter: _TopologyPainter(
          nodes: widget.mesh.onlineNodes,
          myNodeId: widget.mesh.myNodeId,
          pulseValue: widget.pulseValue,
          zoom: _zoom,
          pan: _pan,
          localGroupId: widget.mesh.simulatedLocalGroupId,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

// ─── رسّام الـ Topology ───────────────────────────────
class _TopologyPainter extends CustomPainter {
  final List<NodeInfo> nodes;
  final String myNodeId;
  final double pulseValue;
  // zoom & pan support
  final double zoom;
  final Offset pan;
  final String? localGroupId;

  _TopologyPainter({
    required this.nodes,
    required this.myNodeId,
    required this.pulseValue,
    this.zoom = 1.0,
    this.pan = Offset.zero,
    this.localGroupId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2) + pan;

    _drawBackgroundRings(canvas, center, size);
    _drawConnections(canvas, center);
    _drawNodes(canvas, center);
    _drawMyNode(canvas, center);
  }

  void _drawBackgroundRings(Canvas canvas, Offset center, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF0A0A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, 50.0 * i, paint);
    }
  }

  void _drawConnections(Canvas canvas, Offset center) {
    final linePaint = Paint()
      ..color = AppTheme.accentCyan.withOpacity(0.4)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // Draw group edges: connect each node to its GO, and draw bridge lines between GOs
    final groups = <String, List<NodeInfo>>{};
    for (final n in nodes) {
      groups.putIfAbsent(n.groupId, () => []).add(n);
    }

    // connect members to their GO
    for (final entry in groups.entries) {
      final members = entry.value;
      NodeInfo? go;
      for (final m in members) if (m.isGroupOwner) go = m;
      if (go == null && members.isNotEmpty) go = members.first;

      for (final m in members) {
        final mPos = _nodePosition(m, center);
        final goPos = _nodePosition(go!, center);
        canvas.drawLine(goPos, mPos, linePaint);
      }
    }

    // draw bridges between GOs
    final gos = nodes.where((n) => n.isGroupOwner).toList();
    for (int i = 0; i < gos.length; i++) {
      for (int j = i + 1; j < gos.length; j++) {
        final a = _nodePosition(gos[i], center);
        final b = _nodePosition(gos[j], center);
        canvas.drawLine(a, b, linePaint..color = AppTheme.accentYellow.withOpacity(0.35));
      }
    }

    // connect local node to its simulated group GO when applicable
    if (localGroupId != null) {
      NodeInfo? groupGO;
      try {
        groupGO = nodes.firstWhere((n) => n.groupId == localGroupId && n.isGroupOwner);
      } catch (_) {
        try {
          groupGO = nodes.firstWhere((n) => n.groupId == localGroupId);
        } catch (_) {
          groupGO = null;
        }
      }
      if (groupGO != null) {
        final localPos = center;
        final goPos = _nodePosition(groupGO, center);
        canvas.drawLine(
          localPos,
          goPos,
          Paint()
            ..color = AppTheme.accentCyan.withOpacity(0.5)
            ..strokeWidth = 2,
        );
      }
    }
  }

  void _drawNodes(Canvas canvas, Offset center) {
    for (final node in nodes) {
      final pos = _nodePosition(node, center);

        final color = node.isCritical
          ? AppTheme.accentRed
          : node.isVictim
              ? AppTheme.accentOrange
              : AppTheme.accentCyan;

      // هالة نابضة للـ SOS
      if (node.isCritical) {
        canvas.drawCircle(
          pos,
          22 + 6 * pulseValue,
          Paint()..color = AppTheme.accentRed.withOpacity(0.2 * pulseValue),
        );
      }

      // دائرة خلفية
      canvas.drawCircle(
        pos,
        20,
        Paint()..color = color.withOpacity(0.15),
      );

      // حد
      canvas.drawCircle(
        pos,
        20,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );

      // رمز + أو علامة GO
      if (node.isGroupOwner) {
        // GO badge
        final rect = Rect.fromCenter(center: pos.translate(0, -6), width: 18, height: 12);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()..color = AppTheme.accentYellow,
        );
        final tpGo = TextPainter(
          textDirection: TextDirection.ltr,
          text: const TextSpan(
            text: 'GO',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 8,
              color: Colors.black,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        tpGo.layout();
        tpGo.paint(canvas, Offset(rect.center.dx - tpGo.width / 2, rect.center.dy - tpGo.height / 2));
      } else {
        _drawCross(canvas, pos, color);
      }

      // اسم العقدة
      final textPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: node.nodeId.length > 10
              ? '${node.nodeId.substring(0, 10)}..'
              : node.nodeId,
          style: const TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 9,
            color: Colors.white70,
          ),
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(pos.dx - textPainter.width / 2, pos.dy + 24),
      );

      // draw group label near GO
      if (node.isGroupOwner) {
        final gLabel = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: node.groupId,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 10,
              color: AppTheme.textMuted,
            ),
          ),
        );
        gLabel.layout();
        gLabel.paint(canvas, Offset(pos.dx - gLabel.width / 2, pos.dy - 40));
      }
    }
  }

  Offset _nodePosition(NodeInfo node, Offset center) {
    final idx = nodes.indexOf(node);
    final count = nodes.length == 0 ? 1 : nodes.length;
    final angle = (idx / count) * 2 * math.pi - math.pi / 2;
    final baseRadius = 130.0 * zoom;
    if (node.isGroupOwner) {
      return Offset(
        center.dx + (baseRadius - 40) * math.cos(angle),
        center.dy + (baseRadius - 40) * math.sin(angle),
      );
    }
    return Offset(
      center.dx + baseRadius * math.cos(angle),
      center.dy + baseRadius * math.sin(angle),
    );
  }

  void _drawMyNode(Canvas canvas, Offset center) {
    const color = AppTheme.accentCyan;

    // هالة خارجية
    canvas.drawCircle(
      center,
      32 + 4 * pulseValue,
      Paint()
        ..color = color.withOpacity(0.08)
        ..style = PaintingStyle.fill,
    );

    // دائرة خلفية
    canvas.drawCircle(
      center,
      24,
      Paint()..color = color.withOpacity(0.2),
    );

    // حد
    canvas.drawCircle(
      center,
      24,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    _drawCross(canvas, center, color);

    // نص "Me"
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: const TextSpan(
        text: 'Me',
        style: TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 10,
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
    tp.layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy + 28));
  }

  void _drawCross(Canvas canvas, Offset center, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx - 8, center.dy),
      Offset(center.dx + 8, center.dy),
      paint,
    );
    canvas.drawLine(
      Offset(center.dx, center.dy - 8),
      Offset(center.dx, center.dy + 8),
      paint,
    );
  }

  @override
  bool shouldRepaint(_TopologyPainter old) =>
      old.pulseValue != pulseValue || old.nodes != nodes;
}

// ─── Bottom Sheet معلومات العقدة ──────────────────────
class _NodeDetailSheet extends StatelessWidget {
  final NodeInfo node;
  final double distance;

  const _NodeDetailSheet({required this.node, required this.distance});

  @override
  Widget build(BuildContext context) {
    final color = node.isCritical ? AppTheme.accentRed : AppTheme.accentCyan;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1B2A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textMuted,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color),
                ),
                child: Icon(Icons.add, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                node.nodeId,
                style: const TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const Divider(color: Color(0xFF1A2A3A), height: 24),
          _row(Icons.battery_full, 'Battery',
              '${node.battery}%', _batteryColor(node.battery)),
          _row(Icons.my_location, 'Distance',
              GeoUtils.formatDistance(distance), AppTheme.accentCyan),
          _row(Icons.work, 'Role',
              node.role.name.toUpperCase(),
              node.isVictim ? AppTheme.accentRed : AppTheme.accentGreen),
          _row(Icons.medical_services, 'Triage State',
              node.triageState.name.toUpperCase(),
              _triageColor(node.triageState)),
          _row(Icons.device_hub, 'Connected Via',
              node.discoveredVia ?? 'Direct', AppTheme.textSecondary),
          _row(Icons.lan, 'Group',
              node.groupId, AppTheme.accentCyan),
          _row(Icons.access_time, 'Last Seen',
              node.lastSeenText, AppTheme.textSecondary),
          _row(Icons.route, 'Hop Count',
              '${node.hopCount}', AppTheme.textSecondary),
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 11,
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _batteryColor(int b) {
    if (b > 50) return AppTheme.accentGreen;
    if (b > 20) return AppTheme.accentYellow;
    return AppTheme.accentRed;
  }

  Color _triageColor(TriageState s) {
    switch (s) {
      case TriageState.red: return AppTheme.accentRed;
      case TriageState.yellow: return AppTheme.accentYellow;
      case TriageState.green: return AppTheme.accentGreen;
      default: return AppTheme.textSecondary;
    }
  }
}

// ═══════════════════════════════════════════════════════
// logs_screen.dart — Screen 4: لوحة المطوّر
// ═══════════════════════════════════════════════════════

class LogsScreen extends StatelessWidget {
  const LogsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppTheme.bgPrimary,
        title: const Text(
          'System Logs',
          style: TextStyle(
            fontFamily: 'Rajdhani',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
            letterSpacing: 1,
          ),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppTheme.textMuted),
            onPressed: () {
              context.read<MeshService>().systemLogs.clear();
            },
          ),
        ],
      ),
      body: Consumer<MeshService>(
        builder: (context, mesh, _) {
          if (mesh.systemLogs.isEmpty) {
            return const Center(
              child: Text(
                'لا توجد سجلات بعد...',
                style: TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: mesh.systemLogs.length,
            itemBuilder: (context, index) {
              final log = mesh.systemLogs[index];
              return _LogEntry(entry: log);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DevToolsScreen()));
        },
        child: const Icon(Icons.developer_mode),
      ),
    );
  }
}

class _LogEntry extends StatelessWidget {
  final LogEntry entry;

  const _LogEntry({required this.entry});

  @override
  Widget build(BuildContext context) {
    final color = _levelColor(entry.level);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // النقطة الملونة
          Padding(
            padding: const EdgeInsets.only(top: 4, right: 10),
            child: Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          ),

          // المحتوى
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '${entry.isoTimestamp}  ',
                    style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 9,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  TextSpan(
                    text: '${entry.prefix}${entry.message}',
                    style: TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 11,
                      color: color,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _levelColor(LogLevel level) {
    switch (level) {
      case LogLevel.info: return AppTheme.textSecondary;
      case LogLevel.debug: return AppTheme.textMuted;
      case LogLevel.warning: return AppTheme.accentYellow;
      case LogLevel.error: return AppTheme.accentRed;
      case LogLevel.sos: return AppTheme.accentRed;
    }
  }
}
