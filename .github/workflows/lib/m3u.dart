import 'dart:convert';
import 'dart:typed_data';
import 'models.dart';

class M3uResult {
  final List<Channel> channels;
  final String epgUrl;
  M3uResult(this.channels, this.epgUrl);
}

M3uResult parseM3uBytes(Uint8List b) => parseM3u(utf8.decode(b, allowMalformed: true));

M3uResult parseM3u(String text) {
  final out = <Channel>[];
  String epgUrl = '';
  String? name, logo, group, tvgId;
  final attr = RegExp(r'([\w-]+)="([^"]*)"');
  for (final raw in text.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    if (line.startsWith('#EXTM3U')) {
      final a = {for (final m in attr.allMatches(line)) m.group(1)!.toLowerCase(): m.group(2)!};
      epgUrl = (a['url-tvg'] ?? a['x-tvg-url'] ?? a['tvg-url'] ?? '').split(',').first.trim();
    } else if (line.startsWith('#EXTINF')) {
      final a = {for (final m in attr.allMatches(line)) m.group(1)!.toLowerCase(): m.group(2)!};
      logo = a['tvg-logo'];
      group = a['group-title'];
      tvgId = a['tvg-id'];
      final comma = line.lastIndexOf(',');
      name = comma >= 0 ? line.substring(comma + 1).trim() : a['tvg-name'];
    } else if (line.startsWith('#EXTGRP:')) {
      group = line.substring(8).trim();
    } else if (!line.startsWith('#')) {
      if (name != null) {
        out.add(Channel(
            name: name, url: line, group: group ?? '', logo: logo ?? '', epgId: (tvgId ?? '').toLowerCase()));
      }
      name = logo = group = tvgId = null;
    }
  }
  return M3uResult(out, epgUrl);
}
