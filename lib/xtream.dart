import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'models.dart';

String _base(Source s) => s.url.replaceAll(RegExp(r'/+$'), '');
String _api(Source s) =>
    '${_base(s)}/player_api.php?username=${Uri.encodeComponent(s.user)}&password=${Uri.encodeComponent(s.pass)}';
const _t = Duration(seconds: 90);

Map<String, String> _headers(Source s) => {'User-Agent': s.effectiveUa};

String xtreamEpgUrl(Source s) =>
    '${_base(s)}/xmltv.php?username=${Uri.encodeComponent(s.user)}&password=${Uri.encodeComponent(s.pass)}';

/// Xtream Catch-up (Timeshift) URL oluşturucu
String? xtreamCatchupUrl(Source s, Channel c, Programme p) {
  if (s.type != 'xtream' || c.streamId.isEmpty) return null;
  final d = DateTime.fromMillisecondsSinceEpoch(p.start * 1000).toUtc();
  final durMin = ((p.stop - p.start) / 60).ceil().clamp(1, 360);
  final startStr = '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}:${d.hour.toString().padLeft(2, '0')}-${d.minute.toString().padLeft(2, '0')}';
  return '${_base(s)}/timeshift/${Uri.encodeComponent(s.user)}/${Uri.encodeComponent(s.pass)}/'
      '$durMin/$startStr/${c.streamId}.ts';
}

List<dynamic> _decodeList(Uint8List b) {
  final v = jsonDecode(utf8.decode(b, allowMalformed: true));
  return v is List ? v : <dynamic>[];
}

Future<List<dynamic>> _getList(String url, Source s) async {
  final r = await http.get(Uri.parse(url), headers: _headers(s)).timeout(_t);
  if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('HTTP ${r.statusCode}');
  return compute(_decodeList, r.bodyBytes);
}

Future<List<Channel>> loadXtream(Source s) async {
  final base = _base(s);
  final user = Uri.encodeComponent(s.user);
  final pass = Uri.encodeComponent(s.pass);
  final cats = await _getList('${_api(s)}&action=get_live_categories', s);
  final names = {for (final c in cats) if (c is Map) '${c['category_id']}': '${c['category_name']}'};
  final streams = await _getList('${_api(s)}&action=get_live_streams', s);
  return [
    for (final x in streams)
      if (x is Map)
        Channel(
          sourceId: s.id,
          name: '${x['name'] ?? ''}',
          url: '$base/live/$user/$pass/${x['stream_id']}.m3u8',
          group: names['${x['category_id']}'] ?? '',
          logo: '${x['stream_icon'] ?? ''}',
          epgId: ('${x['epg_channel_id'] ?? ''}').toLowerCase(),
          streamId: '${x['stream_id'] ?? ''}',
          catchupDays: int.tryParse('${x['tv_archive_duration'] ?? 0}') ?? 0,
        )
  ];
}

/// kind: 'movie' | 'series'
Future<List<MediaItem>> loadXtreamItems(Source s, String kind) async {
  final movie = kind == 'movie';
  final cats = await _getList('${_api(s)}&action=${movie ? 'get_vod_categories' : 'get_series_categories'}', s);
  final names = {for (final c in cats) if (c is Map) '${c['category_id']}': '${c['category_name']}'};
  final list = await _getList('${_api(s)}&action=${movie ? 'get_vod_streams' : 'get_series'}', s);
  return [
    for (final x in list)
      if (x is Map)
        MediaItem(
          sourceId: s.id,
          kind: kind,
          extId: '${movie ? x['stream_id'] : x['series_id']}',
          name: '${x['name'] ?? ''}',
          cat: names['${x['category_id']}'] ?? '',
          poster: '${(movie ? x['stream_icon'] : x['cover']) ?? ''}',
          rating: '${x['rating'] ?? ''}',
          ext: movie
              ? ('${x['container_extension'] ?? ''}'.trim().isEmpty ? 'mp4' : '${x['container_extension']}'.trim())
              : '',
        )
  ];
}

String movieUrl(Source s, MediaItem m) {
  if (s.type == 'jellyfin') {
    return '${_base(s)}/Videos/${m.extId}/stream?static=true&api_key=${Uri.encodeComponent(s.pass)}';
  }
  final ext = m.ext.trim().isEmpty ? 'mp4' : m.ext.trim();
  return '${_base(s)}/movie/${Uri.encodeComponent(s.user)}/${Uri.encodeComponent(s.pass)}/${m.extId}.$ext';
}

Future<Map<int, List<Episode>>> fetchEpisodes(Source s, MediaItem series) async {
  if (s.type == 'jellyfin') return _fetchJellyfinEpisodes(s, series);
  final r = await http
      .get(Uri.parse('${_api(s)}&action=get_series_info&series_id=${series.extId}'), headers: _headers(s))
      .timeout(_t);
  if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('HTTP ${r.statusCode}');
  final j = jsonDecode(utf8.decode(r.bodyBytes, allowMalformed: true));
  final eps = j is Map ? j['episodes'] : null;
  final out = <int, List<Episode>>{};
  final user = Uri.encodeComponent(s.user);
  final pass = Uri.encodeComponent(s.pass);

  void add(int season, dynamic e) {
    if (e is! Map) return;
    final rawExt = '${e['container_extension'] ?? ''}'.trim();
    final ext = rawExt.isEmpty ? 'mp4' : rawExt;
    final n = int.tryParse('${e['episode_num']}') ?? 0;
    out.putIfAbsent(season, () => []).add(Episode(
          title: '${e['title'] ?? 'Bölüm $n'}',
          url: '${_base(s)}/series/$user/$pass/${e['id']}.$ext',
          season: season,
          number: n,
        ));
  }

  if (eps is Map) {
    eps.forEach((k, v) {
      final sn = int.tryParse('$k') ?? 0;
      if (v is List) {
        for (final e in v) {
          add(sn, e);
        }
      }
    });
  } else if (eps is List) {
    for (var i = 0; i < eps.length; i++) {
      final v = eps[i];
      if (v is List) {
        for (final e in v) {
          add(i + 1, e);
        }
      }
    }
  }
  return out;
}

