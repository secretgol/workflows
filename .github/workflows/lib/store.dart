import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'db.dart';
import 'epg.dart';
import 'm3u.dart';
import 'media_manager.dart';
import 'models.dart';
import 'xtream.dart';

class AppState extends ChangeNotifier {
  late SharedPreferences _prefs;
  final MediaManager media = MediaManager();

  List<Source> sources = [];
  Source? active;
  List<Profile> profiles = [];
  late Profile profile;

  bool groupVariants = true;
  String tmdbApiKey = '';

  bool loading = false;
  String? error;
  String epgStatus = '', vodStatus = '';
  ReminderItem? dueReminder;

  int dataVersion = 0, favVersion = 0, vodVersion = 0, watchVersion = 0, histVersion = 0, mediaVersion = 0;
  Timer? _reminderTimer;
  final Set<int> _firedReminders = {};

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    media.addListener(_onMediaChanged);

    try {
      sources = [for (final j in jsonDecode(_prefs.getString('sources') ?? '[]')) Source.fromJson(j)];
    } catch (_) {
      sources = [];
    }
    final id = _prefs.getString('active');
    active = sources.where((s) => s.id == id).firstOrNull ?? (sources.isEmpty ? null : sources.first);

    try {
      profiles = [for (final j in jsonDecode(_prefs.getString('profiles') ?? '[]')) Profile.fromJson(j)];
    } catch (_) {
      profiles = [];
    }
    if (profiles.isEmpty) profiles = [const Profile(id: 'p1', name: 'Ana')];
    final pid = _prefs.getString('profile');
    profile = profiles.where((x) => x.id == pid).firstOrNull ?? profiles.first;

    groupVariants = _prefs.getBool('group_variants') ?? true;
    tmdbApiKey = _prefs.getString('tmdb_key') ?? '';

    dataVersion++;
    final a = active;
    if (a != null) {
      final last = _prefs.getInt('last_${a.id}') ?? 0;
      final stale = DateTime.now().millisecondsSinceEpoch - last > a.refreshHours * 3600 * 1000;
      if (stale || await Db.countChannels(a.id) == 0) refresh(a);
    }

