import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/material.dart';
import '../p2p_helper.dart';

class DevToolsScreen extends StatefulWidget {
  const DevToolsScreen({super.key});
  @override
  State<DevToolsScreen> createState() => _DevToolsScreenState();
}

class _DevToolsScreenState extends State<DevToolsScreen> {
  String _info = '';

  Future<void> _getP2p() async {
    final info = await P2pHelper.getP2pInfo();
    setState(() {
      if (info == null) _info = 'no info';
      else _info = 'groupFormed=${info.groupFormed} isGO=${info.isGroupOwner} GO=${info.groupOwnerAddress} local=${info.localIp}';
    });
  }

  Future<void> _sendTest() async {
    final payload = Uint8List.fromList('{"type":"APP_BEACON","nodeId":"DEV_TEST"}'.codeUnits);
    await P2pHelper.sendPayload(payload);
    setState(() { _info = 'test sent'; });
  }

  Future<void> _scanInterfaces() async {
    try {
      final ifaces = await NetworkInterface.list(type: InternetAddressType.IPv4);
      final parts = <String>[];
      for (final ni in ifaces) {
        final addrs = ni.addresses.map((a) => a.address).join(',');
        parts.add('${ni.name}: $addrs');
      }
      setState(() { _info = parts.join('\n'); });
    } catch (e) {
      setState(() { _info = 'scan error: $e'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('Dev Tools')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(onPressed: _getP2p, child: const Text('Get P2P Info')),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _sendTest, child: const Text('Send Test Beacon')),
            const SizedBox(height: 8),
            ElevatedButton(onPressed: _scanInterfaces, child: const Text('Scan Interfaces')),
            const SizedBox(height: 20),
            Text(_info, style: const TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
