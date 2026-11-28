import 'util.dart';

class ChannelVariant {
  final String label;
  final String url;
  final String name;
  const ChannelVariant({required this.label, required this.url, required this.name});
}

class Channel {
  final String sourceId, name, url, group, logo, epgId;
  final String streamId;
  final int catchupDays;
  bool fav;
  String customName;
  String nowTitle = '', nextTitle = '';
  int nowStart = 0, nowStop = 0;
  List<ChannelVariant> variants;

  Channel({
    this.sourceId = '',
    required this.name,
    required this.url,
    this.group = '',
    this.logo = '',
    this.epgId = '',
    this.streamId = '',
    this.catchupDays = 0,
    this.fav = false,
    this.customName = '',
    List<ChannelVariant>? variants,
  }) : variants = variants ?? const [];

  String get displayName => customName.isNotEmpty ? customName : name;
  String get qualityTag => extractQualityTag(name);

  factory Channel.fromRow(Map<String, Object?> r) => Channel(
        sourceId: (r['source_id'] ?? '') as String,
        name: (r['name'] ?? '') as String,
        url: (r['url'] ?? '') as String,
        group: (r['grp'] ?? '') as String,
        logo: (r['logo'] ?? '') as String,
        epgId: (r['epg_id'] ?? '') as String,
        streamId: (r['stream_id'] ?? '') as String,
        catchupDays: (r['catchup_days'] as int?) ?? 0,
        fav: (r['fav'] as int? ?? 0) == 1,
        customName: (r['custom_name'] ?? '') as String,
      );
}

class Programme {
  final int start, stop;
  final String title, desc;
  const Programme(this.start, this.stop, this.title, this.desc);
}

/// Film ya da dizi (Xtream / Jellyfin VOD).
class MediaItem {
  final String sourceId, kind, extId, name, cat, poster, rating, ext; // kind: 'movie' | 'series'
  bool watch;
  MediaItem({
    required this.sourceId,
    required this.kind,
    required this.extId,
    required this.name,
    this.cat = '',
    this.poster = '',
    this.rating = '',
    this.ext = '',
    this.watch = false,
  });

  String get key => '$sourceId|$kind|$extId';

  factory MediaItem.fromRow(Map<String, Object?> r) => MediaItem(
        sourceId: r['source_id'] as String,
        kind: r['kind'] as String,
        extId: r['ext_id'] as String,
        name: (r['name'] ?? '') as String,
        cat: (r['cat'] ?? '') as String,
        poster: (r['poster'] ?? '') as String,
        rating: (r['rating'] ?? '') as String,
        ext: (r['ext'] ?? '') as String,
        watch: (r['watch'] as int? ?? 0) == 1,
      );
}

class Episode {
  final String title, url;
  final int season, number;
  const Episode({required this.title, required this.url, required this.season, required this.number});
}

/// Oynatıcıya verilen öğe: canlı kanal, film, bölüm, kayıt ya da çevrimdışı dosya.
class PlayItem {
  final String title, url, kind, poster, subtitle, userAgent;
  final String _key;
  final bool isLive;
  final List<ChannelVariant> variants;
  final List<Channel> zapList;
  final int zapIndex;

  const PlayItem({
    required this.title,
    required this.url,
    this.isLive = false,
    String key = '',
    this.kind = '',
    this.poster = '',
    this.subtitle = '',
    this.userAgent = kUa,
    this.variants = const [],
    this.zapList = const [],
    this.zapIndex = -1,
  }) : _key = key;

  String get key => _key.isEmpty ? url : _key;
}

class HistoryEntry {
  final String key, kind, title, url, poster;
  final int pos, dur;
  const HistoryEntry(this.key, this.kind, this.title, this.url, this.poster, this.pos, this.dur);
  PlayItem toPlay() => PlayItem(title: title, url: url, key: key, kind: kind, poster: poster);
}

class Profile {
  final String id, name, pin;
  final bool kids;
  const Profile({required this.id, required this.name, this.kids = false, this.pin = ''});
  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'kids': kids, 'pin': pin};
  factory Profile.fromJson(Map<String, dynamic> j) =>
      Profile(id: j['id'], name: j['name'], kids: j['kids'] ?? false, pin: j['pin'] ?? '');
}

/// type: 'm3u' | 'local_m3u' | 'xtream' | 'jellyfin'
class Source {
  final String id, name, type, url, user, pass, epgUrl, userAgent;
  final int refreshHours; // 6, 12, 24
  final int epgOffsetMin; // -180 .. +180

  const Source({
    required this.id,
    required this.name,
    required this.type,
    required this.url,
    this.user = '',
    this.pass = '',
    this.epgUrl = '',
    this.userAgent = '',
    this.refreshHours = 12,
    this.epgOffsetMin = 0,
  });

  String get effectiveUa => userAgent.trim().isEmpty ? kUa : userAgent.trim();

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'url': url,
        'user': user,
        'pass': pass,
        'epgUrl': epgUrl,
        'userAgent': userAgent,
        'refreshHours': refreshHours,
        'epgOffsetMin': epgOffsetMin,
      };

  factory Source.fromJson(Map<String, dynamic> j) => Source(
        id: j['id'],
        name: j['name'],
        type: j['type'],
        url: j['url'],
        user: j['user'] ?? '',
        pass: j['pass'] ?? '',
        epgUrl: j['epgUrl'] ?? '',
        userAgent: j['userAgent'] ?? '',
        refreshHours: (j['refreshHours'] as int?) ?? 12,
        epgOffsetMin: (j['epgOffsetMin'] as int?) ?? 0,
      );
}

class CustomGroup {
  final String id, name;
  final int count;
  const CustomGroup({required this.id, required this.name, this.count = 0});
}

class ReminderItem {
  final int id;
  final String channelName, channelUrl, title;
  final int start, stop;
  const ReminderItem({
    required this.id,
    required this.channelName,
    required this.channelUrl,
    required this.title,
    required this.start,
    required this.stop,
  });
}

class DownloadItem {
  final String key, title, poster, filePath;
  final int sizeBytes, created;
  const DownloadItem({
    required this.key,
    required this.title,
    required this.poster,
    required this.filePath,
    required this.sizeBytes,
    required this.created,
  });
}

class RecordingItem {
  final String id, channelName, title, filePath;
  final int started, durationSec, sizeBytes;
  const RecordingItem({
    required this.id,
    required this.channelName,
    required this.title,
    required this.filePath,
    required this.started,
    required this.durationSec,
    required this.sizeBytes,
  });
}

class SavedMultiviewLayout {
  final String id, name, preset; // preset: '2' | '4' | '1+3' | '6' | '9'
  final List<String> urls;
  final List<String> names;
  const SavedMultiviewLayout({
    required this.id,
    required this.name,
    required this.preset,
    required this.urls,
    required this.names,
  });
}

class TmdbInfo {
  final String overview, genres, releaseDate, rating, backdropUrl;
  const TmdbInfo({
    this.overview = '',
    this.genres = '',
    this.releaseDate = '',
    this.rating = '',
    this.backdropUrl = '',
  });
}
