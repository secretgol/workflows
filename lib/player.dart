import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'db.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'util.dart';

/// IPTV Deck tarzı tam ekran oynatıcı:
/// Varyant seçici (4K/FHD/HD), kanal zap, ±10sn sarma, uyku zamanlayıcı,
/// harici altyazı URL, canlı kayıt, en-boy oranı ve Windows klavye kısayolları.
class PlayerScreen extends StatefulWidget {
  final AppState state;
  final PlayItem item;
  const PlayerScreen(this.state, this.item, {super.key});
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Player player = Player();
  late final VideoController controller = VideoController(player);
  final FocusNode _focus = FocusNode();

  late PlayItem _cur;
  late int _zapIdx;
  int _variantIdx = 0;

  StreamSubscription<String>? _errSub;
  StreamSubscription<bool>? _playSub;
  Timer? _saveTimer;
  Timer? _sleepTimer;
  int _sleepMinutes = 0;
  double _rate = 1.0;
  BoxFit _fit = BoxFit.contain;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cur = widget.item;
    _zapIdx = widget.item.zapIndex;
    _errSub = player.stream.error.listen((e) {
      final low = e.toLowerCase();
      if (e.isEmpty || low.contains('force-seekable') || low.contains('cannot seek')) return;
      if (mounted) setState(() => _error = e);
    });
    _playSub = player.stream.playing.listen((isPlaying) {
      if (isPlaying && _error != null && mounted) setState(() => _error = null);
    });
    _start();
  }

  Future<void> _start({String? overrideUrl}) async {
    if (mounted && _error != null) setState(() => _error = null);
    Duration? start;
    if (!_cur.isLive && overrideUrl == null) {
      final h = await Db.progress(widget.state.profile.id, _cur.key);
      if (h != null && h.pos > 10 && (h.dur == 0 || h.pos < h.dur * 0.95)) start = Duration(seconds: h.pos);
    }
    if (!mounted) return;
    final url = overrideUrl ?? _cur.url;
    await player.open(Media(url, start: start, httpHeaders: {'User-Agent': _cur.userAgent}));
    _saveTimer?.cancel();
    if (!_cur.isLive) {
      _saveTimer = Timer.periodic(const Duration(seconds: 10), (_) => _save());
    }
  }

  void _save() {
    if (_cur.isLive) return;
    final pos = player.state.position.inSeconds;
    final dur = player.state.duration.inSeconds;
    if (dur > 0 && pos > 0) {
      Db.saveProgress(widget.state.profile.id, _cur, pos, dur).then((_) => widget.state.bumpHistory());
    }
  }

  void _zap(int delta) {
    final list = _cur.zapList;
    if (list.isEmpty || _zapIdx < 0) return;
    final next = (_zapIdx + delta) % list.length;
    final c = list[next < 0 ? list.length - 1 : next];
    setState(() {
      _zapIdx = next < 0 ? list.length - 1 : next;
      _variantIdx = 0;
      _cur = PlayItem(
        title: c.displayName,
        url: c.url,
        isLive: true,
        key: c.url,
        kind: 'live',
        subtitle: c.nowTitle,
        userAgent: _cur.userAgent,
        variants: c.variants,
        zapList: list,
        zapIndex: _zapIdx,
      );
    });
    _start();
  }

  void _switchVariant(int idx) {
    if (idx < 0 || idx >= _cur.variants.length) return;
    setState(() => _variantIdx = idx);
    _start(overrideUrl: _cur.variants[idx].url);
  }

  void _seekBy(int sec) {
    if (_cur.isLive) return;
    final target = player.state.position + Duration(seconds: sec);
    player.seek(target.isNegative ? Duration.zero : target);
  }

  void _toggleFit() {
    setState(() {
      _fit = switch (_fit) {
        BoxFit.contain => BoxFit.cover,
        BoxFit.cover => BoxFit.fill,
        _ => BoxFit.contain,
      };
    });
  }

  void _setSleepTimer(int mins) {
    _sleepTimer?.cancel();
    setState(() => _sleepMinutes = mins);
    if (mins <= 0) return;
    _sleepTimer = Timer(Duration(minutes: mins), () {
      if (mounted) Navigator.pop(context);
    });
  }

  void _toggleRecord() {
    final mm = widget.state.media;
    if (mm.isRecordingChannel(_cur.title)) {
      mm.stopRecordingForChannel(_cur.title);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kayıt durduruldu.')));
    } else {
      final url = _cur.variants.isNotEmpty ? _cur.variants[_variantIdx].url : _cur.url;
      mm.startRecording(
        channelName: _cur.title,
        url: url,
        title: _cur.subtitle.isNotEmpty ? '${_cur.title} - ${_cur.subtitle}' : _cur.title,
        userAgent: _cur.userAgent,
      );
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kayıt başladı: ${_cur.title}')));
    }
    setState(() {});
  }

  Future<void> _addExternalSubtitle() async {
    final ctrl = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Harici Altyazı URL'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'https://.../altyazi.srt veya .vtt'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Yükle')),
        ],
      ),
    );
    ctrl.dispose();
    if (url != null && url.isNotEmpty) {
      await player.setSubtitleTrack(SubtitleTrack.uri(url));
    }
  }

  @override
  void dispose() {
    _errSub?.cancel();
    _playSub?.cancel();
    _saveTimer?.cancel();
    _sleepTimer?.cancel();
    _focus.dispose();
    _save();
    player.dispose();
    super.dispose();
  }

  String _name(String? title, String? lang, String id) {
    if (id == 'auto') return 'Otomatik';
    if (id == 'no') return 'Kapalı';
    final label = [if (title != null && title.isNotEmpty) title, if (lang != null && lang.isNotEmpty) lang].join(' · ');
    return label.isEmpty ? 'Parça $id' : label;
  }

  void _showOptionsSheet() {
    final t = player.state.tracks;
    final cur = player.state.track;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          if (_cur.variants.length > 1) ...[
            const ListTile(title: Text('Kalite / Kaynak Varyantı', style: TextStyle(fontWeight: FontWeight.bold, color: kCyan))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (var i = 0; i < _cur.variants.length; i++)
                  ChoiceChip(
                    label: Text(_cur.variants[i].label),
                    selected: _variantIdx == i,
                    onSelected: (_) {
                      Navigator.pop(ctx);
                      _switchVariant(i);
                    },
                  ),
              ]),
            ),
            const Divider(),
          ],
          const ListTile(title: Text('Ses Parçaları', style: TextStyle(fontWeight: FontWeight.bold, color: kCyan))),
          for (final a in t.audio)
            ListTile(
              title: Text(_name(a.title, a.language, a.id)),
              trailing: a == cur.audio ? const Icon(Icons.check, color: kCyan) : null,
              onTap: () {
                player.setAudioTrack(a);
                Navigator.pop(ctx);
              },
            ),
          const ListTile(title: Text('Altyazılar', style: TextStyle(fontWeight: FontWeight.bold, color: kCyan))),
          for (final s in t.subtitle)
            ListTile(
              title: Text(_name(s.title, s.language, s.id)),
              trailing: s == cur.subtitle ? const Icon(Icons.check, color: kCyan) : null,
              onTap: () {
                player.setSubtitleTrack(s);
                Navigator.pop(ctx);
              },
            ),
          ListTile(
            leading: const Icon(Icons.link, color: kGold),
            title: const Text('Harici altyazı URL ekle (.srt / .vtt)'),
            onTap: () {
              Navigator.pop(ctx);
              _addExternalSubtitle();
            },
          ),
          const Divider(),
          const ListTile(title: Text('Uyku Zamanlayıcı', style: TextStyle(fontWeight: FontWeight.bold, color: kCyan))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(spacing: 8, children: [
              for (final m in [0, 15, 30, 60, 90])
                ChoiceChip(
                  label: Text(m == 0 ? 'Kapalı' : '$m dk'),
                  selected: _sleepMinutes == m,
                  onSelected: (_) {
                    _setSleepTimer(m);
                    Navigator.pop(ctx);
                  },
                ),
            ]),
          ),
          if (!_cur.isLive) ...[
            const Divider(),
            const ListTile(title: Text('Oynatma Hızı', style: TextStyle(fontWeight: FontWeight.bold, color: kCyan))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(spacing: 8, children: [
                for (final r in [0.5, 0.75, 1.0, 1.25, 1.5, 2.0])
                  ChoiceChip(
                    label: Text('${r}x'),
                    selected: _rate == r,
                    onSelected: (_) {
                      setState(() => _rate = r);
                      player.setRate(r);
                      Navigator.pop(ctx);
                    },
                  ),
              ]),
            ),
          ],
        ],
      ),
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent ev) {
    if (ev is! KeyDownEvent) return KeyEventResult.ignored;
    final k = ev.logicalKey;
    if (k == LogicalKeyboardKey.space) {
      player.playOrPause();
      return KeyEventResult.handled;
    } else if (k == LogicalKeyboardKey.arrowRight) {
      _seekBy(10);
      return KeyEventResult.handled;
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      _seekBy(-10);
      return KeyEventResult.handled;
    } else if (k == LogicalKeyboardKey.arrowUp && _cur.isLive) {
      _zap(-1);
      return KeyEventResult.handled;
    } else if (k == LogicalKeyboardKey.arrowDown && _cur.isLive) {
      _zap(1);
      return KeyEventResult.handled;
    } else if (k == LogicalKeyboardKey.keyM) {
      player.setVolume(player.state.volume > 0 ? 0 : 100);
      return KeyEventResult.handled;
    } else if (k == LogicalKeyboardKey.escape) {
      Navigator.maybePop(context);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isRec = widget.state.media.isRecordingChannel(_cur.title);
    final canZap = _cur.isLive && _cur.zapList.length > 1;

    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: kPanel.withValues(alpha: 0.92),
          title: Row(children: [
            if (_cur.isLive) ...[const LiveBadge(), const SizedBox(width: 10)],
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_cur.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15.5)),
                if (_cur.subtitle.isNotEmpty)
                  Text(_cur.subtitle, style: const TextStyle(color: kTextMuted, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ]),
            ),
          ]),
          actions: [
            if (_cur.variants.length > 1)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: ActionChip(
                  label: Text(_cur.variants[_variantIdx].label, style: const TextStyle(color: kCyan, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  onPressed: _showOptionsSheet,
                ),
              ),
            if (canZap) ...[
              IconButton(icon: const Icon(Icons.keyboard_arrow_up_rounded), tooltip: 'Önceki kanal', onPressed: () => _zap(-1)),
              IconButton(icon: const Icon(Icons.keyboard_arrow_down_rounded), tooltip: 'Sonraki kanal', onPressed: () => _zap(1)),
            ],
            if (!_cur.isLive) ...[
              IconButton(icon: const Icon(Icons.replay_10_rounded), tooltip: '-10 sn', onPressed: () => _seekBy(-10)),
              IconButton(icon: const Icon(Icons.forward_10_rounded), tooltip: '+10 sn', onPressed: () => _seekBy(10)),
            ],
            if (_cur.isLive)
              IconButton(
                icon: Icon(isRec ? Icons.stop_circle : Icons.fiber_manual_record, color: isRec ? kLive : kTextSoft),
                tooltip: isRec ? 'Kaydı durdur' : 'Canlı kaydet',
                onPressed: _toggleRecord,
              ),
            IconButton(
              icon: const Icon(Icons.aspect_ratio_rounded),
              tooltip: 'En-boy oranı',
              onPressed: _toggleFit,
            ),
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              tooltip: 'Ses / Altyazı / Uyku / Kalite',
              onPressed: _showOptionsSheet,
            ),
          ],
        ),
        body: Column(children: [
          if (_error != null)
            MaterialBanner(
              backgroundColor: kPanel,
              content: Text('Yayın hatası: $_error', maxLines: 2, overflow: TextOverflow.ellipsis),
              actions: [
                TextButton(onPressed: _start, child: const Text('Tekrar dene', style: TextStyle(color: kCyan))),
                TextButton(onPressed: () => setState(() => _error = null), child: const Text('Kapat')),
              ],
            ),
          Expanded(
            child: Center(
              child: Video(controller: controller, fit: _fit),
            ),
          ),
        ]),
      ),
    );
  }
}