    _reminderTimer = Timer.periodic(const Duration(seconds: 30), (_) => _checkReminders());
    _checkReminders();
  }

  void _onMediaChanged() {
    mediaVersion++;
    notifyListeners();
  }

  @override
  void dispose() {
    _reminderTimer?.cancel();
    media.removeListener(_onMediaChanged);
    super.dispose();
  }

  Future<void> _checkReminders() async {
    final list = await Db.reminders(profile.id);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final r in list) {
      if (!_firedReminders.contains(r.id) && r.start <= now + 60 && r.stop > now) {
        _firedReminders.add(r.id);
        dueReminder = r;
        notifyListeners();
        break;
      }
    }
  }

  void dismissReminder() {
    dueReminder = null;
    notifyListeners();
  }

  // ---------- Tercihler ----------
  Future<void> setGroupVariants(bool v) async {
    groupVariants = v;
    await _prefs.setBool('group_variants', v);
    dataVersion++;
    notifyListeners();
  }

  Future<void> setTmdbKey(String key) async {
    tmdbApiKey = key.trim();
    await _prefs.setString('tmdb_key', tmdbApiKey);
    notifyListeners();
  }

  // ---------- Profiller ----------
  Future<void> _saveProfiles() => _prefs.setString('profiles', jsonEncode([for (final x in profiles) x.toJson()]));

  Future<void> addProfile(Profile x) async {
    profiles.add(x);
    await _saveProfiles();
    notifyListeners();
  }

  Future<void> removeProfile(Profile x) async {
    if (profiles.length <= 1 || x.id == profile.id) return;
    profiles.removeWhere((p) => p.id == x.id);
    await _saveProfiles();
    notifyListeners();
  }

  Future<void> switchProfile(Profile x) async {
    profile = x;
    await _prefs.setString('profile', x.id);
    dataVersion++;
    favVersion++;
    watchVersion++;
    histVersion++;
    notifyListeners();
  }

  // ---------- Playlistler ----------
  Future<void> _saveSources() => _prefs.setString('sources', jsonEncode([for (final s in sources) s.toJson()]));

  Future<void> addSource(Source s) async {
    sources.add(s);
    await _saveSources();
    await select(s);
  }

  Future<void> updateSource(Source s) async {
    final idx = sources.indexWhere((x) => x.id == s.id);
    if (idx < 0) return;
    sources[idx] = s;
    await _saveSources();
    if (active?.id == s.id) active = s;
    notifyListeners();
    await refresh(s);
  }

  Future<void> removeSource(Source s) async {
    sources.removeWhere((x) => x.id == s.id);
    await _saveSources();
    await Db.deleteSource(s.id);
    if (active?.id == s.id) {
      active = sources.isEmpty ? null : sources.first;
      await _prefs.setString('active', active?.id ?? '');
    }
    dataVersion++;
    vodVersion++;
    notifyListeners();
  }

  Future<void> select(Source s) async {
    active = s;
    await _prefs.setString('active', s.id);
    epgStatus = '';
    vodStatus = '';
    dataVersion++;
    vodVersion++;
    notifyListeners();
    if (await Db.countChannels(s.id) == 0) await refresh(s);
  }

  Future<void> refresh(Source s) async {
    loading = true;
    error = null;
    notifyListeners();
    String? epg = s.epgUrl.isEmpty ? null : s.epgUrl;
    try {
      List<Channel> list;
      if (s.type == 'xtream') {
        list = await loadXtream(s);
        epg ??= xtreamEpgUrl(s);
      } else if (s.type == 'jellyfin') {
        list = await loadJellyfinChannels(s);
      } else if (s.type == 'local_m3u') {
        final f = File(s.url);
        if (!await f.exists()) throw Exception('Dosya bulunamadı: ${s.url}');
        final bytes = await f.readAsBytes();
        final res = await compute(parseM3uBytes, bytes);
        list = res.channels;
        if (res.epgUrl.isNotEmpty) epg ??= res.epgUrl;
      } else {
        final r = await http.get(Uri.parse(s.url), headers: {'User-Agent': s.effectiveUa}).timeout(const Duration(seconds: 90));
        if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('HTTP ${r.statusCode}');
        final res = await compute(parseM3uBytes, r.bodyBytes);
        list = res.channels;
        if (res.epgUrl.isNotEmpty) epg ??= res.epgUrl;
      }
      await Db.replaceChannels(s.id, list);
      await _prefs.setInt('last_${s.id}', DateTime.now().millisecondsSinceEpoch);
      loading = false;
      dataVersion++;
      notifyListeners();
    } catch (e) {
      error = 'Playlist yüklenemedi: $e';
      loading = false;
      notifyListeners();
      return;
    }
    if (s.type == 'xtream' || s.type == 'jellyfin') await _loadVod(s);
    if (epg != null && epg.isNotEmpty) await _loadEpg(s, epg);
  }

  Future<void> _loadVod(Source s) async {
    var failed = false;
    for (final kind in ['movie', 'series']) {
      try {
        vodStatus = kind == 'movie' ? 'Filmler yükleniyor…' : 'Diziler yükleniyor…';
        notifyListeners();
        final list = s.type == 'jellyfin' ? await loadJellyfinItems(s, kind) : await loadXtreamItems(s, kind);
        await Db.replaceItems(s.id, kind, list);
        vodVersion++;
        notifyListeners();
      } catch (_) {
        failed = true;
      }
    }
    vodStatus = failed ? 'Film/dizi listesi kısmen alınamadı' : '';
    notifyListeners();
  }

  Future<void> _loadEpg(Source s, String url) async {
    epgStatus = 'Rehber indiriliyor…';
    notifyListeners();
    try {
      final r = await http.get(Uri.parse(url), headers: {'User-Agent': s.effectiveUa}).timeout(const Duration(minutes: 5));
      if (r.statusCode < 200 || r.statusCode >= 300) throw Exception('HTTP ${r.statusCode}');
      epgStatus = 'Rehber işleniyor…';
      notifyListeners();
      final parsed = await compute(parseXmltvInput, EpgParseInput(r.bodyBytes, s.epgOffsetMin));
      await Db.replaceEpg(s.id, parsed.channels, parsed.progs);
      epgStatus = 'Rehber güncel (${parsed.progs.length} program)';
      dataVersion++;
    } catch (e) {
      epgStatus = 'Rehber yüklenemedi';
    }
    notifyListeners();
  }

  // ---------- Yedekleme & Geri Yükleme (Windows <-> iOS aktarım) ----------
  String exportBackupJson() => const JsonEncoder.withIndent('  ').convert({
        'version': 1,
        'exportedAt': DateTime.now().toIso8601String(),
        'sources': [for (final s in sources) s.toJson()],
        'profiles': [for (final x in profiles) x.toJson()],
        'groupVariants': groupVariants,
        'tmdbApiKey': tmdbApiKey,
      });

  Future<String> saveBackupFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory(p.join(dir.path, 'OpenIPTV'));
    if (!await folder.exists()) await folder.create(recursive: true);
    final file = File(p.join(folder.path, 'open_iptv_backup.json'));
    await file.writeAsString(exportBackupJson());
    return file.path;
  }

  Future<void> importBackupJson(String raw) async {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    if (j['sources'] is List) {
      sources = [for (final x in j['sources']) Source.fromJson(Map<String, dynamic>.from(x))];
      await _saveSources();
    }
    if (j['profiles'] is List && (j['profiles'] as List).isNotEmpty) {
      profiles = [for (final x in j['profiles']) Profile.fromJson(Map<String, dynamic>.from(x))];
      await _saveProfiles();
      profile = profiles.first;
      await _prefs.setString('profile', profile.id);
    }
    if (j['groupVariants'] is bool) await setGroupVariants(j['groupVariants'] as bool);
    if (j['tmdbApiKey'] is String) await setTmdbKey(j['tmdbApiKey'] as String);
    active = sources.isEmpty ? null : sources.first;
    await _prefs.setString('active', active?.id ?? '');
    dataVersion++;
    vodVersion++;
    notifyListeners();
    if (active != null) refresh(active!);
  }

  // ---------- Küçük yardımcılar ----------
  Future<void> toggleFav(String url) async {
    await Db.toggleFav(profile.id, url);
    favVersion++;
    notifyListeners();
  }

  Future<void> toggleWatch(String key) async {
    await Db.toggleWatch(profile.id, key);
    watchVersion++;
    notifyListeners();
  }

  void bumpData() {
    dataVersion++;
    notifyListeners();
  }

  void bumpHistory() {
    histVersion++;
    notifyListeners();
  }

  void bumpMedia() {
    mediaVersion++;
    notifyListeners();
  }
}
