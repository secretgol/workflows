import 'dart:async';
import 'package:flutter/material.dart';
import 'db.dart';
import 'models.dart';
import 'multiview.dart';
import 'player.dart';
import 'store.dart';
import 'theme.dart';
import 'util.dart';
import 'views.dart';
import 'xtream.dart';

/// IPTV Deck tarzı Ana Sayfa: Hero Spotlight, İzlemeye Devam Et, Favori Kanallar, Filmler & Diziler.
class HomeDashboardView extends StatefulWidget {
  final AppState state;
  final ValueChanged<int> onNavigateTab;
  const HomeDashboardView(this.state, {required this.onNavigateTab, super.key});

  @override
  State<HomeDashboardView> createState() => _HomeDashboardViewState();
}

class _HomeDashboardViewState extends State<HomeDashboardView> {
  List<HistoryEntry> history = [];
  List<Channel> favs = [];
  List<Channel> liveSample = [];
  List<MediaItem> movies = [];
  List<MediaItem> series = [];
  int _dv = -1, _fv = -1, _vv = -1, _hv = -1;

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    s.addListener(_onState);
    _load();
  }

  @override
  void dispose() {
    s.removeListener(_onState);
    super.dispose();
  }

  void _onState() {
    if (_dv != s.dataVersion || _fv != s.favVersion || _vv != s.vodVersion || _hv != s.histVersion) {
      _load();
    }
  }

  Future<void> _load() async {
    _dv = s.dataVersion;
    _fv = s.favVersion;
    _vv = s.vodVersion;
    _hv = s.histVersion;
    final src = s.active?.id;
    final h = await Db.continueWatching(s.profile.id);
    List<Channel> f = [], l = [];
    List<MediaItem> m = [], sr = [];
    if (src != null) {
      f = await Db.channels(src: src, profile: s.profile.id, kids: s.profile.kids, favOnly: true, limit: 20);
      l = await Db.channels(src: src, profile: s.profile.id, kids: s.profile.kids, limit: 15);
      m = await Db.items(src: src, profile: s.profile.id, kind: 'movie', kids: s.profile.kids, limit: 20);
      sr = await Db.items(src: src, profile: s.profile.id, kind: 'series', kids: s.profile.kids, limit: 20);
    }
    if (!mounted) return;
    setState(() {
      history = h;
      favs = f;
      liveSample = l;
      movies = m;
      series = sr;
    });
  }

  void _playChannel(Channel c, List<Channel> list, int idx) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(s, channelItem(c, ua: s.active?.effectiveUa ?? kUa, zapList: list, zapIndex: idx))),
    );
  }

  void _openMedia(MediaItem it) {
    final src = s.sources.where((x) => x.id == it.sourceId).firstOrNull ?? s.active;
    if (src == null) return;
    final Widget page = it.kind == 'series'
        ? SeriesScreen(s, it)
        : PlayerScreen(
            s,
            PlayItem(
              title: it.name,
              url: movieUrl(src, it),
              key: it.key,
              kind: 'movie',
              poster: it.poster,
              userAgent: src.effectiveUa,
            ),
          );
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Widget _heroSpotlight() {
    final hasHistory = history.isNotEmpty;
    final heroMovie = movies.isNotEmpty ? movies.first : (series.isNotEmpty ? series.first : null);
    final heroChan = favs.isNotEmpty ? favs.first : (liveSample.isNotEmpty ? liveSample.first : null);

    final String title;
    final String subtitle;
    final String badge;
    final String imageUrl;
    final VoidCallback? onPlay;

    if (hasHistory) {
      final h = history.first;
      title = h.title;
      subtitle = 'Kaldığınız yerden devam edin · ${formatDuration(h.pos)} / ${formatDuration(h.dur)}';
      badge = 'DEVAM ET';
      imageUrl = h.poster;
      onPlay = () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(s, h.toPlay())));
    } else if (heroChan != null) {
      title = heroChan.displayName;
      subtitle = heroChan.nowTitle.isNotEmpty ? 'Şu an: ${heroChan.nowTitle}' : heroChan.group;
      badge = 'CANLI YAYIN';
      imageUrl = heroChan.logo;
      onPlay = () => _playChannel(heroChan, favs.isNotEmpty ? favs : liveSample, 0);
    } else if (heroMovie != null) {
      title = heroMovie.name;
      subtitle = heroMovie.cat.isNotEmpty ? heroMovie.cat : 'Öne Çıkan';
      badge = heroMovie.kind == 'series' ? 'DİZİ' : 'FİLM';
      imageUrl = heroMovie.poster;
      onPlay = () => _openMedia(heroMovie);
    } else {
      return Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 8),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF101929), Color(0xFF0C0E16)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: kBorder),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const TagPill('OPEN IPTV', color: Color(0x26D9BC84), textColor: kGold),
          const SizedBox(height: 12),
          Text('Kendi IPTV Merkeziniz', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          const Text(
            'M3U, Xtream Codes, yerel dosya veya Jellyfin/Emby kaynağınızı ekleyerek Canlı TV, 14 günlük Rehber, Çoklu İzleme ve VOD dünyasına başlayın.',
            style: TextStyle(color: kTextSoft, height: 1.45),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => widget.onNavigateTab(7),
            icon: const Icon(Icons.add),
            label: const Text('Playlist Ekle'),
          ),
        ]),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      height: 220,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: kPanel,
        border: Border.all(color: kBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(fit: StackFit.expand, children: [
        if (imageUrl.isNotEmpty)
          Opacity(
            opacity: 0.28,
            child: Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox.shrink()),
          ),
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xF5070910), Color(0xCC0A0D18), Color(0x3305060B)],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(children: [
                if (badge == 'CANLI YAYIN')
                  const LiveBadge()
                else
                  TagPill(badge, color: kGold.withValues(alpha: 0.18), textColor: kGold),
                if (s.active != null) ...[
                  const SizedBox(width: 8),
                  TagPill(s.active!.name),
                ],
              ]),
              const SizedBox(height: 10),
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.headlineMedium),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: kTextSoft)),
              ],
              const SizedBox(height: 16),
              Wrap(spacing: 10, runSpacing: 8, children: [
                FilledButton.icon(
                  onPressed: onPlay,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(hasHistory ? 'Devam Et' : 'Şimdi İzle'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MultiviewScreen(s))),
                  icon: const Icon(Icons.grid_view_rounded, size: 18),
                  label: const Text('Çoklu İzleme'),
                ),
              ]),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _sectionHeader(String title, {VoidCallback? onMore}) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 16, 10),
        child: Row(children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const Spacer(),
          if (onMore != null)
            TextButton(
              onPressed: onMore,
              child: const Text('Tümü', style: TextStyle(color: kCyan)),
            ),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _heroSpotlight(),
        if (history.isNotEmpty) ...[
          _sectionHeader('İzlemeye Devam Et', onMore: () => widget.onNavigateTab(6)),
          SizedBox(
            height: 146,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final h = history[i];
                final prog = h.dur > 0 ? (h.pos / h.dur).clamp(0.0, 1.0) : 0.0;
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(s, h.toPlay()))),
                  child: Container(
                    width: 210,
                    decoration: BoxDecoration(
                      color: kPanel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kBorder),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(
                        child: Stack(fit: StackFit.expand, children: [
                          h.poster.isEmpty
                              ? Container(color: kSurface2, child: const Icon(Icons.movie_outlined, color: kTextMuted, size: 32))
                              : Image.network(h.poster, fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Container(color: kSurface2, child: const Icon(Icons.movie_outlined))),
                          const Center(
                            child: CircleAvatar(
                              radius: 18,
                              backgroundColor: Color(0xAA05060B),
                              child: Icon(Icons.play_arrow_rounded, color: kCyan),
                            ),
                          ),
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            child: LinearProgressIndicator(value: prog, minHeight: 3, color: kCyan, backgroundColor: Colors.black54),
                          ),
                        ]),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Text(h.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
        if (favs.isNotEmpty || liveSample.isNotEmpty) ...[
          _sectionHeader(favs.isNotEmpty ? 'Favori Kanallar' : 'Canlı Kanallar', onMore: () => widget.onNavigateTab(2)),
          SizedBox(
            height: 104,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: (favs.isNotEmpty ? favs : liveSample).length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final list = favs.isNotEmpty ? favs : liveSample;
                final c = list[i];
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _playChannel(c, list, i),
                  child: Container(
                    width: 188,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kPanel,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kBorder),
                    ),
                    child: Row(children: [
                      ChannelLogo(c.logo),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(c.displayName, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                            const SizedBox(height: 3),
                            Text(
                              c.nowTitle.isNotEmpty ? c.nowTitle : c.group,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: kTextMuted, fontSize: 11.5),
                            ),
                            if (c.qualityTag.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              TagPill(c.qualityTag),
                            ],
                          ],
                        ),
                      ),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
        if (movies.isNotEmpty) ...[
          _sectionHeader('Filmler', onMore: () => widget.onNavigateTab(4)),
          _posterRail(movies),
        ],
        if (series.isNotEmpty) ...[
          _sectionHeader('Diziler', onMore: () => widget.onNavigateTab(5)),
          _posterRail(series),
        ],
      ],
    );
  }

  Widget _posterRail(List<MediaItem> list) => SizedBox(
        height: 222,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, i) {
            final it = list[i];
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _openMedia(it),
              child: SizedBox(
                width: 124,
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(
                    child: Stack(fit: StackFit.expand, children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: it.poster.isEmpty
                            ? Container(color: kSurface2, child: const Icon(Icons.movie_outlined, color: kTextMuted))
                            : Image.network(it.poster, fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(color: kSurface2, child: const Icon(Icons.movie_outlined))),
                      ),
                      Positioned(right: 6, bottom: 6, child: RatingBadge(it.rating)),
                    ]),
                  ),
                  const SizedBox(height: 6),
                  Text(it.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: kTextSoft)),
                ]),
              ),
            );
          },
        ),
      );
}

