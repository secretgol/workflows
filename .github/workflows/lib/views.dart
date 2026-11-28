import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'db.dart';
import 'models.dart';
import 'multiview.dart';
import 'player.dart';
import 'store.dart';
import 'theme.dart';
import 'util.dart';
import 'xtream.dart';

enum ViewMode { live, guide, favorites }

PlayItem channelItem(
  Channel c, {
  String ua = kUa,
  List<Channel> zapList = const [],
  int zapIndex = -1,
}) =>
    PlayItem(
      title: c.displayName,
      url: c.url,
      isLive: true,
      key: c.url,
      kind: 'live',
      subtitle: c.nowTitle,
      userAgent: ua,
      variants: c.variants,
      zapList: zapList,
      zapIndex: zapIndex,
    );

class ChannelLogo extends StatelessWidget {
  final String url;
  const ChannelLogo(this.url, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: 50,
        height: 38,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: kSurface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: kBorderSoft),
        ),
        child: url.isEmpty
            ? const Icon(Icons.tv_rounded, size: 18, color: kTextMuted)
            : Image.network(url, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.tv_rounded, size: 18, color: kTextMuted)),
      );
}

InputDecoration searchDecoration(String hint) => InputDecoration(
      prefixIcon: const Icon(Icons.search, color: kCyan),
      hintText: hint,
      filled: true,
      fillColor: kSurface2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: kBorderSoft)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: kBorderSoft)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: kCyan)),
      contentPadding: EdgeInsets.zero,
    );

// ===================== Canlı Kanallar / Mobil Rehber / Favoriler =====================
class ChannelsView extends StatefulWidget {
  final AppState state;
  final ViewMode mode;
  const ChannelsView(this.state, {required this.mode, super.key});
  @override
  State<ChannelsView> createState() => _ChannelsViewState();
}

class _ChannelsViewState extends State<ChannelsView> {
  final scroll = ScrollController();
  final List<Channel> items = [];
  List<String> groups = [];
  List<CustomGroup> customGroups = [];
  String query = '', group = '', customGroupId = '';
  bool more = true, busy = false;
  int gen = 0, ver = -1, favVer = -1;
  Timer? deb;

  AppState get s => widget.state;
  bool get favOnly => widget.mode == ViewMode.favorites;

  @override
  void initState() {
    super.initState();
    s.addListener(_onState);
    scroll.addListener(() {
      if (scroll.hasClients && scroll.position.pixels > scroll.position.maxScrollExtent - 600) _more();
    });
    _reload();
  }

  @override
  void dispose() {
    s.removeListener(_onState);
    deb?.cancel();
    scroll.dispose();
    super.dispose();
  }

  void _onState() {
    if (ver != s.dataVersion || (favOnly && favVer != s.favVersion)) _reload();
  }

  Future<void> _reload() async {
    ver = s.dataVersion;
    favVer = s.favVersion;
    gen++;
    items.clear();
    more = true;
    busy = false;
    final src = s.active?.id;
    if (src == null) {
      groups = [];
      customGroups = [];
      if (mounted) setState(() {});
      return;
    }
    final g = await Db.groups(src, profile: s.profile.id, favOnly: favOnly, kids: s.profile.kids);
    final cg = await Db.customGroups(s.profile.id);
    if (!mounted) return;
    groups = g;
    customGroups = cg;
    if (!groups.contains(group)) group = '';
    if (!customGroups.any((x) => x.id == customGroupId)) customGroupId = '';
    await _more();
  }

  Future<void> _more() async {
    final src = s.active?.id;
    if (src == null || busy || !more) return;
    busy = true;
    final myGen = gen;
    final raw = await Db.channels(
      src: src,
      profile: s.profile.id,
      kids: s.profile.kids,
      group: group,
      customGroupId: customGroupId,
      q: query,
      favOnly: favOnly,
      withEpg: widget.mode == ViewMode.guide,
      offset: items.length,
    );
    if (myGen != gen) return;
    busy = false;
    if (!mounted) return;
    final processed = s.groupVariants && widget.mode == ViewMode.live ? Db.groupVariants(raw) : raw;
    items.addAll(processed);
    more = raw.length >= Db.pageSize;
    setState(() {});
  }

