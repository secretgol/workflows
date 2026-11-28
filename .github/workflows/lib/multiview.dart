import 'dart:async';
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

Future<Channel?> pickChannel(BuildContext context, AppState s) => showModalBottomSheet<Channel>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _Picker(s),
    );

class _Picker extends StatefulWidget {
  final AppState s;
  const _Picker(this.s);
  @override
  State<_Picker> createState() => _PickerState();
}

class _PickerState extends State<_Picker> {
  List<Channel> list = [];
  Timer? deb;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    deb?.cancel();
    super.dispose();
  }

  Future<void> _load(String q) async {
    final src = widget.s.active?.id;
    if (src == null) return;
    final r = await Db.channels(src: src, profile: widget.s.profile.id, kids: widget.s.profile.kids, q: q);
    if (mounted) setState(() => list = r);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.72,
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(prefixIcon: Icon(Icons.search, color: kCyan), hintText: 'Kanal ara'),
                onChanged: (v) {
                  deb?.cancel();
                  deb = Timer(const Duration(milliseconds: 250), () => _load(v));
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: list.length,
                itemBuilder: (ctx, i) => ListTile(
                  leading: ChannelLogo(list[i].logo),
                  title: Text(list[i].displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(list[i].group, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(ctx, list[i]),
                ),
              ),
            ),
          ]),
        ),
      );
}

/// IPTV Deck tarzı Çoklu İzleme:
/// 2, 4, 1+3, 6, 9 ızgara düzenleri, aktif ses cyan çerçeve + SES rozeti,
/// tümünü sustur, hücreyi tam ekrana büyüt, düzen kaydet / yükle.
class MultiviewScreen extends StatefulWidget {
  final AppState state;
  const MultiviewScreen(this.state, {super.key});
  @override
  State<MultiviewScreen> createState() => _MultiviewScreenState();
}

class _MultiviewScreenState extends State<MultiviewScreen> {
  static const _presets = ['2', '4', '1+3', '6', '9'];
  String _preset = '4';
  final players = List<Player?>.filled(9, null);
  final ctrls = List<VideoController?>.filled(9, null);
  final urls = List<String>.filled(9, '');
  final names = List<String>.filled(9, '');
  List<SavedMultiviewLayout> _saved = [];
  int audio = -1;
  bool _mutedAll = false;

