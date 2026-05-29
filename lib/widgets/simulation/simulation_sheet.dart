import 'package:flutter/material.dart';
import '../../core/mesh_service.dart';
import '../../theme/app_theme.dart';

Future<void> showSimulationSheet(BuildContext context, MeshService mesh) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: AppTheme.textSecondary.withAlpha(38)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
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
                Text(
                  mesh.simulationActive ? 'محاكاة الشبكة النشطة' : 'بدء المحاكاة',
                  style: const TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  mesh.simulationActive
                      ? 'تشغيل ${mesh.simulationNodeCount} جهازًا افتراضيًا و ${mesh.simulatedNetworkDeviceCount} جهازًا في الشبكة المحلية'
                      : 'انقر لتوليد شبكة اختبارية كاملة مع رسائل، SOS، أجهزة قريبة، وطوبولوجيا.',
                  style: const TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 20),
                _simulationButton(
                  label: 'ابدأ 5 أجهزة افتراضية',
                  icon: Icons.domain,
                  onPressed: () {
                    Navigator.pop(context);
                    mesh.startSimulation(nodeCount: 5);
                  },
                ),
                const SizedBox(height: 12),
                _simulationButton(
                  label: 'ابدأ 12 جهازًا افتراضيًا',
                  icon: Icons.wifi,
                  onPressed: () {
                    Navigator.pop(context);
                    mesh.startSimulation(nodeCount: 12);
                  },
                ),
                const SizedBox(height: 12),
                _simulationButton(
                  label: 'ابدأ 20 جهازًا افتراضيًا',
                  icon: Icons.cloud,
                  onPressed: () {
                    Navigator.pop(context);
                    mesh.startSimulation(nodeCount: 20);
                  },
                ),
                const SizedBox(height: 12),
                _simulationButton(
                  label: 'بدء سيناريو كامل 20 جهازًا',
                  icon: Icons.lightbulb,
                  backgroundColor: AppTheme.accentYellow,
                  onPressed: () {
                    Navigator.pop(context);
                    mesh.startFullSimulation(nodeCount: 20);
                  },
                ),
                const SizedBox(height: 16),
                _simulationButton(
                  label: 'أرسل رسالة نصية تجريبية',
                  icon: Icons.chat,
                  onPressed: () {
                    Navigator.pop(context);
                    if (mesh.firstSimulatedNodeId != null) {
                      mesh.simulateIncomingChat(
                        mesh.firstSimulatedNodeId!,
                        'Hello from simulated node',
                      );
                    } else {
                      mesh.startSimulation(nodeCount: 5);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _simulationButton(
                  label: 'أرسل رسالة صوتية تجريبية',
                  icon: Icons.mic,
                  onPressed: () {
                    Navigator.pop(context);
                    if (mesh.firstSimulatedNodeId != null) {
                      mesh.simulateIncomingVoice(mesh.firstSimulatedNodeId!);
                    } else {
                      mesh.startSimulation(nodeCount: 5);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _simulationButton(
                  label: 'أرسل SOS تجريبية',
                  icon: Icons.warning,
                  backgroundColor: AppTheme.accentRed,
                  onPressed: () {
                    Navigator.pop(context);
                    if (mesh.firstSimulatedNodeId != null) {
                      mesh.simulateIncomingSOS(mesh.firstSimulatedNodeId!);
                    } else {
                      mesh.startSimulation(nodeCount: 5);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _simulationButton(
                  label: 'اظهر مؤشر كتابة',
                  icon: Icons.keyboard,
                  onPressed: () {
                    Navigator.pop(context);
                    if (mesh.firstSimulatedNodeId != null) {
                      mesh.simulateTyping(mesh.firstSimulatedNodeId!);
                    }
                  },
                ),
                const SizedBox(height: 12),
                _simulationButton(
                  label: 'توليد أجهزة قريبة على الشبكة',
                  icon: Icons.router,
                  onPressed: () {
                    Navigator.pop(context);
                    mesh.simulateNearbyDevices(appActiveCount: 4, wifiOnlyCount: 6);
                  },
                ),
                const SizedBox(height: 12),
                _simulationButton(
                  label: 'توليد إشارة GO_BEACON',
                  icon: Icons.signal_wifi_4_bar,
                  onPressed: () {
                    Navigator.pop(context);
                    mesh.simulateGroupBeacon();
                  },
                ),
                const SizedBox(height: 12),
                _simulationButton(
                  label: mesh.simulationActive ? 'إيقاف المحاكاة' : 'إغلاق',
                  icon: mesh.simulationActive ? Icons.stop : Icons.close,
                  backgroundColor: mesh.simulationActive ? AppTheme.accentRed : AppTheme.bgSecondary,
                  onPressed: () {
                    Navigator.pop(context);
                    if (mesh.simulationActive) {
                      mesh.stopSimulation();
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _simulationButton({
  required String label,
  required IconData icon,
  Color backgroundColor = AppTheme.accentCyan,
  required VoidCallback onPressed,
}) {
  return SizedBox(
    width: double.infinity,
    child: ElevatedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      onPressed: onPressed,
    ),
  );
}