  void _filterChanged() {
    gen++;
    items.clear();
    more = true;
    busy = false;
    if (scroll.hasClients) scroll.jumpTo(0);
    _more();
  }

  void _open(Channel c, int idx) {
    final page = widget.mode == ViewMode.guide
        ? ProgrammesScreen(s, c)
        : PlayerScreen(s, channelItem(c, ua: s.active?.effectiveUa ?? kUa, zapList: items, zapIndex: idx));
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _createCustomGroup() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yeni Özel Grup'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Grup adı')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Oluştur')),
        ],
      ),
    );
    ctrl.dispose();
    if (name != null && name.isNotEmpty) {
      await Db.createCustomGroup(s.profile.id, name);
      s.bumpData();
    }
  }

  Future<void> _channelActions(Channel c) async {
    final myGroups = await Db.customGroups(s.profile.id);
    final memberOf = await Db.channelGroupIds(c.url);
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          ListTile(
            leading: ChannelLogo(c.logo),
            title: Text(c.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(c.group),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: kCyan),
            title: const Text('Kanalı yeniden adlandır'),
            onTap: () async {
              Navigator.pop(ctx);
              final ctrl = TextEditingController(text: c.displayName);
              final val = await showDialog<String>(
                context: context,
                builder: (dctx) => AlertDialog(
                  title: const Text('Yeniden adlandır'),
                  content: TextField(controller: ctrl, autofocus: true),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('İptal')),
                    FilledButton(onPressed: () => Navigator.pop(dctx, ctrl.text.trim()), child: const Text('Kaydet')),
                  ],
                ),
              );
              ctrl.dispose();
              if (val != null) {
                await Db.setChannelOverride(s.profile.id, c.url, customName: val);
                s.bumpData();
              }
            },
          ),
          ListTile(
            leading: const Icon(Icons.visibility_off_outlined, color: kLive),
            title: const Text('Bu kanalı gizle'),
            onTap: () async {
              Navigator.pop(ctx);
              await Db.setChannelOverride(s.profile.id, c.url, hidden: true);
              s.bumpData();
            },
          ),
          ListTile(
            leading: const Icon(Icons.fiber_manual_record, color: kLive),
            title: const Text('Canlı yayını kaydet'),
            onTap: () {
              Navigator.pop(ctx);
              s.media.startRecording(
                channelName: c.displayName,
                url: c.url,
                title: c.nowTitle.isNotEmpty ? '${c.displayName} - ${c.nowTitle}' : c.displayName,
                userAgent: s.active?.effectiveUa ?? kUa,
              );
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kayıt başladı: ${c.displayName}')));
            },
          ),
          if (myGroups.isNotEmpty) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Text('ÖZEL GRUPLARIM', style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
            for (final g in myGroups)
              CheckboxListTile(
                title: Text(g.name),
                value: memberOf.contains(g.id),
                onChanged: (_) async {
                  await Db.toggleChannelInGroup(g.id, c.url);
                  if (ctx.mounted) Navigator.pop(ctx);
                  s.bumpData();
                },
              ),
          ],
        ],
      ),
    );
  }

  Widget _subtitle(Channel c) {
    if (widget.mode != ViewMode.guide) {
      return Text(c.nowTitle.isNotEmpty ? c.nowTitle : c.group, maxLines: 1, overflow: TextOverflow.ellipsis);
    }
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final prog =
        c.nowStop > c.nowStart ? ((now - c.nowStart) / (c.nowStop - c.nowStart)).clamp(0.0, 1.0).toDouble() : 0.0;
    final small = Theme.of(context).textTheme.bodySmall;
    if (c.nowTitle.isEmpty) return Text('Şu an program bilgisi yok', style: small);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${hm(c.nowStart)}  ${c.nowTitle}', maxLines: 1, overflow: TextOverflow.ellipsis),
      const SizedBox(height: 4),
      LinearProgressIndicator(value: prog, minHeight: 3, color: kCyan, borderRadius: BorderRadius.circular(2)),
      if (c.nextTitle.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Sonra: ${c.nextTitle}', style: small, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (s.sources.isEmpty) return const Center(child: Text('Ayarlar sekmesinden bir playlist ekleyin.'));
    return Column(children: [
      if (s.error != null)
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(s.error!, style: const TextStyle(color: kLive)),
        ),
      if (widget.mode == ViewMode.guide && s.epgStatus.isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.epgStatus, style: Theme.of(context).textTheme.bodySmall)),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 4),
        child: Row(children: [
          Expanded(
            child: TextField(
              decoration: searchDecoration('Kanal ara'),
              onChanged: (v) {
                deb?.cancel();
                deb = Timer(const Duration(milliseconds: 250), () {
                  query = v;
                  _filterChanged();
                });
              },
            ),
          ),
          if (widget.mode == ViewMode.live) ...[
            IconButton(
              tooltip: 'Özel grup oluştur',
              icon: const Icon(Icons.create_new_folder_outlined, color: kGold),
              onPressed: _createCustomGroup,
            ),
            IconButton(
              tooltip: 'Çoklu izleme',
              icon: const Icon(Icons.grid_view_rounded, color: kCyan),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MultiviewScreen(s))),
            ),
          ],
        ]),
      ),
      SizedBox(
        height: 50,
        child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: ChoiceChip(
              label: const Text('Tümü'),
              selected: group.isEmpty && customGroupId.isEmpty,
              onSelected: (_) {
                group = '';
                customGroupId = '';
                _filterChanged();
              },
            ),
          ),
          for (final cg in customGroups)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: ChoiceChip(
                avatar: const Icon(Icons.folder_special_rounded, size: 15, color: kGold),
                label: Text('${cg.name} (${cg.count})'),
                selected: customGroupId == cg.id,
                onSelected: (_) {
                  customGroupId = cg.id;
                  group = '';
                  _filterChanged();
                },
              ),
            ),
          for (final g in groups)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: ChoiceChip(
                label: Text(g),
                selected: group == g && customGroupId.isEmpty,
                onSelected: (_) {
                  group = g;
                  customGroupId = '';
                  _filterChanged();
                },
              ),
            ),
        ]),
      ),
      Expanded(
        child: items.isEmpty && !busy
            ? const Center(child: Text('Gösterilecek kanal yok.'))
            : ListView.builder(
                controller: scroll,
                itemCount: items.length + (more ? 1 : 0),
                itemBuilder: (context, i) {
                  if (i >= items.length) {
                    return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(color: kCyan)));
                  }
                  final c = items[i];
                  return ListTile(
                    leading: ChannelLogo(c.logo),
                    title: Row(children: [
                      Expanded(child: Text(c.displayName, maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (c.variants.length > 1) ...[
                        const SizedBox(width: 6),
                        TagPill('${c.variants.length} kaynak', color: kCyan.withValues(alpha: 0.14), textColor: kCyan),
                      ] else if (c.qualityTag.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        TagPill(c.qualityTag),
                      ],
                    ]),
                    subtitle: _subtitle(c),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        icon: Icon(c.fav ? Icons.favorite : Icons.favorite_border, color: c.fav ? kCyan : kTextMuted),
                        onPressed: () {
                          setState(() => c.fav = !c.fav);
                          s.toggleFav(c.url);
                        },
                      ),
                      if (widget.mode == ViewMode.live)
                        IconButton(
                          icon: const Icon(Icons.more_vert, size: 19, color: kTextMuted),
                          onPressed: () => _channelActions(c),
                        ),
                    ]),
                    onTap: () => _open(c, i),
                    onLongPress: widget.mode == ViewMode.live ? () => _channelActions(c) : null,
                  );
                },
              ),
      ),
    ]);
  }
}

