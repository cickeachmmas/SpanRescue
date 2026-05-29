import 'dart:async';
import 'dart:isolate';
import 'dart:convert';
import 'dart:io' show Platform;

/// A small fixed-size isolate pool to run CPU-bound tasks without
/// repeatedly spawning short-lived isolates. Supports two operations:
/// - 'jsonBatch' -> List<Map<String,dynamic>> from List<String>
/// - 'base64Batch' -> List<List<int>> from List<String>
class IsolatePool {
  static IsolatePool? _instance;
  static IsolatePool get instance => _instance ??= IsolatePool._create();

  final int _size;
  final List<SendPort?> _ports = [];
  int _next = 0;

  IsolatePool._create({int? size}) : _size = size ?? (Platform.numberOfProcessors > 2 ? Platform.numberOfProcessors - 1 : 1) {
    for (var i = 0; i < _size; i++) {
      _ports.add(null);
      _spawnWorker(i);
    }
  }

  void _spawnWorker(int idx) async {
    final receive = ReceivePort();
    await Isolate.spawn(_isolateEntry, receive.sendPort);
    final port = await receive.first as SendPort;
    _ports[idx] = port;
  }

  Future<dynamic> run(String op, dynamic payload, {Duration? timeout}) {
    final completer = Completer<dynamic>();
    final id = DateTime.now().microsecondsSinceEpoch.toString() + '_' + (_next++).toString();
    final rp = ReceivePort();
    final workerPort = _ports[_next % _ports.length];
    _next = _next % _ports.length;
    if (workerPort == null) {
      completer.completeError('Isolate worker not ready');
      return completer.future;
    }

    final msg = {
      'id': id,
      'op': op,
      'payload': payload,
      'reply': rp.sendPort,
    };

    StreamSubscription? sub;
    sub = rp.listen((dynamic r) {
      try {
        if (r is Map && r['id'] == id) {
          sub?.cancel();
          rp.close();
          if (r['error'] != null) {
            completer.completeError(r['error']);
          } else {
            completer.complete(r['result']);
          }
        }
      } catch (e) {
        sub?.cancel();
        rp.close();
        completer.completeError(e);
      }
    });

    try {
      workerPort.send(msg);
    } catch (e) {
      sub.cancel();
      rp.close();
      completer.completeError(e);
    }

    if (timeout != null) {
      return completer.future.timeout(timeout);
    }
    return completer.future;
  }
}

// Top-level isolate entry
void _isolateEntry(SendPort initialReply) {
  final port = ReceivePort();
  initialReply.send(port.sendPort);

  port.listen((dynamic message) {
    // message: {id, op, payload, reply}
    final Map m = message as Map;
    final id = m['id'] as String;
    final op = m['op'] as String;
    final payload = m['payload'];
    final SendPort reply = m['reply'] as SendPort;

    try {
      if (op == 'jsonBatch') {
        final List<String> raws = List<String>.from(payload as List);
        final result = <Map<String, dynamic>>[];
        for (final r in raws) {
          try {
            result.add(jsonDecode(r) as Map<String, dynamic>);
          } catch (_) {
            result.add(<String, dynamic>{});
          }
        }
        reply.send({'id': id, 'result': result});
      } else if (op == 'base64Batch') {
        final List<String> raws = List<String>.from(payload as List);
        final result = <List<int>>[];
        for (final r in raws) {
          try {
            result.add(base64Decode(r));
          } catch (_) {
            result.add(<int>[]);
          }
        }
        reply.send({'id': id, 'result': result});
      } else {
        reply.send({'id': id, 'error': 'unknown-op'});
      }
    } catch (e) {
      reply.send({'id': id, 'error': e.toString()});
    }
  });
}
