import 'dart:convert';
import 'dart:typed_data';
import 'models.dart';

class M3uResult {
  final List<Channel> channels;
  final List<MediaItem> movies;
  final String epgUrl;
  M3uResult(this.channels, this.movies, this.epgUrl);
}

M3uResult parseM3uBytes(Uint8List b) => parseM3u(utf8.decode(b, allowMalformed: true));

bool _isMovieUrl(String url) {
  final l = url.toLowerCase();
  if (l.contains('/movie/')) return true;
  final pathOnly = l.split('?').first;
  return pathOnly.endsWith('.mp4') || pathOnly.endsWith('.mkv') || pathOnly.endsWith('.avi') || pathOnly.endsWith('.mov');
}

M3uResult parseM3u(String text) {
  final out = <Channel>[];
  final movies = <MediaItem>[];
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
      final afterComma = comma >= 0 ? line.substring(comma + 1).trim() : '';
      name = afterComma.isNotEmpty ? afterComma : (a['tvg-name']?.trim() ?? '');
    } else if (line.startsWith('#EXTGRP:')) {
      group = line.substring(8).trim();
    } else if (!line.startsWith('#')) {
      if (name != null) {
        final finalName = name.isNotEmpty ? name : (group?.isNotEmpty == true ? group! : 'Kanal');
        if (_isMovieUrl(line)) {
          movies.add(MediaItem(
            sourceId: '',
            kind: 'movie',
            extId: line,
            name: finalName,
            cat: group ?? '',
            poster: logo ?? '',
            ext: 'direct',
          ));
        } else {
          out.add(Channel(
            name: finalName,
            url: line,
            group: group ?? '',
            logo: logo ?? '',
            epgId: (tvgId ?? '').toLowerCase(),
          ));
        }
      }
      name = logo = group = tvgId = null;
    }
  }
  return M3uResult(out, movies, epgUrl);
}