class ProgrammesScreen extends StatefulWidget {
  final AppState state;
  final Channel channel;
  const ProgrammesScreen(this.state, this.channel, {super.key});
  @override
  State<ProgrammesScreen> createState() => _ProgrammesScreenState();
}

class _ProgrammesScreenState extends State<ProgrammesScreen> {
  List<Programme>? list;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    Db.programmes(widget.channel.sourceId, widget.channel.epgId, now - 2 * 86400, now + 7 * 86400).then((r) {
      if (mounted) setState(() => list = r);
    });
  }

  void _play() => Navigator.push(
      context, MaterialPageRoute(builder: (_) => PlayerScreen(widget.state, channelItem(widget.channel, ua: widget.state.active?.effectiveUa ?? kUa))));

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final l = list;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.channel.displayName),
        actions: [IconButton(icon: const Icon(Icons.play_circle_fill, color: kCyan), onPressed: _play)],
      ),
      body: l == null
          ? const Center(child: CircularProgressIndicator(color: kCyan))
          : l.isEmpty
              ? const Center(child: Text('Bu kanal için program bilgisi yok.'))
              : ListView.builder(
                  itemCount: l.length,
                  itemBuilder: (context, i) {
                    final p = l[i];
                    final isNow = p.start <= now && p.stop > now;
                    final isPast = p.stop <= now;
                    final isFuture = p.start > now;
                    final newDay = i == 0 || dayLabel(l[i - 1].start) != dayLabel(p.start);
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (newDay)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                          child: Text(dayLabel(p.start), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: kCyan)),
                        ),
                      ListTile(
                        leading: Text(hm(p.start), style: const TextStyle(fontWeight: FontWeight.bold)),
                        title: Text(p.title, style: TextStyle(color: isNow ? kCyan : null)),
                        subtitle: p.desc.isEmpty ? null : Text(p.desc, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: isNow
                            ? const Icon(Icons.play_arrow_rounded, color: kCyan)
                            : isFuture
                                ? IconButton(
                                    icon: const Icon(Icons.notifications_none_rounded, color: kGold),
                                    tooltip: 'Hatırlatıcı ekle',
                                    onPressed: () async {
                                      await Db.addReminder(widget.state.profile.id, widget.channel.displayName, widget.channel.url, p);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hatırlatıcı eklendi: ${p.title}')));
                                      }
                                    },
                                  )
                                : isPast && widget.channel.streamId.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.history_rounded, color: kTextSoft),
                                        tooltip: 'Catch-up izle',
                                        onPressed: () {
                                          final src = widget.state.active;
                                          if (src == null) return;
                                          final u = xtreamCatchupUrl(src, widget.channel, p);
                                          if (u == null) return;
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => PlayerScreen(
                                                widget.state,
                                                PlayItem(title: p.title, url: u, kind: 'catchup', userAgent: src.effectiveUa),
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : null,
                        onTap: isNow ? _play : null,
                      ),
                    ]);
                  },
                ),
    );
  }
}

