import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class P2pInfo {
  final bool groupFormed;
  final bool isGroupOwner;
  final String? groupOwnerAddress;
  final String? localIp;

  P2pInfo({required this.groupFormed, required this.isGroupOwner, this.groupOwnerAddress, this.localIp});

  factory P2pInfo.fromMap(Map m) => P2pInfo(
        groupFormed: m['groupFormed'] == true,
        isGroupOwner: m['isGroupOwner'] == true,
        groupOwnerAddress: m['groupOwnerAddress'],
        localIp: m['localIp'],
      );
}

class P2pHelper {
  static const MethodChannel _channel = MethodChannel('com.spanrescue.tactical/p2p');

  /// Request P2P info from Android native side
  static Future<P2pInfo?> getP2pInfo() async {
    try {
      final res = await _channel.invokeMethod('getP2pInfo');
      if (res is Map) {
        return P2pInfo.fromMap(Map<String, dynamic>.from(res));
      }
    } catch (e) {
      // ignore
    }
    return null;
  }

  static InternetAddress _broadcastFromIp(String ip) {
    // Quick heuristic: if 192.168.x.x use .255
    final parts = ip.split('.');
    if (parts.length == 4) {
      return InternetAddress('${parts[0]}.${parts[1]}.${parts[2]}.255');
    }
    return InternetAddress('255.255.255.255');
  }

  /// Bind UDP socket ready for send/receive on IPv4
  static Future<RawDatagramSocket> bindUdp({int port = 44444}) async {
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, port);
    socket.broadcastEnabled = true;
    return socket;
  }

  /// Send payload either to groupOwnerAddress (preferred) or to broadcast address
  static Future<void> sendPayload(Uint8List payload, {int port = 44444}) async {
    final info = await getP2pInfo();
    if (info != null) {
      final socket = await bindUdp(port: 0);
      try {
        if (info.groupOwnerAddress != null && info.groupOwnerAddress!.isNotEmpty) {
          socket.send(payload, InternetAddress(info.groupOwnerAddress!), port);
        } else if (info.localIp != null) {
          final b = _broadcastFromIp(info.localIp!);
          socket.send(payload, b, port);
        } else {
          // fallback
          socket.send(payload, InternetAddress('255.255.255.255'), port);
        }
      } finally {
        socket.close();
      }
    } else {
      // no p2p info -> broadcast
      final socket = await bindUdp(port: 0);
      try {
        socket.send(payload, InternetAddress('255.255.255.255'), port);
      } finally {
        socket.close();
      }
    }
  }

  /// Simple listener helper
  static Future<void> startListener(void Function(String from, Uint8List data) onDatagram, {int port = 44444}) async {
    final socket = await bindUdp(port: port);
    socket.listen((event) {
      if (event == RawSocketEvent.read) {
        final dg = socket.receive();
        if (dg != null) {
          onDatagram(dg.address.address, dg.data);
        }
      }
    });
  }
}
