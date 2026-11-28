import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'models.dart';
import 'util.dart';

String _pf(String profile) => profile.replaceAll(RegExp(r'[^A-Za-z0-9_]'), '');

String kidsClause(String col) =>
    ' AND ${['xxx', 'adult', 'porn', '18+', 'erotic', 'sex'].map((k) => "$col NOT LIKE '%$k%'").join(' AND ')}';

class Db {
  static const pageSize = 60;
  static Database? _d;
  static Future<Database> get db async => _d ??= await _open();

  static Future<Database> _open() async {
    final desktop = Platform.isWindows || Platform.isLinux;
    final dir = desktop ? (await getApplicationSupportDirectory()).path : await getDatabasesPath();
    return openDatabase(
      p.join(dir, 'open_iptv.db'),
      version: 3,
      onCreate: (d, v) async {
        await d.execute('CREATE TABLE channels(id INTEGER PRIMARY KEY, source_id TEXT NOT NULL, name TEXT, '
            'name_norm TEXT, url TEXT, grp TEXT, logo TEXT, epg_id TEXT, stream_id TEXT, catchup_days INTEGER DEFAULT 0)');
        await d.execute('CREATE INDEX ch_src_grp ON channels(source_id, grp)');
        await d.execute('CREATE INDEX ch_src_norm ON channels(source_id, name_norm)');
        await d.execute('CREATE TABLE programmes(src TEXT, chan TEXT, start INTEGER, stop INTEGER, title TEXT, descr TEXT)');
        await d.execute('CREATE INDEX pr_idx ON programmes(src, chan, start)');
        await d.execute('CREATE TABLE epg_channels(src TEXT, chan TEXT, name_norm TEXT)');
        await d.execute('CREATE INDEX ec_chan ON epg_channels(src, chan)');
        await d.execute('CREATE INDEX ec_norm ON epg_channels(src, name_norm)');
        await _v2(d);
        await _v3(d);
      },
      onUpgrade: (d, oldV, newV) async {
        if (oldV < 2) {
          await d.execute('DROP TABLE IF EXISTS favorites');
          await _v2(d);
        }
        if (oldV < 3) {
          try {
            await d.execute('ALTER TABLE channels ADD COLUMN stream_id TEXT');
          } catch (_) {}
          try {
            await d.execute('ALTER TABLE channels ADD COLUMN catchup_days INTEGER DEFAULT 0');
          } catch (_) {}
          await _v3(d);
        }
      },
    );
  }

  static Future<void> _v2(Database d) async {
    await d.execute('CREATE TABLE favorites(profile TEXT, url TEXT, PRIMARY KEY(profile, url))');
    await d.execute('CREATE TABLE items(id INTEGER PRIMARY KEY, source_id TEXT NOT NULL, kind TEXT, ext_id TEXT, '
        'key TEXT, name TEXT, name_norm TEXT, cat TEXT, poster TEXT, rating TEXT, ext TEXT)');
    await d.execute('CREATE INDEX it_cat ON items(source_id, kind, cat)');
    await d.execute('CREATE INDEX it_norm ON items(source_id, kind, name_norm)');
    await d.execute('CREATE TABLE watchlist(profile TEXT, key TEXT, PRIMARY KEY(profile, key))');
    await d.execute('CREATE TABLE history(profile TEXT, key TEXT, kind TEXT, title TEXT, url TEXT, poster TEXT, '
        'pos INTEGER, dur INTEGER, updated INTEGER, PRIMARY KEY(profile, key))');
  }