// ===================== Film / Dizi Duvarı (+ Windows Sağ Detay Paneli) =====================
class VodView extends StatefulWidget {
  final AppState state;
  final String? kind; // 'movie' | 'series' | null
  final bool watchOnly;
  const VodView(this.state, {this.kind, this.watchOnly = false, super.key});
  @override
  State<VodView> createState() => _VodViewState();
}

class _VodViewState extends State<VodView> {
  final scroll = ScrollController();
  final List<MediaItem> items = [];
  List<String> cats = [];
  String query = '', cat = '', sort = 'default';
  bool more = true, busy = false;
  int gen = 0, ver = -1, vVer = -1, wVer = -1;
  Timer? deb;

  MediaItem? _selected;
  TmdbInfo? _tmdb;

  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    s.addListener(_onState);
    scroll.addListener(() {
      if (scroll.hasClients && scroll.position.pixels > scroll.position.maxScrollExtent - 600) _more();
    });
    _reload();
  }

  @override
  void dispose() {
    s.removeListener(_onState);
    deb?.cancel();
    scroll.dispose();
    super.dispose();
  }

  void _onState() {
    if (ver != s.dataVersion || vVer != s.vodVersion || (widget.watchOnly && wVer != s.watchVersion)) _reload();
  }

  Future<void> _reload() async {
    ver = s.dataVersion;
    vVer = s.vodVersion;
    wVer = s.watchVersion;
    gen++;
    items.clear();
    more = true;
    busy = false;
    final src = s.active?.id;
    if (src == null) {
      cats = [];
      if (mounted) setState(() {});
      return;
    }
    if (!widget.watchOnly) {
      final c = await Db.cats(src, widget.kind, kids: s.profile.kids);
      if (!mounted) return;
      cats = c;
      if (!cats.contains(cat)) cat = '';
    }
    await _more();
  }

  Future<void> _more() async {
    final src = s.active?.id;
    if (src == null || busy || !more) return;
    busy = true;
    final myGen = gen;
    final r = await Db.items(
      src: src,
      profile: s.profile.id,
      kind: widget.kind,
      cat: cat,
      q: query,
      watchOnly: widget.watchOnly,
      kids: s.profile.kids,
      sort: sort,
      offset: items.length,
    );
    if (myGen != gen) return;
    busy = false;
    if (!mounted) return;
    items.addAll(r);
    if (_selected == null && items.isNotEmpty) _selectItem(items.first);
    more = r.length >= Db.pageSize;
    setState(() {});
  }

  void _filterChanged() {
    gen++;
    items.clear();
    _selected = null;
    _tmdb = null;
    more = true;
    busy = false;
    if (scroll.hasClients) scroll.jumpTo(0);
    _more();
  }

  Future<void> _selectItem(MediaItem it) async {
    setState(() {
      _selected = it;
      _tmdb = null;
    });
    if (s.tmdbApiKey.isNotEmpty) {
      final info = await fetchTmdbInfo(s.tmdbApiKey, it.name, it.kind);
      if (mounted && _selected?.key == it.key) setState(() => _tmdb = info);
    }
  }

  void _open(MediaItem it) {
    final src = s.sources.where((x) => x.id == it.sourceId).firstOrNull ?? s.active;
    if (src == null) return;
    final Widget page = it.kind == 'series'
        ? SeriesScreen(s, it)
        : PlayerScreen(
            s,
            PlayItem(title: it.name, url: movieUrl(src, it), key: it.key, kind: 'movie', poster: it.poster, userAgent: src.effectiveUa),
          );
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  void _downloadMovie(MediaItem it) {
    final src = s.sources.where((x) => x.id == it.sourceId).firstOrNull ?? s.active;
    if (src == null || it.kind != 'movie') return;
    s.media.startDownload(
      PlayItem(title: it.name, url: movieUrl(src, it), key: it.key, kind: 'movie', poster: it.poster, userAgent: src.effectiveUa),
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İndirme başladı: ${it.name}')));
  }

  Widget _tile(MediaItem it, bool wide) {
    final sel = wide && _selected?.key == it.key;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => wide ? _selectItem(it) : _open(it),
      onDoubleTap: () => _open(it),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: sel ? kCyan : kBorderSoft, width: sel ? 2 : 1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(fit: StackFit.expand, children: [
              it.poster.isEmpty
                  ? Container(color: kSurface2, child: const Icon(Icons.movie_outlined, size: 36, color: kTextMuted))
                  : Image.network(it.poster, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: kSurface2, child: const Icon(Icons.movie_outlined, size: 36))),
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: Icon(it.watch ? Icons.bookmark : Icons.bookmark_border, color: it.watch ? kCyan : Colors.white),
                  onPressed: () {
                    setState(() => it.watch = !it.watch);
                    s.toggleWatch(it.key);
                  },
                ),
              ),
              Positioned(right: 6, bottom: 6, child: RatingBadge(it.rating)),
            ]),
          ),
        ),
        const SizedBox(height: 5),
        Text(it.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: kTextSoft)),
      ]),
    );
  }

  Widget _inspectorPanel(MediaItem it) => Container(
        width: 300,
        padding: const EdgeInsets.all(18),
        decoration: const BoxDecoration(
          color: kPanel,
          border: Border(left: BorderSide(color: kBorder)),
        ),
        child: ListView(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: AspectRatio(
              aspectRatio: 2 / 3,
              child: it.poster.isEmpty
                  ? Container(color: kSurface2, child: const Icon(Icons.movie_outlined, size: 48))
                  : Image.network(it.poster, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: kSurface2, child: const Icon(Icons.movie_outlined, size: 48))),
            ),
          ),
          const SizedBox(height: 14),
          Text(it.name, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 6, children: [
            if (it.cat.isNotEmpty) TagPill(it.cat),
            RatingBadge(_tmdb?.rating.isNotEmpty == true ? _tmdb!.rating : it.rating),
            if (_tmdb?.releaseDate.isNotEmpty == true) TagPill(_tmdb!.releaseDate),
          ]),
          if (_tmdb?.overview.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(_tmdb!.overview, style: const TextStyle(color: kTextSoft, fontSize: 13, height: 1.45)),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _open(it),
            icon: const Icon(Icons.play_arrow_rounded),
            label: Text(it.kind == 'series' ? 'Bölümleri Gör' : 'Şimdi İzle'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () {
              setState(() => it.watch = !it.watch);
              s.toggleWatch(it.key);
            },
            icon: Icon(it.watch ? Icons.bookmark : Icons.bookmark_border, color: kCyan),
            label: Text(it.watch ? 'İzleme Listesinde' : 'İzleme Listesine Ekle'),
          ),
          if (it.kind == 'movie') ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => _downloadMovie(it),
              icon: const Icon(Icons.download_rounded, color: kGold),
              label: const Text('Çevrimdışı İndir'),
            ),
          ],
        ]),
      );

  @override
  Widget build(BuildContext context) {
    if (s.sources.isEmpty) return const Center(child: Text('Ayarlar sekmesinden bir playlist ekleyin.'));
    final wide = MediaQuery.of(context).size.width >= 1020 && !widget.watchOnly;

    final gridArea = Column(children: [
      if (s.vodStatus.isNotEmpty)
        Padding(padding: const EdgeInsets.only(top: 8), child: Text(s.vodStatus, style: Theme.of(context).textTheme.bodySmall)),
      if (!widget.watchOnly) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(children: [
            Expanded(
              child: TextField(
                decoration: searchDecoration(widget.kind == 'series' ? 'Dizi ara' : 'Film ara'),
                onChanged: (v) {
                  deb?.cancel();
                  deb = Timer(const Duration(milliseconds: 250), () {
                    query = v;
                    _filterChanged();
                  });
                },
              ),
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort_rounded, color: kCyan),
              tooltip: 'Sırala',
              onSelected: (v) {
                sort = v;
                _filterChanged();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'default', child: Text('Varsayılan')),
                PopupMenuItem(value: 'az', child: Text('Ada göre (A-Z)')),
                PopupMenuItem(value: 'rating', child: Text('Puana göre')),
              ],
            ),
          ]),
        ),
        SizedBox(
          height: 50,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
            for (final c in ['', ...cats])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                child: ChoiceChip(
                  label: Text(c.isEmpty ? 'Tümü' : c),
                  selected: cat == c,
                  onSelected: (_) {
                    cat = c;
                    _filterChanged();
                  },
                ),
              ),
          ]),
        ),
      ],
      Expanded(
        child: items.isEmpty && !busy
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(widget.watchOnly
                      ? 'İzleme listeniz boş. Bir filmde yer imi simgesine dokunun.'
                      : 'Bu bölümde içerik yok. Film ve diziler Xtream / Jellyfin kaynaklarından gelir.'),
                ),
              )
            : GridView.builder(
                controller: scroll,
                padding: const EdgeInsets.all(14),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 155,
                  childAspectRatio: 0.56,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                ),
                itemCount: items.length,
                itemBuilder: (_, i) => _tile(items[i], wide),
              ),
      ),
    ]);

    if (!wide) return gridArea;
    return Row(children: [
      Expanded(child: gridArea),
      if (_selected != null) _inspectorPanel(_selected!),
    ]);
  }
}

