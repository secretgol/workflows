import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'db.dart';
import 'models.dart';
import 'player.dart';
import 'store.dart';
import 'theme.dart';
import 'util.dart';
import 'views.dart';
import 'xtream.dart';

/// IPTV Deck tarzı 14 Günlük TV Rehberi (EPG):
/// - Geniş ekranda (Windows): Üstte canlı mini önizleme + program detay kartı, altta yatay zaman çizelgesi + cyan ŞİMDİ çizgisi.
/// - Mobil ekranda (iOS): Gün seçici haplar + dikey kanal rehberi.
class EpgGridView extends StatefulWidget {
  final AppState state;
  const EpgGridView(this.state, {super.key});
  @override
  State<EpgGridView> createState() => _EpgGridViewState();
}

class _EpgGridViewState extends State<EpgGridView> {
  static const double _pxPerMin = 4.2;
  static const double _rowHeight = 58;
  static const double _chanColW = 190;

  final ScrollController _hScroll = ScrollController();
  List<Channel> _channels = [];
  Map<String, List<Programme>> _progsByEpg = {};
  int _dayOffset = 0; // -3 .. +6
  Channel? _selectedChan;
  Programme? _selectedProg;
  bool _busy = false;
  int _dv = -1;

  // Mini preview player (yalnızca geniş ekranda kullanıcı kanal seçince açılır)
  Player? _previewPlayer;
  VideoController? _previewCtrl;
  String _previewUrl = '';

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
    _hScroll.dispose();
    _previewPlayer?.dispose();
    super.dispose();
  }

  void _onState() {
    if (_dv != s.dataVersion) _load();
  }

  DateTime get _dayStart {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day).add(Duration(days: _dayOffset));
  }

  Future<void> _load() async {
    _dv = s.dataVersion;
    final src = s.active?.id;
    if (src == null) {
      setState(() {
        _channels = [];
        _progsByEpg = {};
      });
      return;
    }
    setState(() => _busy = true);
    final list = await Db.channels(
      src: src,
      profile: s.profile.id,
      kids: s.profile.kids,
      withEpg: true,
      limit: 80,
    );
    final from = _dayStart.millisecondsSinceEpoch ~/ 1000;
    final to = from + 86400;
    final map = await Db.programmesBatch(src, [for (final c in list) c.epgId], from, to);
    if (!mounted) return;
    setState(() {
      _channels = list;
      _progsByEpg = map;
      _busy = false;
      if (_selectedChan == null && list.isNotEmpty) {
        _selectedChan = list.first;
        final ps = map[list.first.epgId] ?? const [];
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        _selectedProg = ps.where((p) => p.start <= now && p.stop > now).firstOrNull ?? (ps.isNotEmpty ? ps.first : null);
      }
    });
    if (_dayOffset == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _jumpToNow());
    }
  }

  void _jumpToNow() {
    if (!_hScroll.hasClients) return;
    final now = DateTime.now();
    final mins = now.hour * 60 + now.minute;
    final target = (mins * _pxPerMin - 180).clamp(0.0, _hScroll.position.maxScrollExtent);
    _hScroll.jumpTo(target);
  }

  Future<void> _openPreview(Channel c) async {
    if (_previewUrl == c.url) return;
    _previewUrl = c.url;
    _previewPlayer ??= Player();
    _previewCtrl ??= VideoController(_previewPlayer!);
    await _previewPlayer!.setVolume(60);
    await _previewPlayer!.open(Media(c.url, httpHeaders: {'User-Agent': s.active?.effectiveUa ?? kUa}));
    if (mounted) setState(() {});
  }

  void _playLive(Channel c) {
    _previewPlayer?.pause();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(s, channelItem(c, ua: s.active?.effectiveUa ?? kUa)),
      ),
    );
  }

  void _playCatchup(Channel c, Programme p) {
    final src = s.active;
    if (src == null) return;
    final url = xtreamCatchupUrl(src, c, p);
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu kanal için catch-up bilgisi yok.')));
      return;
    }
    _previewPlayer?.pause();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          s,
          PlayItem(
            title: '${c.displayName} · ${p.title}',
            url: url,
            isLive: false,
            kind: 'catchup',
            subtitle: '${hm(p.start)} - ${hm(p.stop)}',
            userAgent: src.effectiveUa,
          ),
        ),
      ),
    );
  }

  Future<void> _setReminder(Channel c, Programme p) async {
    await Db.addReminder(s.profile.id, c.displayName, c.url, p);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hatırlatıcı eklendi: ${p.title} (${hm(p.start)})')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (s.sources.isEmpty) return const Center(child: Text('Ayarlar sekmesinden bir playlist ekleyin.'));
    final wide = MediaQuery.of(context).size.width >= 900;
    if (!wide) {
      return ChannelsView(s, mode: ViewMode.guide);
    }

    final from = _dayStart.millisecondsSinceEpoch ~/ 1000;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final totalW = 24 * 60 * _pxPerMin;
    final nowX = _dayOffset == 0 ? ((now - from) / 60.0) * _pxPerMin : -1.0;

    return Column(children: [
      // Üst panel: Mini önizleme + seçili program detayı
      Container(
        height: 196,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(
          color: kPanel,
          border: Border(bottom: BorderSide(color: kBorder)),
        ),
        child: Row(children: [
          // Sol mini canlı önizleme
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
              ),
              clipBehavior: Clip.antiAlias,
              child: _previewCtrl != null
                  ? Stack(fit: StackFit.expand, children: [
                      Video(controller: _previewCtrl!, controls: NoVideoControls),
                      const Positioned(left: 8, top: 8, child: LiveBadge()),
                    ])
                  : InkWell(
                      onTap: _selectedChan != null ? () => _openPreview(_selectedChan!) : null,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.play_circle_outline_rounded, size: 42, color: kCyan),
                          SizedBox(height: 6),
                          Text('Önizleme için tıklayın', style: TextStyle(color: kTextMuted, fontSize: 12)),
                        ],
                      ),
                    ),
            ),
          ),
          const SizedBox(width: 18),
          // Sağ program detayları ve aksiyonlar
          Expanded(
            child: _selectedChan == null
                ? const Center(child: Text('Program seçin', style: TextStyle(color: kTextMuted)))
                : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Text(_selectedChan!.displayName, style: const TextStyle(color: kCyan, fontWeight: FontWeight.w700)),
                      if (_selectedProg != null) ...[
                        const SizedBox(width: 10),
                        TagPill('${hm(_selectedProg!.start)} – ${hm(_selectedProg!.stop)}'),
                      ],
                      const Spacer(),
                      if (s.epgStatus.isNotEmpty) Text(s.epgStatus, style: const TextStyle(color: kTextMuted, fontSize: 11.5)),
                    ]),
                    const SizedBox(height: 6),
                    Text(
                      _selectedProg?.title ?? 'Program bilgisi yok',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Expanded(
                      child: Text(
                        _selectedProg?.desc.isNotEmpty == true ? _selectedProg!.desc : 'Açıklama bulunmuyor.',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kTextSoft, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(spacing: 8, children: [
                      FilledButton.icon(
                        onPressed: () => _playLive(_selectedChan!),
                        icon: const Icon(Icons.play_arrow_rounded, size: 18),
                        label: const Text('Canlı İzle'),
                      ),
                      if (_selectedProg != null && _selectedProg!.stop <= now && _selectedChan!.streamId.isNotEmpty)
                        OutlinedButton.icon(
                          onPressed: () => _playCatchup(_selectedChan!, _selectedProg!),
                          icon: const Icon(Icons.history_rounded, size: 18),
                          label: const Text('Catch-up İzle'),
                        ),
                      if (_selectedProg != null && _selectedProg!.start > now)
                        OutlinedButton.icon(
                          onPressed: () => _setReminder(_selectedChan!, _selectedProg!),
                          icon: const Icon(Icons.notifications_active_outlined, size: 18),
                          label: const Text('Hatırlat'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () {
                          s.media.startRecording(
                            channelName: _selectedChan!.displayName,
                            url: _selectedChan!.url,
                            title: _selectedProg?.title ?? _selectedChan!.displayName,
                            userAgent: s.active?.effectiveUa ?? kUa,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Kayıt başladı: ${_selectedChan!.displayName}')),
                          );
                        },
                        icon: const Icon(Icons.fiber_manual_record, size: 16, color: kLive),
                        label: const Text('Kaydet'),
                      ),
                    ]),
                  ]),
          ),
        ]),
      ),

      // Gün seçici şeridi
      Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        color: kBg,
        child: Row(children: [
          for (var d = -2; d <= 5; d++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: Text(dayLabel(DateTime.now().add(Duration(days: d)).millisecondsSinceEpoch ~/ 1000)),
                selected: _dayOffset == d,
                onSelected: (_) {
                  _dayOffset = d;
                  _load();
                },
              ),
            ),
          const Spacer(),
          if (_dayOffset == 0)
            TextButton.icon(
              onPressed: _jumpToNow,
              icon: const Icon(Icons.schedule, size: 16, color: kCyan),
              label: const Text('ŞİMDİ', style: TextStyle(color: kCyan, fontWeight: FontWeight.w700)),
            ),
        ]),
      ),

      // Zaman çizelgesi ızgarası
      Expanded(
        child: _busy
            ? const Center(child: CircularProgressIndicator(color: kCyan))
            : _channels.isEmpty
                ? const Center(child: Text('EPG eşleşen kanal bulunamadı. Ayarlardan EPG adresini kontrol edin.'))
                : Row(children: [
                    // Sol sabit kanal sütunu
                    SizedBox(
                      width: _chanColW,
                      child: Column(children: [
                        Container(
                          height: 32,
                          alignment: Alignment.centerLeft,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: const BoxDecoration(
                            color: kPanel,
                            border: Border(bottom: BorderSide(color: kBorder), right: BorderSide(color: kBorder)),
                          ),
                          child: const Text('KANALLAR', style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemExtent: _rowHeight,
                            itemCount: _channels.length,
                            itemBuilder: (_, i) {
                              final c = _channels[i];
                              final sel = _selectedChan?.url == c.url;
                              return InkWell(
                                onTap: () {
                                  setState(() => _selectedChan = c);
                                  _openPreview(c);
                                },
                                onDoubleTap: () => _playLive(c),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: sel ? kCyan.withValues(alpha: 0.10) : kPanel,
                                    border: const Border(bottom: BorderSide(color: kBorderSoft), right: BorderSide(color: kBorder)),
                                  ),
                                  child: Row(children: [
                                    ChannelLogo(c.logo),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        c.displayName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 12.5, fontWeight: sel ? FontWeight.w700 : FontWeight.w500),
                                      ),
                                    ),
                                  ]),
                                ),
                              );
                            },
                          ),
                        ),
                      ]),
                    ),

                    // Sağ yatay kaydırılabilir zaman çizelgesi
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _hScroll,
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: totalW,
                          child: Stack(children: [
                            Column(children: [
                              // Saat cetveli
                              Container(
                                height: 32,
                                decoration: const BoxDecoration(
                                  color: kPanel,
                                  border: Border(bottom: BorderSide(color: kBorder)),
                                ),
                                child: Stack(children: [
                                  for (var h = 0; h < 24; h++)
                                    Positioned(
                                      left: h * 60 * _pxPerMin + 6,
                                      top: 7,
                                      child: Text(
                                        '${h.toString().padLeft(2, '0')}:00',
                                        style: const TextStyle(color: kTextMuted, fontSize: 11.5, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                ]),
                              ),
                              // Kanal satırları
                              Expanded(
                                child: ListView.builder(
                                  itemExtent: _rowHeight,
                                  itemCount: _channels.length,
                                  itemBuilder: (_, i) {
                                    final c = _channels[i];
                                    final progs = _progsByEpg[c.epgId] ?? const [];
                                    return Container(
                                      decoration: const BoxDecoration(
                                        border: Border(bottom: BorderSide(color: kBorderSoft)),
                                      ),
                                      child: Stack(children: [
                                        for (final p in progs) _progCell(c, p, from, now),
                                      ]),
                                    );
                                  },
                                ),
                              ),
                            ]),
                            // ŞİMDİ cyan dikey çizgi
                            if (nowX >= 0 && nowX <= totalW)
                              Positioned(
                                left: nowX,
                                top: 0,
                                bottom: 0,
                                child: IgnorePointer(
                                  child: Container(width: 2, color: kCyan),
                                ),
                              ),
                          ]),
                        ),
                      ),
                    ),
                  ]),
      ),
    ]);
  }

  Widget _progCell(Channel c, Programme p, int dayStart, int now) {
    final sSec = p.start < dayStart ? dayStart : p.start;
    final eSec = p.stop > dayStart + 86400 ? dayStart + 86400 : p.stop;
    final left = ((sSec - dayStart) / 60.0) * _pxPerMin;
    final w = (((eSec - sSec) / 60.0) * _pxPerMin).clamp(24.0, 2000.0);
    final isNow = p.start <= now && p.stop > now;
    final isSel = _selectedChan?.url == c.url && _selectedProg == p;

    return Positioned(
      left: left,
      top: 4,
      bottom: 4,
      width: w - 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () {
          setState(() {
            _selectedChan = c;
            _selectedProg = p;
          });
          _openPreview(c);
        },
        onDoubleTap: () => _playLive(c),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: isSel
                ? kCyan.withValues(alpha: 0.22)
                : isNow
                    ? const Color(0xFF152130)
                    : kSurface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSel ? kCyan : (isNow ? kCyan.withValues(alpha: 0.45) : kBorderSoft),
              width: isSel ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                p.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, fontWeight: isNow || isSel ? FontWeight.w700 : FontWeight.w500),
              ),
              Text(
                '${hm(p.start)} - ${hm(p.stop)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: kTextMuted, fontSize: 10.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