/// Birleşik Global Arama: Canlı Kanallar, Filmler, Diziler ve EPG Programları tek ekranda.
class GlobalSearchView extends StatefulWidget {
  final AppState state;
  const GlobalSearchView(this.state, {super.key});
  @override
  State<GlobalSearchView> createState() => _GlobalSearchViewState();
}

class _GlobalSearchViewState extends State<GlobalSearchView> {
  final _ctrl = TextEditingController();
  Timer? _deb;
  bool _busy = false;
  List<Channel> _chans = [];
  List<MediaItem> _movies = [];
  List<MediaItem> _series = [];
  List<Map<String, Object?>> _progs = [];

  AppState get s => widget.state;

  @override
  void dispose() {
    _deb?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _search(String q) async {
    final src = s.active?.id;
    if (src == null || q.trim().isEmpty) {
      setState(() {
        _chans = [];
        _movies = [];
        _series = [];
        _progs = [];
      });
      return;
    }
    setState(() => _busy = true);
    final res = await Future.wait([
      Db.channels(src: src, profile: s.profile.id, kids: s.profile.kids, q: q, limit: 30),
      Db.items(src: src, profile: s.profile.id, kind: 'movie', kids: s.profile.kids, q: q, limit: 30),
      Db.items(src: src, profile: s.profile.id, kind: 'series', kids: s.profile.kids, q: q, limit: 30),
      Db.searchProgrammes(src, q, limit: 25),
    ]);
    if (!mounted) return;
    setState(() {
      _chans = res[0] as List<Channel>;
      _movies = res[1] as List<MediaItem>;
      _series = res[2] as List<MediaItem>;
      _progs = res[3] as List<Map<String, Object?>>;
      _busy = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final empty = _chans.isEmpty && _movies.isEmpty && _series.isEmpty && _progs.isEmpty;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
        child: TextField(
          controller: _ctrl,
          autofocus: false,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, color: kCyan),
            hintText: 'Kanal, film, dizi veya TV programı ara…',
          ),
          onChanged: (v) {
            _deb?.cancel();
            _deb = Timer(const Duration(milliseconds: 250), () => _search(v));
          },
        ),
      ),
      if (_busy) const LinearProgressIndicator(minHeight: 2, color: kCyan),
      Expanded(
        child: _ctrl.text.trim().isEmpty
            ? const Center(child: Text('Aramak için yukarıya yazın.', style: TextStyle(color: kTextMuted)))
            : empty && !_busy
                ? const Center(child: Text('Sonuç bulunamadı.', style: TextStyle(color: kTextMuted)))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      if (_chans.isNotEmpty) ...[
                        _hdr('Canlı Kanallar (${_chans.length})'),
                        for (var i = 0; i < _chans.length; i++)
                          ListTile(
                            leading: ChannelLogo(_chans[i].logo),
                            title: Text(_chans[i].displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(_chans[i].nowTitle.isNotEmpty ? _chans[i].nowTitle : _chans[i].group,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            trailing: const Icon(Icons.play_arrow_rounded, color: kCyan),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlayerScreen(
                                  s,
                                  channelItem(_chans[i], ua: s.active?.effectiveUa ?? kUa, zapList: _chans, zapIndex: i),
                                ),
                              ),
                            ),
                          ),
                      ],
                      if (_movies.isNotEmpty) ...[
                        _hdr('Filmler (${_movies.length})'),
                        for (final m in _movies)
                          ListTile(
                            leading: const Icon(Icons.movie_outlined, color: kGold),
                            title: Text(m.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(m.cat),
                            trailing: RatingBadge(m.rating),
                            onTap: () {
                              final src = s.sources.where((x) => x.id == m.sourceId).firstOrNull ?? s.active;
                              if (src == null) return;
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => PlayerScreen(
                                    s,
                                    PlayItem(title: m.name, url: movieUrl(src, m), key: m.key, kind: 'movie', poster: m.poster, userAgent: src.effectiveUa),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                      if (_series.isNotEmpty) ...[
                        _hdr('Diziler (${_series.length})'),
                        for (final sr in _series)
                          ListTile(
                            leading: const Icon(Icons.tv_outlined, color: kCyan),
                            title: Text(sr.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text(sr.cat),
                            trailing: RatingBadge(sr.rating),
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => SeriesScreen(s, sr))),
                          ),
                      ],
                      if (_progs.isNotEmpty) ...[
                        _hdr('TV Rehberi Programları (${_progs.length})'),
                        for (final r in _progs)
                          ListTile(
                            leading: Text(hm(r['start'] as int), style: const TextStyle(color: kCyan, fontWeight: FontWeight.w700)),
                            title: Text('${r['title']}', maxLines: 1, overflow: TextOverflow.ellipsis),
                            subtitle: Text('${r['chan_name']} · ${dayLabel(r['start'] as int)}'),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PlayerScreen(
                                  s,
                                  PlayItem(
                                    title: '${r['chan_name']}',
                                    url: '${r['chan_url']}',
                                    isLive: true,
                                    kind: 'live',
                                    subtitle: '${r['title']}',
                                    userAgent: s.active?.effectiveUa ?? kUa,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
      ),
    ]);
  }

  Widget _hdr(String t) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 6),
        child: Text(t, style: const TextStyle(color: kCyan, fontWeight: FontWeight.w700, fontSize: 13)),
      );
}