class SeriesScreen extends StatefulWidget {
  final AppState state;
  final MediaItem series;
  const SeriesScreen(this.state, this.series, {super.key});
  @override
  State<SeriesScreen> createState() => _SeriesScreenState();
}

class _SeriesScreenState extends State<SeriesScreen> {
  late final Future<Map<int, List<Episode>>> future;

  @override
  void initState() {
    super.initState();
    final src = widget.state.sources.where((x) => x.id == widget.series.sourceId).firstOrNull ?? widget.state.active;
    future = src == null ? Future.value(<int, List<Episode>>{}) : fetchEpisodes(src, widget.series);
  }

  @override
  Widget build(BuildContext context) {
    final it = widget.series;
    final ua = widget.state.active?.effectiveUa ?? kUa;
    return Scaffold(
      appBar: AppBar(title: Text(it.name)),
      body: FutureBuilder<Map<int, List<Episode>>>(
        future: future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) return const Center(child: CircularProgressIndicator(color: kCyan));
          if (snap.hasError || (snap.data ?? {}).isEmpty) return const Center(child: Text('Bölümler alınamadı.'));
          final seasons = snap.data!.keys.toList()..sort();
          return ListView(children: [
            for (final sn in seasons)
              ExpansionTile(
                initiallyExpanded: seasons.length == 1,
                title: Text('Sezon $sn', style: const TextStyle(fontWeight: FontWeight.w700, color: kCyan)),
                children: [
                  for (final e in snap.data![sn]!)
                    ListTile(
                      leading: TagPill('B${e.number}'),
                      title: Text(e.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: const Icon(Icons.download_outlined, color: kGold, size: 20),
                          tooltip: 'Bölümü indir',
                          onPressed: () {
                            widget.state.media.startDownload(PlayItem(
                              title: '${it.name} S${sn.toString().padLeft(2, '0')}E${e.number.toString().padLeft(2, '0')}',
                              url: e.url,
                              key: '${it.key}|$sn|${e.number}',
                              kind: 'series',
                              poster: it.poster,
                              userAgent: ua,
                            ));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İndiriliyor: ${e.title}')));
                          },
                        ),
                        const Icon(Icons.play_arrow_rounded, color: kCyan),
                      ]),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PlayerScreen(
                            widget.state,
                            PlayItem(
                              title: '${it.name}  S${sn.toString().padLeft(2, '0')}E${e.number.toString().padLeft(2, '0')}',
                              url: e.url,
                              key: '${it.key}|$sn|${e.number}',
                              kind: 'series',
                              poster: it.poster,
                              userAgent: ua,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ]);
        },
      ),
    );
  }
}

// ===================== Kitaplık (Devam Et, İzleme Listesi, Favoriler, İndirilenler, Kayıtlar) =====================
class LibraryView extends StatelessWidget {
  final AppState s;
  const LibraryView(this.s, {super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 5,
        child: Column(children: [
          const TabBar(
            isScrollable: true,
            indicatorColor: kCyan,
            labelColor: kCyan,
            unselectedLabelColor: kTextMuted,
            tabs: [
              Tab(text: 'Devam Et'),
              Tab(text: 'İzleme Listesi'),
              Tab(text: 'Favori Kanallar'),
              Tab(text: 'İndirilenler'),
              Tab(text: 'Kayıtlarım (DVR)'),
            ],
          ),
          Expanded(
            child: TabBarView(children: [
              _ContinueList(s),
              VodView(s, watchOnly: true),
              ChannelsView(s, mode: ViewMode.favorites),
              _DownloadsTab(s),
              _RecordingsTab(s),
            ]),
          ),
        ]),
      );
}

class _ContinueList extends StatefulWidget {
  final AppState s;
  const _ContinueList(this.s);
  @override
  State<_ContinueList> createState() => _ContinueListState();
}

class _ContinueListState extends State<_ContinueList> {
  List<HistoryEntry> list = [];
  int hv = -1, dv = -1;
  AppState get s => widget.s;

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
    if (hv != s.histVersion || dv != s.dataVersion) _load();
  }

