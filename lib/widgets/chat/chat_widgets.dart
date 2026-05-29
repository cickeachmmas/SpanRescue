// ═══════════════════════════════════════════════════════
// message_bubble.dart
// ═══════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import '../../core/audio_service.dart';
import '../../core/mesh_service.dart';
import '../../core/wifi_direct_service.dart';
import '../../core/notification_service.dart';
import '../../models/mesh_message.dart';
import '../../theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final MeshMessage message;
  final bool isMe;
  final AudioService audioService;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.audioService,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            _buildAvatar(),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                if (!isMe)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      message.senderId,
                      style: const TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 9,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ),
                GestureDetector(
                  onLongPress: isMe
                      ? () => _showMessageActions(context)
                      : null,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.72,
                    ),
                    padding: message.isVoice
                        ? const EdgeInsets.all(12)
                        : const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isMe
                          ? AppTheme.bubbleMe
                          : AppTheme.bubbleOther,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (message.replyTo != null) _buildReplyPreview(context),
                        message.isVoice
                            ? _buildVoiceContent()
                            : _buildTextContent(),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.dateTime),
                      style: const TextStyle(
                        fontFamily: 'SpaceMono',
                        fontSize: 9,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    if (message.edited) ...[
                      const SizedBox(width: 4),
                      const Text('(edited)', style: TextStyle(fontSize: 8, color: AppTheme.textMuted)),
                    ],
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.location_on,
                      size: 9,
                      color: AppTheme.textMuted,
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.done_all,
                        size: 11,
                        color: AppTheme.accentCyan,
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showMessageActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit'),
                onTap: () async {
                  Navigator.pop(context);
                  final controller = TextEditingController(text: message.content);
                  final result = await showDialog<String>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Edit message'),
                      content: TextField(
                        controller: controller,
                        maxLines: null,
                      ),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Save')),
                      ],
                    ),
                  );

                  if (result != null && result.trim().isNotEmpty) {
                    Provider.of<MeshService>(context, listen: false).editMessage(message.messageId, result.trim());
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: const Text('Delete'),
                onTap: () {
                  Navigator.pop(context);
                  final mesh = Provider.of<MeshService>(context, listen: false);
                  mesh.deleteMessage(message.messageId);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Message deleted'),
                      action: SnackBarAction(
                        label: 'Undo',
                        onPressed: () => mesh.restoreMessage(message.messageId),
                      ),
                      duration: const Duration(seconds: 5),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.clear),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTextContent() {
    if (message.deleted) {
      return Text(
        '🗑️ This message was deleted',
        style: TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 13,
          color: AppTheme.textMuted,
          decoration: TextDecoration.lineThrough,
        ),
      );
    }
    return Text(
      message.content,
      style: const TextStyle(
        fontFamily: 'SpaceMono',
        fontSize: 13,
        color: AppTheme.textPrimary,
        height: 1.4,
      ),
    );
  }

  Widget _buildVoiceContent() {
    return _VoicePlayer(
      message: message,
      audioService: audioService,
    );
  }

  Widget _buildReplyPreview(BuildContext context) {
    final original = Provider.of<MeshService>(context, listen: false)
        .chatMessages
        .firstWhere(
          (m) => m.messageId == message.replyTo,
          orElse: () => MeshMessage(
            messageId: '',
            senderId: '',
            senderGroup: '',
            type: MessageType.chat,
            content: '',
            ttl: 0,
            hopCount: 0,
            seenBy: const [],
            path: const [],
            timestamp: 0,
            location: const GeoLocation(lat: 0.0, lng: 0.0),
            medicalState: MedicalState.none,
            role: NodeRole.rescuer,
            battery: 0,
            triageState: TriageState.none,
          ),
        );

    if (original.messageId.isEmpty) {
      return const SizedBox.shrink();
    }

    final preview = original.content.length > 40
        ? '${original.content.substring(0, 40)}…'
        : original.content;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.bgPrimary.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Reply to ${original.senderId.replaceAll("Node_", "")} – $preview',
        style: const TextStyle(
          fontFamily: 'SpaceMono',
          fontSize: 11,
          color: AppTheme.textMuted,
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final id = message.senderId.replaceAll('Node_', '');
    final num = int.tryParse(id) ?? 0;
    final color = _nodeColor(num);

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

  Color _nodeColor(int id) {
    final colors = [
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
    ];
    return colors[id % colors.length];
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ─── مشغّل الصوت ─────────────────────────────────────
class _VoicePlayer extends StatefulWidget {
  final MeshMessage message;
  final AudioService audioService;

  const _VoicePlayer({
    required this.message,
    required this.audioService,
  });

  @override
  State<_VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<_VoicePlayer> {
  bool _isPlaying = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white24,
            ),
            child: Icon(
              _isPlaying ? Icons.pause : Icons.play_arrow,
              color: Colors.white,
              size: 22,
            ),
          ),
        ),
        const SizedBox(width: 10),
        // Waveform
        Row(
          children: List.generate(18, (i) {
            final height = (i % 3 == 0)
                ? 20.0
                : (i % 2 == 0)
                    ? 12.0
                    : 7.0;
            return Container(
              width: 3,
              height: height,
              margin: const EdgeInsets.symmetric(horizontal: 1),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }),
        ),
      ],
    );
  }

  Future<void> _togglePlay() async {
    setState(() => _isPlaying = true);
    await widget.audioService.playAudioFromBase64(widget.message.content);
    if (mounted) setState(() => _isPlaying = false);
  }
}

