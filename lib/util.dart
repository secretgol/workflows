const kUa = 'OpenIPTV/1.0';

const _from = 'àáâãäåçèéêëìíîïñòóôõöøùúûüýÿğışčšž';
const _to = 'aaaaaa' 'c' 'eeee' 'iiii' 'n' 'oooooo' 'uuuu' 'yy' 'gis' 'csz';

String normalizeUrl(String raw) {
  final u = raw.trim();
  if (u.isEmpty) return '';
  if (u.startsWith('http://') || u.startsWith('https://')) return u;
  return 'http://$u';
}

/// Kanal adlarını eşleştirmek için sadeleştirir: ülke kodu, kalite etiketi, aksan ve noktalama gider.
String normName(String s) {
  final b = StringBuffer();
  for (final r in s.toLowerCase().runes) {
    final ch = String.fromCharCode(r);
    final i = _from.indexOf(ch);
    b.write(i >= 0 ? _to[i] : ch);
  }
  var x = b.toString();
  x = x.replaceFirst(RegExp(r'^\s*[\[\(\|]\s*[a-z]{2,3}\s*[\]\)\|]\s*'), '');
  x = x.replaceFirst(RegExp(r'^\s*[a-z]{2,3}\s*[:|\-]\s*'), '');
  x = x.replaceAll(RegExp(r'\(vod\)'), '');
  x = x.replaceAll(
    RegExp(r'\b(uhd|4k|2160p|fhd|1080p|hd|720p|sd|hevc|h265|h264|raw|vip|backup|50fps|60fps)\b'),
    '',
  );
  return x.replaceAll(RegExp(r'[^a-z0-9]'), '');
}

/// Kanal adından kalite etiketi çıkarır (4K, UHD, FHD, HD, HEVC, RAW, SD).
String extractQualityTag(String name) {
  final u = name.toUpperCase();
  if (RegExp(r'\b(4K|UHD|2160P)\b').hasMatch(u)) return '4K';
  if (RegExp(r'\b(RAW)\b').hasMatch(u)) return 'RAW';
  if (RegExp(r'\b(FHD|1080P)\b').hasMatch(u)) return 'FHD';
  if (RegExp(r'\b(HEVC|H265)\b').hasMatch(u)) return 'HEVC';
  if (RegExp(r'\b(HD|720P)\b').hasMatch(u)) return 'HD';
  if (RegExp(r'\b(SD)\b').hasMatch(u)) return 'SD';
  return '';
}

int qualityRank(String tag) => switch (tag) {
      '4K' => 6,
      'RAW' => 5,
      'FHD' => 4,
      'HEVC' => 3,
      'HD' => 2,
      'SD' => 1,
      _ => 0,
    };

/// XMLTV zamanı ("20261128183000 +0100") -> unix saniye
int? parseXmltvTime(String? s) {
  if (s == null || s.length < 14) return null;
  final y = int.tryParse(s.substring(0, 4)), mo = int.tryParse(s.substring(4, 6));
  final d = int.tryParse(s.substring(6, 8)), h = int.tryParse(s.substring(8, 10));
  final mi = int.tryParse(s.substring(10, 12)), se = int.tryParse(s.substring(12, 14));
  if (y == null || mo == null || d == null || h == null || mi == null || se == null) return null;
  var t = DateTime.utc(y, mo, d, h, mi, se).millisecondsSinceEpoch ~/ 1000;
  final m = RegExp(r'([+-])(\d{2})(\d{2})').firstMatch(s.substring(14));
  if (m != null) {
    final off = (int.parse(m[2]!) * 3600 + int.parse(m[3]!) * 60) * (m[1] == '-' ? -1 : 1);
    t -= off;
  }
  return t;
}

String hm(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

const _days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

String dayLabel(int ts) {
  final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(d.year, d.month, d.day);
  final diff = target.difference(today).inDays;
  if (diff == 0) return 'Bugün';
  if (diff == 1) return 'Yarın';
  if (diff == -1) return 'Dün';
  return '${_days[d.weekday - 1]} ${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
}

String formatDuration(int seconds) {
  if (seconds <= 0) return '0:00';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  final s = seconds % 60;
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  return '$m:${s.toString().padLeft(2, '0')}';
}

String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
}