  Future<void> _load() async {
    hv = s.histVersion;
    dv = s.dataVersion;
    final r = await Db.continueWatching(s.profile.id);
    if (mounted) setState(() => list = r);
  }

  @override
  Widget build(BuildContext context) {
    if (list.isEmpty) return const Center(child: Text('Yarım bıraktığınız film ya da bölüm yok.'));
    return ListView(children: [
      for (final h in list)
        ListTile(
          leading: SizedBox(
            width: 44,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: h.poster.isEmpty
                  ? const Icon(Icons.movie_outlined)
                  : Image.network(h.poster, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.movie_outlined)),
            ),
          ),
          title: Text(h.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: LinearProgressIndicator(value: (h.pos / h.dur).clamp(0.0, 1.0).toDouble(), minHeight: 3, color: kCyan),
          ),
          trailing: const Icon(Icons.play_arrow_rounded, color: kCyan),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(s, h.toPlay()))),
        ),
    ]);
  }
}

class _DownloadsTab extends StatefulWidget {
  final AppState s;
  const _DownloadsTab(this.s);
  @override
  State<_DownloadsTab> createState() => _DownloadsTabState();
}

class _DownloadsTabState extends State<_DownloadsTab> {
  List<DownloadItem> list = [];
  int mv = -1;
  AppState get s => widget.s;

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
    if (mv != s.mediaVersion) _load();
  }

  Future<void> _load() async {
    mv = s.mediaVersion;
    final r = await Db.downloads();
    if (mounted) setState(() => list = r);
  }

  @override
  Widget build(BuildContext context) {
    final active = s.media.activeDownloads.values.toList();
    if (active.isEmpty && list.isEmpty) {
      return const Center(child: Text('Henüz çevrimdışı indirme yok. Film veya bölüm sayfasından indirebilirsiniz.'));
    }
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final a in active)
        Card(
          child: ListTile(
            leading: const Icon(Icons.downloading_rounded, color: kCyan),
            title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 6),
              LinearProgressIndicator(value: a.progress, color: kCyan),
              const SizedBox(height: 4),
              Text('${formatBytes(a.receivedBytes)}${a.totalBytes > 0 ? ' / ${formatBytes(a.totalBytes)}' : ''}'),
            ]),
            trailing: IconButton(icon: const Icon(Icons.close, color: kLive), onPressed: a.cancel),
          ),
        ),
      for (final d in list)
        ListTile(
          leading: const Icon(Icons.offline_pin_rounded, color: kOk),
          title: Text(d.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(formatBytes(d.sizeBytes)),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final f = File(d.filePath);
                if (await f.exists()) await f.delete();
                await Db.deleteDownload(d.key);
                _load();
              },
            ),
            const Icon(Icons.play_arrow_rounded, color: kCyan),
          ]),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlayerScreen(s, PlayItem(title: d.title, url: d.filePath, key: d.key, kind: 'offline'))),
          ),
        ),
    ]);
  }
}