  int get _cellCount => switch (_preset) {
        '2' => 2,
        '4' => 4,
        '1+3' => 4,
        '6' => 6,
        '9' => 9,
        _ => 4,
      };

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final list = await Db.savedLayouts(widget.state.profile.id);
    if (mounted) setState(() => _saved = list);
  }

  @override
  void dispose() {
    for (final p in players) {
      p?.dispose();
    }
    super.dispose();
  }

  Future<void> _openInCell(int i, String url, String name) async {
    await players[i]?.dispose();
    if (!mounted) return;
    final p = Player();
    final vc = VideoController(p);
    players[i] = p;
    ctrls[i] = vc;
    urls[i] = url;
    names[i] = name;
    if (audio < 0 || players[audio] == null) audio = i;
    await p.setVolume(!_mutedAll && audio == i ? 100 : 0);
    if (!mounted) {
      await p.dispose();
      return;
    }
    setState(() {});
    await p.open(Media(url, httpHeaders: {'User-Agent': widget.state.active?.effectiveUa ?? kUa}));
  }

  Future<void> _pick(int i) async {
    final c = await pickChannel(context, widget.state);
    if (c == null || !mounted) return;
    await _openInCell(i, c.url, c.displayName);
  }

  void _clear(int i) {
    players[i]?.dispose();
    players[i] = null;
    ctrls[i] = null;
    urls[i] = '';
    names[i] = '';
    if (audio == i) audio = players.indexWhere((p) => p != null);
    _applyVolumes();
    setState(() {});
  }

  void _resetAll() {
    for (var i = 0; i < 9; i++) {
      players[i]?.dispose();
      players[i] = null;
      ctrls[i] = null;
      urls[i] = '';
      names[i] = '';
    }
    audio = -1;
    setState(() {});
  }

  void _applyVolumes() {
    for (var j = 0; j < 9; j++) {
      players[j]?.setVolume(!_mutedAll && j == audio ? 100 : 0);
    }
  }

  void _setAudio(int i) {
    audio = i;
    _mutedAll = false;
    _applyVolumes();
    setState(() {});
  }

  void _toggleMuteAll() {
    _mutedAll = !_mutedAll;
    _applyVolumes();
    setState(() {});
  }

  void _expandCell(int i) {
    if (urls[i].isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          widget.state,
          PlayItem(
            title: names[i],
            url: urls[i],
            isLive: true,
            kind: 'live',
            userAgent: widget.state.active?.effectiveUa ?? kUa,
          ),
        ),
      ),
    );
  }

  Future<void> _saveCurrentLayout() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Düzeni kaydet'),
        content: TextField(controller: ctrl, autofocus: true, decoration: const InputDecoration(labelText: 'Düzen adı')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Kaydet')),
        ],
      ),
    );
    ctrl.dispose();
    if (name == null || name.isEmpty) return;
    await Db.saveLayout(
      widget.state.profile.id,
      SavedMultiviewLayout(
        id: 'mv_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        preset: _preset,
        urls: urls.sublist(0, _cellCount),
        names: names.sublist(0, _cellCount),
      ),
    );
    await _loadSaved();
  }

  Future<void> _applySavedLayout(SavedMultiviewLayout layout) async {
    _resetAll();
    setState(() => _preset = layout.preset);
    for (var i = 0; i < layout.urls.length && i < 9; i++) {
      if (layout.urls[i].isNotEmpty) {
        await _openInCell(i, layout.urls[i], layout.names[i]);
      }
    }
  }

  Widget _cell(int i) {
    final vc = ctrls[i];
    final isAudio = !_mutedAll && audio == i && vc != null;
    return Expanded(
      child: GestureDetector(
        onTap: vc != null ? () => _setAudio(i) : () => _pick(i),
        onDoubleTap: vc != null ? () => _expandCell(i) : null,
        child: Container(
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: kPanel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isAudio ? kCyan : kBorder,
              width: isAudio ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: vc == null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.add_circle_outline, size: 36, color: kCyan), onPressed: () => _pick(i)),
                    Text('Kanal ${i + 1}', style: const TextStyle(color: kTextMuted, fontSize: 12)),
                  ]),
                )
              : Stack(fit: StackFit.expand, children: [
                  Video(controller: vc, controls: NoVideoControls, fit: BoxFit.cover),
                  const Positioned(left: 8, top: 8, child: LiveBadge()),
                  if (isAudio)
                    const Positioned(
                      right: 8,
                      top: 8,
                      child: TagPill('SES', color: Color(0xCC041418), textColor: kCyan),
                    ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(10, 14, 4, 4),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Color(0xCC05060B)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            names[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12.5),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: Icon(isAudio ? Icons.volume_up_rounded : Icons.volume_off_rounded, size: 18, color: isAudio ? kCyan : kTextSoft),
                          onPressed: () => _setAudio(i),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.open_in_full_rounded, size: 17),
                          tooltip: 'Tam ekran',
                          onPressed: () => _expandCell(i),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                          onPressed: () => _pick(i),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => _clear(i),
                        ),
                      ]),
                    ),
                  ),
                ]),
        ),
      ),
    );
  }

  Widget _grid() => switch (_preset) {
        '2' => Row(children: [_cell(0), _cell(1)]),
        '1+3' => Row(children: [
            Expanded(flex: 2, child: Column(children: [_cell(0)])),
            Expanded(flex: 1, child: Column(children: [_cell(1), _cell(2), _cell(3)])),
          ]),
        '6' => Column(children: [
            Expanded(child: Row(children: [_cell(0), _cell(1), _cell(2)])),
            Expanded(child: Row(children: [_cell(3), _cell(4), _cell(5)])),
          ]),
        '9' => Column(children: [
            Expanded(child: Row(children: [_cell(0), _cell(1), _cell(2)])),
            Expanded(child: Row(children: [_cell(3), _cell(4), _cell(5)])),
            Expanded(child: Row(children: [_cell(6), _cell(7), _cell(8)])),
          ]),
        _ => Column(children: [
            Expanded(child: Row(children: [_cell(0), _cell(1)])),
            Expanded(child: Row(children: [_cell(2), _cell(3)])),
          ]),
      };

  Widget _sidebar() => Container(
        width: 210,
        padding: const EdgeInsets.all(14),
        decoration: const BoxDecoration(
          color: kPanel,
          border: Border(right: BorderSide(color: kBorder)),
        ),
        child: ListView(children: [
          const Text('PENCERE DÜZENİ', style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final p in _presets)
              ChoiceChip(
                label: Text(p),
                selected: _preset == p,
                onSelected: (_) => setState(() => _preset = p),
              ),
          ]),
          const Divider(height: 28),
          OutlinedButton.icon(
            onPressed: _toggleMuteAll,
            icon: Icon(_mutedAll ? Icons.volume_off : Icons.volume_up, size: 18, color: _mutedAll ? kLive : kCyan),
            label: Text(_mutedAll ? 'Sesi Aç' : 'Tümünü Sustur'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _saveCurrentLayout,
            icon: const Icon(Icons.bookmark_add_outlined, size: 18, color: kGold),
            label: const Text('Düzeni Kaydet'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _resetAll,
            icon: const Icon(Icons.restart_alt, size: 18),
            label: const Text('Sıfırla'),
          ),
          if (_saved.isNotEmpty) ...[
            const Divider(height: 28),
            const Text('KAYITLI DÜZENLER', style: TextStyle(color: kTextMuted, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final l in _saved)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${l.preset} ekran', style: const TextStyle(fontSize: 11)),
                onTap: () => _applySavedLayout(l),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  onPressed: () async {
                    await Db.deleteLayout(l.id);
                    _loadSaved();
                  },
                ),
              ),
          ],
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Çoklu İzleme'),
        actions: [
          if (!wide) ...[
            for (final p in ['2', '4', '1+3'])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: ChoiceChip(
                  label: Text(p),
                  selected: _preset == p,
                  onSelected: (_) => setState(() => _preset = p),
                ),
              ),
            IconButton(icon: Icon(_mutedAll ? Icons.volume_off : Icons.volume_up), onPressed: _toggleMuteAll),
            IconButton(icon: const Icon(Icons.bookmark_add_outlined), onPressed: _saveCurrentLayout),
          ],
        ],
      ),
      body: wide
          ? Row(children: [_sidebar(), Expanded(child: Padding(padding: const EdgeInsets.all(6), child: _grid()))])
          : Padding(padding: const EdgeInsets.all(4), child: _grid()),
    );
  }
}