  static Future<void> _v3(Database d) async {
    await d.execute('CREATE TABLE IF NOT EXISTS custom_groups(id TEXT PRIMARY KEY, profile TEXT, name TEXT, sort_order INTEGER)');
    await d.execute('CREATE TABLE IF NOT EXISTS custom_group_channels(group_id TEXT, url TEXT, sort_order INTEGER, PRIMARY KEY(group_id, url))');
    await d.execute('CREATE TABLE IF NOT EXISTS channel_overrides(profile TEXT, url TEXT, hidden INTEGER DEFAULT 0, custom_name TEXT, PRIMARY KEY(profile, url))');
    await d.execute('CREATE TABLE IF NOT EXISTS hidden_groups(profile TEXT, source_id TEXT, grp TEXT, PRIMARY KEY(profile, source_id, grp))');
    await d.execute('CREATE TABLE IF NOT EXISTS reminders(id INTEGER PRIMARY KEY AUTOINCREMENT, profile TEXT, chan_name TEXT, chan_url TEXT, title TEXT, start INTEGER, stop INTEGER)');
    await d.execute('CREATE TABLE IF NOT EXISTS downloads(key TEXT PRIMARY KEY, title TEXT, poster TEXT, file_path TEXT, size_bytes INTEGER, created INTEGER)');
    await d.execute('CREATE TABLE IF NOT EXISTS recordings(id TEXT PRIMARY KEY, chan_name TEXT, title TEXT, file_path TEXT, started INTEGER, duration_sec INTEGER, size_bytes INTEGER)');
    await d.execute('CREATE TABLE IF NOT EXISTS saved_layouts(id TEXT PRIMARY KEY, profile TEXT, name TEXT, preset TEXT, urls_json TEXT, names_json TEXT)');
  }

  // ---------- Canlı kanallar ----------
  static Future<int> countChannels(String src) async {
    final d = await db;
    return Sqflite.firstIntValue(await d.rawQuery('SELECT COUNT(*) FROM channels WHERE source_id = ?', [src])) ?? 0;
  }

  static Future<void> replaceChannels(String src, List<Channel> list) async {
    final d = await db;
    await d.transaction((t) async {
      await t.delete('channels', where: 'source_id = ?', whereArgs: [src]);
      for (var i = 0; i < list.length; i += 2000) {
        final b = t.batch();
        for (final c in list.sublist(i, min(i + 2000, list.length))) {
          b.insert('channels', {
            'source_id': src,
            'name': c.name,
            'name_norm': normName(c.name),
            'url': c.url,
            'grp': c.group,
            'logo': c.logo,
            'epg_id': c.epgId,
            'stream_id': c.streamId,
            'catchup_days': c.catchupDays,
          });
        }
        await b.commit(noResult: true);
      }
    });
  }

  static Future<void> deleteSource(String src) async {
    final d = await db;
    await d.transaction((t) async {
      await t.delete('channels', where: 'source_id = ?', whereArgs: [src]);
      await t.delete('items', where: 'source_id = ?', whereArgs: [src]);
      await t.delete('programmes', where: 'src = ?', whereArgs: [src]);
      await t.delete('epg_channels', where: 'src = ?', whereArgs: [src]);
      await t.delete('hidden_groups', where: 'source_id = ?', whereArgs: [src]);
    });
  }

  static String _fav(String profile) =>
      "EXISTS(SELECT 1 FROM favorites f WHERE f.url = c.url AND f.profile = '${_pf(profile)}')";

  static Future<List<String>> groups(String src, {required String profile, bool favOnly = false, bool kids = false, bool includeHidden = false}) async {
    final d = await db;
    final pf = _pf(profile);
    final hideClause = includeHidden
        ? ''
        : "AND NOT EXISTS(SELECT 1 FROM hidden_groups hg WHERE hg.profile = '$pf' AND hg.source_id = c.source_id AND hg.grp = c.grp)";
    final rows = await d.rawQuery(
        "SELECT DISTINCT grp FROM channels c WHERE source_id = ? AND grp != '' "
        "${favOnly ? 'AND ${_fav(profile)}' : ''} $hideClause ${kids ? kidsClause('grp') : ''} ORDER BY grp",
        [src]);
    return [for (final r in rows) r['grp'] as String];
  }

