// ═══════════════════════════════════════════════════════
// chat_screen.dart — Screen 2: غرفة العمليات
// طبق الأصل من الصور — Dark Tactical Chat
// ═══════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/mesh_service.dart';
import '../core/network_scanner.dart';
import '../core/wifi_direct_service.dart';
import '../core/audio_service.dart';
import '../models/mesh_message.dart';
import '../theme/app_theme.dart';
import '../widgets/chat/message_bubble.dart';
import '../widgets/chat/sos_alert_card.dart';
import '../widgets/chat/sos_modal.dart';
import '../widgets/chat/chat_input_bar.dart';
import '../widgets/simulation/simulation_sheet.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ScrollController _scrollController = ScrollController();
  final AudioService _audioService = AudioService();
  StreamSubscription? _sosSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final mesh = context.read<MeshService>();
      mesh.markAllRead();
      _audioService.setMeshService(mesh);
      _listenForSOS();
      mesh.startNetworkScan();
    });
  }

  void _listenForSOS() {
    _sosSub = context.read<MeshService>().onSOS.listen((sos) {
      if (mounted) {
        _audioService.playSOSAlarm();
        _showSOSModal(sos);
      }
    });
  }

  void _showSOSModal(MeshMessage sos) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => SOSModal(message: sos),
    );
  }

  @override
  void dispose() {
    _sosSub?.cancel();
    _scrollController.dispose();
    context.read<MeshService>().stopNetworkScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgPrimary,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // قائمة الرسائل
          Expanded(child: _buildMessageList()),
          // شريط الإرسال
          ChatInputBar(
            onSendText: _sendText,
            onSendVoice: _sendVoice,
            audioService: _audioService,
          ),
        ],
      ),
    );
  }

  // ─── AppBar طبق الأصل ────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppTheme.bgPrimary,
      elevation: 0,
      titleSpacing: 16,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Global Squad',
            style: TextStyle(
              fontFamily: 'Rajdhani',
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          Consumer<MeshService>(
            builder: (_, mesh, __) => Text(
              mesh.isMeshActive ? 'Mesh Network Active' : 'Connecting...',
              style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 10,
                color: mesh.isMeshActive
                    ? AppTheme.accentGreen
                    : AppTheme.accentYellow,
              ),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.developer_board, color: AppTheme.accentCyan),
          onPressed: () => showSimulationSheet(context, context.read<MeshService>()),
          tooltip: 'Simulation',
        ),
        IconButton(
          icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
          onPressed: _confirmSendSOS,
          tooltip: 'Send SOS',
        ),
        PopupMenuButton<dynamic>(
          tooltip: 'Nearby devices',
          icon: const Icon(Icons.devices, color: AppTheme.accentCyan),
          onSelected: (selected) {
            if (selected == null) {
              _showNetworkDevices();
            } else if (selected is NetworkDevice) {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Device'),
                  content: Text('${selected.ipAddress}\nType: ${selected.type == DeviceType.appActive ? "App + Wi‑Fi" : "Wi‑Fi only"}'),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
                ),
              );
            }
          },
          itemBuilder: (ctx) {
            final mesh = ctx.read<MeshService>();
            final devices = mesh.discoveredDevices;
            final items = <PopupMenuEntry<dynamic>>[];

            // Show up to 20 devices quickly in the dropdown
            for (final d in devices.take(20)) {
              items.add(PopupMenuItem(
                value: d,
                child: Row(
                  children: [
                    Icon(
                      d.type == DeviceType.appActive ? Icons.check_circle : Icons.wifi,
                      color: d.type == DeviceType.appActive ? AppTheme.accentGreen : AppTheme.accentYellow,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(d.hostName ?? d.ipAddress)),
                  ],
                ),
              ));
            }

            items.add(const PopupMenuDivider());
            items.add(const PopupMenuItem(value: null, child: Text('Open full list')));
            return items;
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
          onSelected: (value) {
            if (value == 'quickReplies') {
              _showQuickReplyManager();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'quickReplies',
              child: Text('Manage quick replies'),
            ),
          ],
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 0.5,
          color: const Color(0xFF1A1A1A),
        ),
      ),
    );
  }

  // ─── قائمة الرسائل ───────────────────────────────
  Widget _buildMessageList() {
    return Consumer<MeshService>(
      builder: (context, mesh, _) {
        final messages = mesh.chatMessages;
        final typingUsers = mesh.getTypingUsers();

        if (messages.isEmpty && typingUsers.isEmpty) {
          return _buildEmptyState();
        }

        return ListView.builder(
          controller: _scrollController,
          reverse: true, // أحدث رسالة في الأسفل
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: messages.length + (typingUsers.isNotEmpty ? 1 : 0),
          itemBuilder: (context, index) {
            // عرض typing indicator في الأعلى
            if (typingUsers.isNotEmpty && index == 0) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    const SizedBox(width: 6),
                    _buildAvatar(typingUsers.first),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.bubbleOther,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildDot(0),
                          const SizedBox(width: 4),
                          _buildDot(1),
                          const SizedBox(width: 4),
                          _buildDot(2),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            final messageIndex = typingUsers.isNotEmpty ? index - 1 : index;
            if (messageIndex >= messages.length) return const SizedBox.shrink();

            final message = messages[messageIndex];
            final isMe = message.senderId == mesh.myNodeId;

            // بطاقة SOS
            if (message.isSOS) {
              return SOSAlertCard(message: message, isMe: isMe);
            }

            // رسالة عادية أو صوتية
            return MessageBubble(
              message: message,
              isMe: isMe,
              audioService: _audioService,
            );
          },
        );
      },
    );
  }

  Widget _buildAvatar(String nodeId) {
    final id = nodeId.replaceAll('Node_', '');
    final num = int.tryParse(id) ?? 0;
    final colors = [
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    final color = colors[num % colors.length];

    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: Center(
        child: Text(
          (num % 9 + 1).toString(),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int delay) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.accentCyan,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            color: AppTheme.textMuted,
            size: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'لا توجد رسائل بعد',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ابدأ التواصل مع فريق الإنقاذ',
            style: TextStyle(
              fontFamily: 'SpaceMono',
              fontSize: 10,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ─── إرسال نص ────────────────────────────────────
  void _sendText(String text) {
    if (text.trim().isEmpty) return;
    final mesh = context.read<MeshService>();
    final wifi = context.read<WifiDirectService>();
    final msg = mesh.createChatMessage(text.trim());
    wifi.broadcastMessage(msg);
  }

  Future<void> _confirmSendSOS() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm SOS'),
          content: const Text('Send an emergency SOS alert to nearby nodes?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send SOS'),
            ),
          ],
        );
      },
    );

    if (result == true) {
      _sendSOS();
    }
  }

  void _sendSOS() {
    final mesh = context.read<MeshService>();
    final wifi = context.read<WifiDirectService>();
    final msg = mesh.createSOSMessage();
    wifi.broadcastMessage(msg);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SOS alert sent')),
      );
    }
  }

  void _showQuickReplyManager() {
    final mesh = context.read<MeshService>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        final controllers = mesh.quickReplies
            .map((reply) => TextEditingController(text: reply))
            .toList();

        return StatefulBuilder(
          builder: (context, setState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Quick Replies',
                    style: TextStyle(
                      fontFamily: 'Rajdhani',
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...List.generate(controllers.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controllers[index],
                              decoration: InputDecoration(
                                labelText: 'Reply ${index + 1}',
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (value) {
                                mesh.updateQuickReply(index, value);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.redAccent),
                            onPressed: () {
                              mesh.removeQuickReply(index);
                              setState(() {
                                controllers.removeAt(index);
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  }),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Add quick reply'),
                    onPressed: () {
                      mesh.addQuickReply('New quick reply');
                      setState(() {
                        controllers.add(TextEditingController(text: 'New quick reply'));
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Done'),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ─── عرض الأجهزة المتصلة بالشبكة ──────────────
  void _showNetworkDevices() {
    final mesh = context.read<MeshService>();
    final appDevices = mesh.getActiveAppDevices();
    final wifiDevices = mesh.getWifiOnlyDevices();

    mesh.stopNetworkScan();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            color: AppTheme.bgPrimary,
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(ctx).padding.bottom + 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.devices, color: AppTheme.accentCyan),
                        const SizedBox(width: 8),
                        const Text(
                          'Network Devices',
                          style: TextStyle(
                            fontFamily: 'Rajdhani',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        if (mesh.isScanning)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (appDevices.isNotEmpty) ...[
                      const Text(
                        '✅ التطبيق مشغل + Wi-Fi',
                        style: TextStyle(
                          fontFamily: 'Rajdhani',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentGreen,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...appDevices.map((device) {
                        return Card(
                          color: AppTheme.bgSecondary,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  device.hostName ?? device.ipAddress,
                                  style: const TextStyle(
                                    fontFamily: 'Rajdhani',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  device.ipAddress,
                                  style: const TextStyle(
                                    fontFamily: 'SpaceMono',
                                    fontSize: 10,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                      const SizedBox(height: 12),
                    ],

                    if (wifiDevices.isNotEmpty) ...[
                      const Text(
                        '⚠️ Wi-Fi فقط (بدون التطبيق)',
                        style: TextStyle(
                          fontFamily: 'Rajdhani',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.accentYellow,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...wifiDevices.map((device) {
                        return Card(
                          color: AppTheme.bgSecondary.withOpacity(0.5),
                          margin: const EdgeInsets.only(bottom: 8),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  device.hostName ?? device.ipAddress,
                                  style: const TextStyle(
                                    fontFamily: 'Rajdhani',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  device.ipAddress,
                                  style: const TextStyle(
                                    fontFamily: 'SpaceMono',
                                    fontSize: 10,
                                    color: AppTheme.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ],

                    if (appDevices.isEmpty && wifiDevices.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Column(
                          children: [
                            Icon(
                              Icons.cloud_off_outlined,
                              size: 48,
                              color: AppTheme.textMuted,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'لم يتم العثور على أجهزة',
                              style: TextStyle(
                                fontFamily: 'Rajdhani',
                                fontSize: 13,
                                color: AppTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentCyan,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).whenComplete(() {
      mesh.startNetworkScan();
    });
  }

  // ─── إرسال صوت ───────────────────────────────────
  Future<void> _sendVoice(String base64WithEof) async {
    final mesh = context.read<MeshService>();
    final msg = mesh.createVoiceMessage(base64WithEof);
    final wifi = context.read<WifiDirectService>();
    await wifi.broadcastMessage(msg);
  }
}