class _RecordingsTab extends StatefulWidget {
  final AppState s;
  const _RecordingsTab(this.s);
  @override
  State<_RecordingsTab> createState() => _RecordingsTabState();
}

class _RecordingsTabState extends State<_RecordingsTab> {
  List<RecordingItem> list = [];
  int mv = -1;
  AppState get s => widget.s;

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
    if (mv != s.mediaVersion) _load();
  }

  Future<void> _load() async {
    mv = s.mediaVersion;
    final r = await Db.recordings();
    if (mounted) setState(() => list = r);
  }

  @override
  Widget build(BuildContext context) {
    final active = s.media.activeRecordings.values.toList();
    if (active.isEmpty && list.isEmpty) {
      return const Center(child: Text('Henüz DVR kaydı yok. Oynatıcıdan veya TV Rehberinden kayıt başlatabilirsiniz.'));
    }
    return ListView(padding: const EdgeInsets.all(12), children: [
      for (final a in active)
        Card(
          child: ListTile(
            leading: const Icon(Icons.fiber_manual_record, color: kLive),
            title: Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('${a.channelName} · ${formatDuration(a.elapsedSec)} · ${formatBytes(a.bytesWritten)}'),
            trailing: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kLive, foregroundColor: Colors.white),
              onPressed: () => s.media.stopRecording(a.id),
              child: const Text('Durdur'),
            ),
          ),
        ),
      for (final r in list)
        ListTile(
          leading: const Icon(Icons.video_file_rounded, color: kGold),
          title: Text(r.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${r.channelName} · ${formatDuration(r.durationSec)} · ${formatBytes(r.sizeBytes)}'),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final f = File(r.filePath);
                if (await f.exists()) await f.delete();
                await Db.deleteRecording(r.id);
                _load();
              },
            ),
            const Icon(Icons.play_arrow_rounded, color: kCyan),
          ]),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlayerScreen(s, PlayItem(title: r.title, url: r.filePath, key: r.id, kind: 'recording'))),
          ),
        ),
    ]);
  }
}