  static Future<List<Channel>> channels({
    required String src,
    required String profile,
    bool kids = false,
    String group = '',
    String customGroupId = '',
    String q = '',
    bool favOnly = false,
    bool withEpg = false,
    bool includeHidden = false,
    int offset = 0,
    int limit = pageSize,
  }) async {
    final d = await db;
    final pf = _pf(profile);
    final fe = _fav(profile);
    final where = <String>['c.source_id = ?'];
    final args = <Object?>[src];

    if (customGroupId.isNotEmpty) {
      where.add('EXISTS(SELECT 1 FROM custom_group_channels cgc WHERE cgc.group_id = ? AND cgc.url = c.url)');
      args.add(customGroupId);
    } else if (group.isNotEmpty) {
      where.add('c.grp = ?');
      args.add(group);
    }
    final nq = normName(q);
    if (nq.isNotEmpty) {
      where.add("(c.name_norm LIKE ? OR LOWER(COALESCE(ov.custom_name, '')) LIKE ?)");
      args.add('%$nq%');
      args.add('%${q.trim().toLowerCase()}%');
    }
    if (favOnly) where.add(fe);
    if (withEpg) {
      where.add("c.epg_id != '' AND EXISTS(SELECT 1 FROM programmes p WHERE p.src = c.source_id AND p.chan = c.epg_id)");
    }
    if (!includeHidden) {
      where.add('COALESCE(ov.hidden, 0) = 0');
      if (customGroupId.isEmpty) {
        where.add("NOT EXISTS(SELECT 1 FROM hidden_groups hg WHERE hg.profile = '$pf' AND hg.source_id = c.source_id AND hg.grp = c.grp)");
      }
    }
    var w = where.join(' AND ');
    if (kids) w += kidsClause('c.grp');
    final rows = await d.rawQuery(
        "SELECT c.*, $fe AS fav, COALESCE(ov.custom_name, '') AS custom_name "
        "FROM channels c "
        "LEFT JOIN channel_overrides ov ON ov.profile = '$pf' AND ov.url = c.url "
        "WHERE $w ORDER BY c.id LIMIT ? OFFSET ?",
        [...args, limit, offset]);
    final list = [for (final r in rows) Channel.fromRow(r)];
    await _attachEpg(d, src, list);
    return list;
  }

  /// Aynı kanala ait farklı kalite varyantlarını (4K, FHD, HD, RAW, VIP vb.) tek kanalda birleştirir.
  static List<Channel> groupVariants(List<Channel> raw) {
    final byKey = <String, List<Channel>>{};
    final order = <String>[];
    for (final c in raw) {
      final norm = normName(c.displayName);
      final key = norm.isEmpty ? c.url : '${c.group}|$norm';
      if (!byKey.containsKey(key)) {
        byKey[key] = [];
        order.add(key);
      }
      if (!byKey[key]!.any((e) => e.url == c.url)) {
        byKey[key]!.add(c);
      }
    }
    final out = <Channel>[];
    for (final k in order) {
      final group = byKey[k]!;
      if (group.length == 1) {
        out.add(group.first);
        continue;
      }
      group.sort((a, b) => qualityRank(b.qualityTag).compareTo(qualityRank(a.qualityTag)));
      final primary = group.first;
      primary.variants = [
        for (var i = 0; i < min(group.length, 8); i++)
          ChannelVariant(
            label: group[i].qualityTag.isNotEmpty ? group[i].qualityTag : 'Kaynak ${i + 1}',
            url: group[i].url,
            name: group[i].displayName,
          ),
      ];
      out.add(primary);
    }
    return out;
  }