// ═══════════════════════════════════════════════════════
// sos_alert_card.dart — بطاقة SOS الحمراء
// ═══════════════════════════════════════════════════════

class SOSAlertCard extends StatelessWidget {
  final MeshMessage message;
  final bool isMe;

  const SOSAlertCard({
    super.key,
    required this.message,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF8B0000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.accentRed.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFF5C0000), width: 1),
              ),
            ),
            child: const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.accentYellow,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'EMERGENCY SOS ALERT',
                  style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accentYellow,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),

          // المحتوى
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Victim: ${message.senderId}',
                  style: const TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 13,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Medical State: ${message.medicalState.name.toUpperCase()}',
                  style: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
                if (!message.location.isGpsDenied) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Location: ${message.location.lat.toStringAsFixed(7)}, '
                    '${message.location.lng.toStringAsFixed(7)}',
                    style: const TextStyle(
                      fontFamily: 'SpaceMono',
                      fontSize: 10,
                      color: AppTheme.accentCyan,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(
                      Icons.circle,
                      color: AppTheme.accentRed,
                      size: 10,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '[EMERGENCY SOS ${isMe ? "SENT" : "RECEIVED"}]\n${message.content}',
                        style: const TextStyle(
                          fontFamily: 'SpaceMono',
                          fontSize: 13,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Replies thread (latest replies referencing this SOS)
                Consumer<MeshService>(
                  builder: (context, mesh, __) {
                    final replies = mesh.chatMessages
                        .where((m) => m.replyTo == message.messageId)
                        .take(5)
                        .toList();

                    if (replies.isEmpty) return const SizedBox.shrink();

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Replies:', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
                        const SizedBox(height: 6),
                        ...replies.map((r) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(child: Text('${r.senderId.replaceAll("Node_", "")} — ${r.content}', style: const TextStyle(color: Colors.white, fontSize: 12),)),
                            ],
                          ),
                        )),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Timestamp
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  _formatTime(message.dateTime),
                  style: const TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 9,
                    color: Colors.white54,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.location_on,
                  size: 9,
                  color: Colors.white54,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

// ═══════════════════════════════════════════════════════
// sos_modal.dart — نافذة SOS المنبثقة
// ═══════════════════════════════════════════════════════

class SOSModal extends StatelessWidget {
  final MeshMessage message;

  const SOSModal({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFFB71C1C),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppTheme.accentRed.withOpacity(0.6),
            width: 2,
          ),
          boxShadow: AppTheme.redGlow,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان
            const Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                SizedBox(width: 10),
                Text(
                  'EMERGENCY (SOS)',
                  style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const Text(
              'A nearby user needs immediate help!',
              style: TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 13,
                color: Colors.white,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'ID: ${message.senderId.replaceAll("Node_", "")}',
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 13,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Message: ${message.content}',
              style: const TextStyle(
                fontFamily: 'SpaceMono',
                fontSize: 13,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(height: 8),

            // Quick replies
            Consumer<MeshService>(
              builder: (context, mesh, __) {
                final replies = mesh.quickReplies.isNotEmpty
                    ? mesh.quickReplies
                    : ['I\'m coming', 'Hold on', 'Need ETA?'];

                return Wrap(
                  spacing: 8,
                  children: replies
                      .map((reply) => _QuickReplyChip(
                            text: reply,
                            messageId: message.messageId,
                          ))
                      .toList(),
                );
              },
            ),

            const SizedBox(height: 12),

            // أزرار الإجراء
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () async {
                    // Stop local SOS vibration/notifications when acknowledging
                    try {
                      final notif = Provider.of<NotificationService>(context, listen: false);
                      await notif.stopSOS();
                    } catch (_) {}
                    Navigator.pop(context);
                  },
                  child: const Text('Acknowledge', style: TextStyle(color: Colors.white)),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentCyan),
                  onPressed: () async {
                    // افتح مربع نص للرد الحر
                    final controller = TextEditingController();
                    final result = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Reply to SOS'),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(hintText: 'Type your reply...'),
                          maxLines: null,
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                          TextButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Send')),
                        ],
                      ),
                    );

                    if (result != null && result.trim().isNotEmpty) {
                      final mesh = Provider.of<MeshService>(context, listen: false);
                      final wifi = Provider.of<WifiDirectService>(context, listen: false);
                      final msg = mesh.createReplyMessage(message.messageId, result.trim());
                      await wifi.broadcastMessage(msg);
                      try {
                        final notif = Provider.of<NotificationService>(context, listen: false);
                        await notif.stopSOS();
                      } catch (_) {}
                      Navigator.pop(context); // close SOS modal
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reply sent')));
                    }
                  },
                  child: const Text('Reply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Quick reply chip widget that sends quick replies
class _QuickReplyChip extends StatelessWidget {
  final String text;
  final String messageId;
  const _QuickReplyChip({required this.text, required this.messageId});

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(text),
      onPressed: () async {
        final mesh = Provider.of<MeshService>(context, listen: false);
        final wifi = Provider.of<WifiDirectService>(context, listen: false);
        final msg = mesh.createReplyMessage(messageId, text);
        await wifi.broadcastMessage(msg);
        try {
          final notif = Provider.of<NotificationService>(context, listen: false);
          await notif.stopSOS();
        } catch (_) {}
        Navigator.pop(context); // close SOS modal after quick reply
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Quick reply sent')));
      },
    );
  }
}

// ═══════════════════════════════════════════════════════
// chat_input_bar.dart — شريط الإرسال
// ═══════════════════════════════════════════════════════

class ChatInputBar extends StatefulWidget {
  final Function(String) onSendText;
  final Function(String) onSendVoice;
  final AudioService audioService;

  const ChatInputBar({
    super.key,
    required this.onSendText,
    required this.onSendVoice,
    required this.audioService,
  });

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  bool _isRecording = false;
  Timer? _typingTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    _typingTimer?.cancel();
    if (_controller.text.trim().isNotEmpty) {
      final mesh = context.read<MeshService>();
      mesh.setTyping(mesh.myNodeId);
      _typingTimer = Timer(const Duration(milliseconds: 500), () {
        setState(() {});
      });
    }
    setState(() {});
  }

  @override
  void dispose() {
    _controller.dispose();
    _typingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: const BoxDecoration(
        color: AppTheme.bgPrimary,
        border: Border(
          top: BorderSide(color: Color(0xFF1A1A1A), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // حقل الكتابة
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.bgSecondary,
                borderRadius: BorderRadius.circular(28),
              ),
              child: TextField(
                controller: _controller,
                style: const TextStyle(
                  fontFamily: 'SpaceMono',
                  fontSize: 13,
                  color: AppTheme.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: 'Message',
                  hintStyle: TextStyle(
                    fontFamily: 'SpaceMono',
                    fontSize: 13,
                    color: AppTheme.textMuted,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
                onSubmitted: _sendText,
              ),
            ),
          ),
          const SizedBox(width: 8),

          // زر الإرسال / الميكروفون
          GestureDetector(
            onTap: _controller.text.trim().isNotEmpty ? _sendCurrentText : null,
            onLongPressStart: (_) => _startRecording(),
            onLongPressEnd: (_) => _stopRecording(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isRecording
                    ? AppTheme.accentRed
                    : const Color(0xFF1565C0),
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording
                            ? AppTheme.accentRed
                            : AppTheme.accentCyan)
                        .withOpacity(0.3),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: Icon(
                _isRecording
                    ? Icons.fiber_manual_record
                    : (_controller.text.trim().isNotEmpty ? Icons.send : Icons.mic),
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _sendText(String text) {
    if (text.trim().isEmpty) return;
    widget.onSendText(text);
    _controller.clear();
  }

  void _sendCurrentText() {
    _sendText(_controller.text);
  }

  Future<void> _startRecording() async {
    final ok = await widget.audioService.startRecording();
    if (ok) {
      setState(() => _isRecording = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recording permission denied or failed')));
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    setState(() => _isRecording = false);
    final base64 = await widget.audioService.stopRecording();
    if (base64 != null) {
      widget.onSendVoice(base64);
    }
  }
}
