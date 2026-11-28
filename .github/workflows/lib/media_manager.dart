import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'db.dart';
import 'models.dart';
import 'util.dart';

class ActiveDownload {
  final String key, title;
  int receivedBytes = 0;
  int totalBytes = 0;
  bool cancelled = false;
  http.Client? _client;

  ActiveDownload({required this.key, required this.title});
  double? get progress => totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : null;

  void cancel() {
    cancelled = true;
    _client?.close();
  }
}

class ActiveRecording {
  final String id, channelName, title, filePath;
  final int startedEpoch;
  int bytesWritten = 0;
  bool stopped = false;
  http.Client? _client;

  ActiveRecording({
    required this.id,
    required this.channelName,
    required this.title,
    required this.filePath,
    required this.startedEpoch,
  });

  int get elapsedSec => (DateTime.now().millisecondsSinceEpoch ~/ 1000) - startedEpoch;

  void stop() {
    stopped = true;
    _client?.close();
  }
}

/// Çevrimdışı VOD indirme ve Canlı TV DVR kayıt yöneticisi.
class MediaManager extends ChangeNotifier {
  final Map<String, ActiveDownload> activeDownloads = {};
  final Map<String, ActiveRecording> activeRecordings = {};
  String? lastMessage;

  Future<Directory> _mediaDir(String sub) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'OpenIPTV', sub));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  String _safeFile(String name) => name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_').replaceAll(RegExp(r'_+'), '_');

  Future<void> startDownload(PlayItem item) async {
    if (activeDownloads.containsKey(item.key)) return;
    final task = ActiveDownload(key: item.key, title: item.title);
    activeDownloads[item.key] = task;
    notifyListeners();

    final client = http.Client();
    task._client = client;
    IOSink? sink;
    File? file;
    try {
      final dir = await _mediaDir('Downloads');
      final ext = p.extension(Uri.parse(item.url).path).replaceAll(RegExp(r'[^A-Za-z0-9.]'), '');
      final finalExt = ext.isEmpty || ext.length > 5 ? '.mp4' : ext;
      file = File(p.join(dir.path, '${_safeFile(item.title)}_${DateTime.now().millisecondsSinceEpoch}$finalExt'));

      final req = http.Request('GET', Uri.parse(item.url));
      req.headers['User-Agent'] = item.userAgent;
      final resp = await client.send(req);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      task.totalBytes = resp.contentLength ?? 0;
      sink = file.openWrite();
      var lastNotify = DateTime.now();

      await for (final chunk in resp.stream) {
        if (task.cancelled) break;
        sink.add(chunk);
        task.receivedBytes += chunk.length;
        final now = DateTime.now();
        if (now.difference(lastNotify).inMilliseconds > 350) {
          lastNotify = now;
          notifyListeners();
        }
      }
      await sink.close();
      sink = null;

      if (task.cancelled) {
        if (await file.exists()) await file.delete();
      } else {
        await Db.saveDownload(DownloadItem(
          key: item.key,
          title: item.title,
          poster: item.poster,
          filePath: file.path,
          sizeBytes: task.receivedBytes,
          created: DateTime.now().millisecondsSinceEpoch,
        ));
        lastMessage = 'İndirme tamamlandı: ${item.title}';
      }
    } catch (e) {
      await sink?.close();
      if (file != null && await file.exists()) await file.delete();
      if (!task.cancelled) lastMessage = 'İndirme hatası: $e';
    } finally {
      client.close();
      activeDownloads.remove(item.key);
      notifyListeners();
    }
  }

  Future<String?> startRecording({
    required String channelName,
    required String url,
    String title = '',
    String userAgent = kUa,
  }) async {
    final id = 'rec_${DateTime.now().millisecondsSinceEpoch}';
    final dir = await _mediaDir('Recordings');
    final recTitle = title.isNotEmpty ? title : channelName;
    final filePath = p.join(dir.path, '${_safeFile(recTitle)}_${DateTime.now().millisecondsSinceEpoch}.ts');
    final started = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final rec = ActiveRecording(
      id: id,
      channelName: channelName,
      title: recTitle,
      filePath: filePath,
      startedEpoch: started,
    );
    activeRecordings[id] = rec;
    notifyListeners();

    unawaited(_recordLoop(rec, url, userAgent));
    return id;
  }

  Future<void> _recordLoop(ActiveRecording rec, String url, String userAgent) async {
    final client = http.Client();
    rec._client = client;
    final file = File(rec.filePath);
    IOSink? sink;
    try {
      final req = http.Request('GET', Uri.parse(url));
      req.headers['User-Agent'] = userAgent;
      final resp = await client.send(req);
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      sink = file.openWrite();
      var lastNotify = DateTime.now();
      await for (final chunk in resp.stream) {
        if (rec.stopped) break;
        sink.add(chunk);
        rec.bytesWritten += chunk.length;
        final now = DateTime.now();
        if (now.difference(lastNotify).inMilliseconds > 500) {
          lastNotify = now;
          notifyListeners();
        }
      }
    } catch (_) {
      // Kullanıcı durdurduğunda client.close() beklenen bir hata fırlatabilir
    } finally {
      await sink?.close();
      client.close();
      activeRecordings.remove(rec.id);
      if (rec.bytesWritten > 0) {
        await Db.saveRecording(RecordingItem(
          id: rec.id,
          channelName: rec.channelName,
          title: rec.title,
          filePath: rec.filePath,
          started: rec.startedEpoch,
          durationSec: rec.elapsedSec,
          sizeBytes: rec.bytesWritten,
        ));
        lastMessage = 'Kayıt kaydedildi: ${rec.title} (${formatBytes(rec.bytesWritten)})';
      } else if (await file.exists()) {
        await file.delete();
      }
      notifyListeners();
    }
  }

  void stopRecording(String id) {
    activeRecordings[id]?.stop();
  }

  bool isRecordingChannel(String channelName) =>
      activeRecordings.values.any((r) => r.channelName == channelName);

  void stopRecordingForChannel(String channelName) {
    for (final r in activeRecordings.values.where((r) => r.channelName == channelName).toList()) {
      r.stop();
    }
  }
}