  static Future<void> _attachEpg(Database d, String src, List<Channel> list) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final withId = [for (final c in list) if (c.epgId.isNotEmpty) c];
    if (withId.isEmpty) return;
    final b = d.batch();
    for (final c in withId) {
      b.query('programmes',
          columns: ['title', 'start', 'stop'],
          where: 'src = ? AND chan = ? AND start <= ? AND stop > ?',
          whereArgs: [src, c.epgId, now, now],
          limit: 1);
      b.query('programmes',
          columns: ['title'],
          where: 'src = ? AND chan = ? AND start >= ?',
          whereArgs: [src, c.epgId, now],
          orderBy: 'start',
          limit: 1);
    }
    final res = await b.commit();
    for (var i = 0; i < withId.length; i++) {
      final nowRows = res[i * 2] as List;
      final nextRows = res[i * 2 + 1] as List;
      if (nowRows.isNotEmpty) {
        final r = nowRows.first as Map;
        withId[i].nowTitle = '${r['title']}';
        withId[i].nowStart = r['start'] as int;
        withId[i].nowStop = r['stop'] as int;
      }
      if (nextRows.isNotEmpty) withId[i].nextTitle = '${(nextRows.first as Map)['title']}';
    }
  }

  static Future<List<Programme>> programmes(String src, String chan, int from, int to) async {
    final d = await db;
    final rows = await d.query('programmes',
        where: 'src = ? AND chan = ? AND stop > ? AND start < ?', whereArgs: [src, chan, from, to], orderBy: 'start');
    return [
      for (final r in rows)
        Programme(r['start'] as int, r['stop'] as int, (r['title'] ?? '') as String, (r['descr'] ?? '') as String)
    ];
  }

  static Future<Map<String, List<Programme>>> programmesBatch(
      String src, List<String> epgIds, int from, int to) async {
    final d = await db;
    final clean = epgIds.where((e) => e.isNotEmpty).toSet().toList();
    if (clean.isEmpty) return {};
    final b = d.batch();
    for (final id in clean) {
      b.query('programmes',
          where: 'src = ? AND chan = ? AND stop > ? AND start < ?',
          whereArgs: [src, id, from, to],
          orderBy: 'start');
    }
    final res = await b.commit();
    final map = <String, List<Programme>>{};
    for (var i = 0; i < clean.length; i++) {
      final rows = res[i] as List;
      map[clean[i]] = [
        for (final r in rows.cast<Map<String, Object?>>())
          Programme(r['start'] as int, r['stop'] as int, (r['title'] ?? '') as String, (r['descr'] ?? '') as String)
      ];
    }
    return map;
  }

  static Future<List<Map<String, Object?>>> searchProgrammes(String src, String q, {int limit = 30}) async {
    final d = await db;
    final clean = q.trim();
    if (clean.isEmpty) return [];
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return d.rawQuery(
      'SELECT p.chan, p.start, p.stop, p.title, p.descr, c.name AS chan_name, c.url AS chan_url, c.logo AS chan_logo '
      'FROM programmes p '
      'JOIN channels c ON c.source_id = p.src AND c.epg_id = p.chan '
      'WHERE p.src = ? AND p.stop > ? AND LOWER(p.title) LIKE ? '
      'GROUP BY p.chan, p.start ORDER BY p.start LIMIT ?',
      [src, now - 3600, '%${clean.toLowerCase()}%', limit],
    );
  }

  static Future<void> toggleFav(String profile, String url) async {
    final d = await db;
    final pf = _pf(profile);
    final n = await d.delete('favorites', where: 'profile = ? AND url = ?', whereArgs: [pf, url]);
    if (n == 0) await d.insert('favorites', {'profile': pf, 'url': url});
  }

  static Future<void> replaceEpg(
      String src, List<Map<String, Object?>> chans, List<Map<String, Object?>> progs) async {
    final d = await db;
    await d.transaction((t) async {
      await t.delete('programmes', where: 'src = ?', whereArgs: [src]);
      await t.delete('epg_channels', where: 'src = ?', whereArgs: [src]);
      for (var i = 0; i < chans.length; i += 3000) {
        final b = t.batch();
        for (final m in chans.sublist(i, min(i + 3000, chans.length))) {
          b.insert('epg_channels', {...m, 'src': src});
        }
        await b.commit(noResult: true);
      }
      for (var i = 0; i < progs.length; i += 3000) {
        final b = t.batch();
        for (final m in progs.sublist(i, min(i + 3000, progs.length))) {
          b.insert('programmes', {...m, 'src': src});
        }
        await b.commit(noResult: true);
      }
      await t.rawUpdate(
          "UPDATE channels SET epg_id = COALESCE((SELECT e.chan FROM epg_channels e "
          "WHERE e.src = channels.source_id AND e.name_norm = channels.name_norm AND e.name_norm != '' LIMIT 1), '') "
          "WHERE source_id = ? AND (epg_id IS NULL OR epg_id = '' "
          "OR epg_id NOT IN (SELECT chan FROM epg_channels WHERE src = ?))",
          [src, src]);
    });
  }

  // ---------- Özel Gruplar & Kanal Düzenleme ----------
  static Future<List<CustomGroup>> customGroups(String profile) async {
    final d = await db;
    final pf = _pf(profile);
    final rows = await d.rawQuery(
      'SELECT g.id, g.name, COUNT(c.url) AS cnt '
      'FROM custom_groups g LEFT JOIN custom_group_channels c ON c.group_id = g.id '
      'WHERE g.profile = ? GROUP BY g.id ORDER BY g.sort_order, g.name',
      [pf],
    );
    return [for (final r in rows) CustomGroup(id: '${r['id']}', name: '${r['name']}', count: (r['cnt'] as int?) ?? 0)];
  }

  static Future<void> createCustomGroup(String profile, String name) async {
    final d = await db;
    final id = 'cg_${DateTime.now().millisecondsSinceEpoch}';
    await d.insert('custom_groups', {'id': id, 'profile': _pf(profile), 'name': name.trim(), 'sort_order': 0});
  }

  static Future<void> deleteCustomGroup(String groupId) async {
    final d = await db;
    await d.transaction((t) async {
      await t.delete('custom_group_channels', where: 'group_id = ?', whereArgs: [groupId]);
      await t.delete('custom_groups', where: 'id = ?', whereArgs: [groupId]);
    });
  }

  static Future<void> toggleChannelInGroup(String groupId, String url) async {
    final d = await db;
    final n = await d.delete('custom_group_channels', where: 'group_id = ? AND url = ?', whereArgs: [groupId, url]);
    if (n == 0) {
      await d.insert('custom_group_channels', {'group_id': groupId, 'url': url, 'sort_order': 0});
    }
  }

  static Future<Set<String>> channelGroupIds(String url) async {
    final d = await db;
    final rows = await d.query('custom_group_channels', columns: ['group_id'], where: 'url = ?', whereArgs: [url]);
    return {for (final r in rows) '${r['group_id']}'};
  }

  static Future<void> setChannelOverride(String profile, String url, {bool? hidden, String? customName}) async {
    final d = await db;
    final pf = _pf(profile);
    final cur = await d.query('channel_overrides', where: 'profile = ? AND url = ?', whereArgs: [pf, url], limit: 1);
    final h = hidden ?? (cur.isNotEmpty && ((cur.first['hidden'] as int?) ?? 0) == 1);
    final n = customName ?? (cur.isNotEmpty ? '${cur.first['custom_name'] ?? ''}' : '');
    await d.insert(
      'channel_overrides',
      {'profile': pf, 'url': url, 'hidden': h ? 1 : 0, 'custom_name': n},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> hideGroup(String profile, String src, String grp, bool hide) async {
    final d = await db;
    final pf = _pf(profile);
    if (hide) {
      await d.insert('hidden_groups', {'profile': pf, 'source_id': src, 'grp': grp},
          conflictAlgorithm: ConflictAlgorithm.ignore);
    } else {
      await d.delete('hidden_groups', where: 'profile = ? AND source_id = ? AND grp = ?', whereArgs: [pf, src, grp]);
    }
  }

  static Future<List<String>> hiddenGroups(String profile, String src) async {
    final d = await db;
    final rows = await d.query('hidden_groups',
        columns: ['grp'], where: 'profile = ? AND source_id = ?', whereArgs: [_pf(profile), src]);
    return [for (final r in rows) '${r['grp']}'];
  }

  // ---------- Film / dizi ----------
  static Future<void> replaceItems(String src, String kind, List<MediaItem> list) async {
    final d = await db;
    await d.transaction((t) async {
      await t.delete('items', where: 'source_id = ? AND kind = ?', whereArgs: [src, kind]);
      for (var i = 0; i < list.length; i += 2000) {
        final b = t.batch();
        for (final m in list.sublist(i, min(i + 2000, list.length))) {
          b.insert('items', {
            'source_id': src,
            'kind': kind,
            'ext_id': m.extId,
            'key': m.key,
            'name': m.name,
            'name_norm': normName(m.name),
            'cat': m.cat,
            'poster': m.poster,
            'rating': m.rating,
            'ext': m.ext,
          });
        }
        await b.commit(noResult: true);
      }
    });
  }

  static Future<List<String>> cats(String src, String? kind, {bool kids = false}) async {
    final d = await db;
    final rows = await d.rawQuery(
        "SELECT DISTINCT cat FROM items WHERE source_id = ? ${kind != null ? 'AND kind = ?' : ''} "
        "AND cat != '' ${kids ? kidsClause('cat') : ''} ORDER BY cat",
        [src, if (kind != null) kind]);
    return [for (final r in rows) r['cat'] as String];
  }

  static String _watch(String profile) =>
      "EXISTS(SELECT 1 FROM watchlist w WHERE w.key = i.key AND w.profile = '${_pf(profile)}')";

  static Future<List<MediaItem>> items({
    required String src,
    required String profile,
    String? kind,
    String cat = '',
    String q = '',
    bool watchOnly = false,
    bool kids = false,
    String sort = 'default', // 'default' | 'az' | 'rating'
    int offset = 0,
    int limit = pageSize,
  }) async {
    final d = await db;
    final we = _watch(profile);
    final where = <String>['i.source_id = ?'];
    final args = <Object?>[src];
    if (kind != null) {
      where.add('i.kind = ?');
      args.add(kind);
    }
    if (cat.isNotEmpty) {
      where.add('i.cat = ?');
      args.add(cat);
    }
    final nq = normName(q);
    if (nq.isNotEmpty) {
      where.add('i.name_norm LIKE ?');
      args.add('%$nq%');
    }
    if (watchOnly) where.add(we);
    var w = where.join(' AND ');
    if (kids) w += kidsClause('i.cat');
    final orderBy = switch (sort) {
      'az' => 'i.name COLLATE NOCASE ASC',
      'rating' => 'CAST(i.rating AS REAL) DESC, i.id ASC',
      _ => 'i.id ASC',
    };
    final rows = await d.rawQuery(
        'SELECT i.*, $we AS watch FROM items i WHERE $w ORDER BY $orderBy LIMIT ? OFFSET ?', [...args, limit, offset]);
    return [for (final r in rows) MediaItem.fromRow(r)];
  }

  static Future<void> toggleWatch(String profile, String key) async {
    final d = await db;
    final pf = _pf(profile);
    final n = await d.delete('watchlist', where: 'profile = ? AND key = ?', whereArgs: [pf, key]);
    if (n == 0) await d.insert('watchlist', {'profile': pf, 'key': key});
  }

  // ---------- İzleme geçmişi ----------
  static Future<void> saveProgress(String profile, PlayItem it, int pos, int dur) async {
    final d = await db;
    await d.insert(
        'history',
        {
          'profile': _pf(profile),
          'key': it.key,
          'kind': it.kind,
          'title': it.title,
          'url': it.url,
          'poster': it.poster,
          'pos': pos,
          'dur': dur,
          'updated': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  static Future<HistoryEntry?> progress(String profile, String key) async {
    final d = await db;
    final r = await d.query('history', where: 'profile = ? AND key = ?', whereArgs: [_pf(profile), key], limit: 1);
    return r.isEmpty ? null : _hist(r.first);
  }

  static HistoryEntry _hist(Map<String, Object?> r) => HistoryEntry('${r['key']}', '${r['kind']}', '${r['title']}',
      '${r['url']}', '${r['poster']}', (r['pos'] ?? 0) as int, (r['dur'] ?? 0) as int);

  static Future<List<HistoryEntry>> continueWatching(String profile) async {
    final d = await db;
    final r = await d.query('history',
        where: 'profile = ? AND dur > 0 AND pos > 10', whereArgs: [_pf(profile)], orderBy: 'updated DESC', limit: 60);
    return [for (final x in r.map(_hist)) if (x.pos < x.dur * 0.95) x];
  }

  // ---------- Hatırlatıcılar ----------
  static Future<void> addReminder(String profile, String chanName, String chanUrl, Programme p) async {
    final d = await db;
    await d.insert('reminders', {
      'profile': _pf(profile),
      'chan_name': chanName,
      'chan_url': chanUrl,
      'title': p.title,
      'start': p.start,
      'stop': p.stop,
    });
  }

  static Future<void> deleteReminder(int id) async {
    final d = await db;
    await d.delete('reminders', where: 'id = ?', whereArgs: [id]);
  }

  static Future<List<ReminderItem>> reminders(String profile) async {
    final d = await db;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final rows = await d.query('reminders',
        where: 'profile = ? AND stop > ?', whereArgs: [_pf(profile), now - 300], orderBy: 'start ASC');
    return [
      for (final r in rows)
        ReminderItem(
          id: r['id'] as int,
          channelName: '${r['chan_name']}',
          channelUrl: '${r['chan_url']}',
          title: '${r['title']}',
          start: r['start'] as int,
          stop: r['stop'] as int,
        )
    ];
  }

  // ---------- Çevrimdışı İndirmeler & Kayıtlar ----------
  static Future<void> saveDownload(DownloadItem item) async {
    final d = await db;
    await d.insert(
      'downloads',
      {
        'key': item.key,
        'title': item.title,
        'poster': item.poster,
        'file_path': item.filePath,
        'size_bytes': item.sizeBytes,
        'created': item.created,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<DownloadItem>> downloads() async {
    final d = await db;
    final rows = await d.query('downloads', orderBy: 'created DESC');
    return [
      for (final r in rows)
        DownloadItem(
          key: '${r['key']}',
          title: '${r['title']}',
          poster: '${r['poster']}',
          filePath: '${r['file_path']}',
          sizeBytes: (r['size_bytes'] as int?) ?? 0,
          created: (r['created'] as int?) ?? 0,
        )
    ];
  }

  static Future<void> deleteDownload(String key) async {
    final d = await db;
    await d.delete('downloads', where: 'key = ?', whereArgs: [key]);
  }

  static Future<void> saveRecording(RecordingItem rec) async {
    final d = await db;
    await d.insert(
      'recordings',
      {
        'id': rec.id,
        'chan_name': rec.channelName,
        'title': rec.title,
        'file_path': rec.filePath,
        'started': rec.started,
        'duration_sec': rec.durationSec,
        'size_bytes': rec.sizeBytes,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<List<RecordingItem>> recordings() async {
    final d = await db;
    final rows = await d.query('recordings', orderBy: 'started DESC');
    return [
      for (final r in rows)
        RecordingItem(
          id: '${r['id']}',
          channelName: '${r['chan_name']}',
          title: '${r['title']}',
          filePath: '${r['file_path']}',
          started: (r['started'] as int?) ?? 0,
          durationSec: (r['duration_sec'] as int?) ?? 0,
          sizeBytes: (r['size_bytes'] as int?) ?? 0,
        )
    ];
  }

  static Future<void> deleteRecording(String id) async {
    final d = await db;
    await d.delete('recordings', where: 'id = ?', whereArgs: [id]);
  }

  // ---------- Kayıtlı Çoklu İzleme Düzenleri ----------
  static Future<List<SavedMultiviewLayout>> savedLayouts(String profile) async {
    final d = await db;
    final rows = await d.query('saved_layouts', where: 'profile = ?', whereArgs: [_pf(profile)], orderBy: 'name ASC');
    return [
      for (final r in rows)
        SavedMultiviewLayout(
          id: '${r['id']}',
          name: '${r['name']}',
          preset: '${r['preset']}',
          urls: List<String>.from(jsonDecode('${r['urls_json']}')),
          names: List<String>.from(jsonDecode('${r['names_json']}')),
        )
    ];
  }

  static Future<void> saveLayout(String profile, SavedMultiviewLayout layout) async {
    final d = await db;
    await d.insert(
      'saved_layouts',
      {
        'id': layout.id,
        'profile': _pf(profile),
        'name': layout.name,
        'preset': layout.preset,
        'urls_json': jsonEncode(layout.urls),
        'names_json': jsonEncode(layout.names),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<void> deleteLayout(String id) async {
    final d = await db;
    await d.delete('saved_layouts', where: 'id = ?', whereArgs: [id]);
  }
}