// ---------- Jellyfin / Emby desteği (API Key ile) ----------
Future<List<Channel>> loadJellyfinChannels(Source s) async {
  final base = _base(s);
  final key = Uri.encodeComponent(s.pass);
  final r = await http.get(Uri.parse('$base/LiveTv/Channels?api_key=$key'), headers: _headers(s)).timeout(_t);
  if (r.statusCode < 200 || r.statusCode >= 300) return [];
  final j = jsonDecode(utf8.decode(r.bodyBytes, allowMalformed: true));
  final list = (j is Map && j['Items'] is List) ? j['Items'] as List : const [];
  return [
    for (final x in list)
      if (x is Map)
        Channel(
          sourceId: s.id,
          name: '${x['Name'] ?? ''}',
          url: '$base/Videos/${x['Id']}/stream?static=true&api_key=$key',
          group: 'Jellyfin Canlı TV',
          logo: '$base/Items/${x['Id']}/Images/Primary?api_key=$key',
          epgId: '${x['Id'] ?? ''}'.toLowerCase(),
        )
  ];
}

Future<List<MediaItem>> loadJellyfinItems(Source s, String kind) async {
  final base = _base(s);
  final key = Uri.encodeComponent(s.pass);
  final type = kind == 'movie' ? 'Movie' : 'Series';
  final r = await http
      .get(Uri.parse('$base/Items?IncludeItemTypes=$type&Recursive=true&Fields=Genres&api_key=$key'), headers: _headers(s))
      .timeout(_t);
  if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('HTTP ${r.statusCode}');
  final j = jsonDecode(utf8.decode(r.bodyBytes, allowMalformed: true));
  final list = (j is Map && j['Items'] is List) ? j['Items'] as List : const [];
  return [
    for (final x in list)
      if (x is Map)
        MediaItem(
          sourceId: s.id,
          kind: kind,
          extId: '${x['Id'] ?? ''}',
          name: '${x['Name'] ?? ''}',
          cat: (x['Genres'] is List && (x['Genres'] as List).isNotEmpty) ? '${(x['Genres'] as List).first}' : 'Jellyfin',
          poster: '$base/Items/${x['Id']}/Images/Primary?maxWidth=400&api_key=$key',
          rating: x['CommunityRating'] != null ? (x['CommunityRating'] as num).toStringAsFixed(1) : '',
        )
  ];
}

Future<Map<int, List<Episode>>> _fetchJellyfinEpisodes(Source s, MediaItem series) async {
  final base = _base(s);
  final key = Uri.encodeComponent(s.pass);
  final r = await http
      .get(Uri.parse('$base/Shows/${series.extId}/Episodes?api_key=$key'), headers: _headers(s))
      .timeout(_t);
  if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('HTTP ${r.statusCode}');
  final j = jsonDecode(utf8.decode(r.bodyBytes, allowMalformed: true));
  final list = (j is Map && j['Items'] is List) ? j['Items'] as List : const [];
  final out = <int, List<Episode>>{};
  for (final x in list) {
    if (x is! Map) continue;
    final sn = (x['ParentIndexNumber'] as int?) ?? 1;
    final ep = (x['IndexNumber'] as int?) ?? 0;
    out.putIfAbsent(sn, () => []).add(Episode(
          title: '${x['Name'] ?? 'Bölüm $ep'}',
          url: '$base/Videos/${x['Id']}/stream?static=true&api_key=$key',
          season: sn,
          number: ep,
        ));
  }
  return out;
}

// ---------- Opsiyonel TMDB metadata zenginleştirme ----------
Future<TmdbInfo?> fetchTmdbInfo(String apiKey, String title, String kind) async {
  if (apiKey.trim().isEmpty) return null;
  final cleanTitle = title.replaceAll(RegExp(r'\(\d{4}\)|\[.*?\]'), '').trim();
  final type = kind == 'series' ? 'tv' : 'movie';
  final uri = Uri.parse(
      'https://api.themoviedb.org/3/search/$type?api_key=${Uri.encodeComponent(apiKey.trim())}&language=tr-TR&query=${Uri.encodeComponent(cleanTitle)}');
  try {
    final r = await http.get(uri).timeout(const Duration(seconds: 12));
    if (r.statusCode != 200) return null;
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    final results = j['results'];
    if (results is! List || results.isEmpty) return null;
    final first = results.first as Map;
    final backdrop = first['backdrop_path'] != null ? 'https://image.tmdb.org/t/p/w780${first['backdrop_path']}' : '';
    final rating = first['vote_average'] != null ? (first['vote_average'] as num).toStringAsFixed(1) : '';
    return TmdbInfo(
      overview: '${first['overview'] ?? ''}',
      releaseDate: '${first['release_date'] ?? first['first_air_date'] ?? ''}',
      rating: rating,
      backdropUrl: backdrop,
    );
  } catch (_) {
    return null;
  }
}
