import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'epg_view.dart';
import 'home_view.dart';
import 'models.dart';
import 'multiview.dart';
import 'player.dart';
import 'playlists.dart';
import 'store.dart';
import 'theme.dart';
import 'views.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  MediaKit.ensureInitialized();
  final state = AppState();
  await state.init();
  runApp(MaterialApp(
    title: 'Open IPTV',
    debugShowCheckedModeBanner: false,
    theme: buildTheme(),
    home: HomeScreen(state),
  ));
}

class HomeScreen extends StatefulWidget {
  final AppState state;
  const HomeScreen(this.state, {super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int tab = 0;

  static const _desktopNav = [
    (Icons.home_rounded, 'Ana Sayfa'),
    (Icons.search_rounded, 'Ara'),
    (Icons.live_tv_rounded, 'Canlı TV'),
    (Icons.calendar_view_day_rounded, 'TV Rehberi'),
    (Icons.movie_outlined, 'Filmler'),
    (Icons.tv_outlined, 'Diziler'),
    (Icons.video_library_outlined, 'Kitaplık'),
    (Icons.settings_outlined, 'Ayarlar'),
  ];

  static const _mobileTabIndices = [0, 2, 3, 4, 7];

  Widget _playlistSwitcher(AppState s) {
    if (s.sources.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<Source>(
      tooltip: 'Playlist değiştir',
      onSelected: s.select,
      itemBuilder: (_) => [
        for (final src in s.sources)
          PopupMenuItem(
            value: src,
            child: Row(children: [
              Icon(src.id == s.active?.id ? Icons.check_circle : Icons.circle_outlined,
                  size: 16, color: src.id == s.active?.id ? kCyan : kTextMuted),
              const SizedBox(width: 8),
              Expanded(child: Text(src.name, overflow: TextOverflow.ellipsis)),
            ]),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: kSurface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kBorder),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.playlist_play_rounded, size: 16, color: kCyan),
          const SizedBox(width: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 140),
            child: Text(s.active?.name ?? 'Playlist', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(width: 2),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: kTextMuted),
        ]),
      ),
    );
  }

  Widget _desktopSidebar(AppState s) => Container(
        width: 214,
        decoration: const BoxDecoration(
          color: kPanel,
          border: Border(right: BorderSide(color: kBorder)),
        ),
        child: Column(children: [
          // Marka başlığı
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 16, 14),
            child: Row(children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(color: kGold, shape: BoxShape.circle),
              ),
              const SizedBox(width: 10),
              const Text(
                'Open IPTV',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.4),
              ),
              const Spacer(),
              if (s.media.activeRecordings.isNotEmpty) const LiveBadge(text: 'REC'),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Align(alignment: Alignment.centerLeft, child: _playlistSwitcher(s)),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                for (var i = 0; i < _desktopNav.length; i++) _navTile(i, _desktopNav[i].$1, _desktopNav[i].$2),
                const Divider(height: 24),
                ListTile(
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(Icons.grid_view_rounded, size: 20, color: kGold),
                  title: const Text('Çoklu İzleme', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MultiviewScreen(s))),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: kCyan.withValues(alpha: 0.18),
              child: Icon(s.profile.kids ? Icons.child_care : Icons.person, size: 16, color: kCyan),
            ),
            title: Text(s.profile.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            subtitle: Text(s.profile.kids ? 'Çocuk profili' : 'Profil', style: const TextStyle(fontSize: 11)),
            onTap: () => setState(() => tab = 7),
          ),
        ]),
      );

  Widget _navTile(int index, IconData icon, String label) {
    final active = tab == index;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => tab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? kCyan.withValues(alpha: 0.14) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? kCyan.withValues(alpha: 0.55) : Colors.transparent),
          ),
          child: Row(children: [
            Icon(icon, size: 20, color: active ? kCyan : kTextMuted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: active ? kText : kTextSoft,
                  fontSize: 13.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            if (active)
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(color: kCyan, shape: BoxShape.circle),
              ),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final pages = IndexedStack(index: tab, children: [
      HomeDashboardView(s, onNavigateTab: (i) => setState(() => tab = i)),
      GlobalSearchView(s),
      ChannelsView(s, mode: ViewMode.live),
      EpgGridView(s),
      VodView(s, kind: 'movie'),
      VodView(s, kind: 'series'),
      LibraryView(s),
      SettingsView(s),
    ]);

    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final rem = s.dueReminder;
        final body = Column(children: [
          if (s.loading) const LinearProgressIndicator(minHeight: 2, color: kCyan),
          if (rem != null)
            MaterialBanner(
              backgroundColor: kPanel,
              leading: const Icon(Icons.notifications_active_rounded, color: kGold),
              content: Text('Başlıyor: ${rem.title} (${rem.channelName})'),
              actions: [
                TextButton(
                  onPressed: () {
                    s.dismissReminder();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PlayerScreen(
                          s,
                          PlayItem(title: rem.channelName, url: rem.channelUrl, isLive: true, kind: 'live', subtitle: rem.title),
                        ),
                      ),
                    );
                  },
                  child: const Text('İzle', style: TextStyle(color: kCyan)),
                ),
                TextButton(onPressed: s.dismissReminder, child: const Text('Kapat')),
              ],
            ),
          Expanded(child: pages),
        ]);

        return LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 900;
          final mobileNavIdx = _mobileTabIndices.indexOf(tab);
          return Scaffold(
            appBar: wide
                ? null
                : AppBar(
                    title: Row(children: [
                      Container(width: 8, height: 8, decoration: const BoxDecoration(color: kGold, shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      const Text('Open IPTV'),
                    ]),
                    actions: [
                      _playlistSwitcher(s),
                      IconButton(icon: const Icon(Icons.search_rounded), tooltip: 'Ara', onPressed: () => setState(() => tab = 1)),
                      IconButton(icon: const Icon(Icons.tv_outlined), tooltip: 'Diziler', onPressed: () => setState(() => tab = 5)),
                      IconButton(icon: const Icon(Icons.video_library_outlined), tooltip: 'Kitaplık', onPressed: () => setState(() => tab = 6)),
                    ],
                  ),
            body: SafeArea(
              child: wide ? Row(children: [_desktopSidebar(s), Expanded(child: body)]) : body,
            ),
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: mobileNavIdx >= 0 ? mobileNavIdx : 0,
                    onDestinationSelected: (i) => setState(() => tab = _mobileTabIndices[i]),
                    destinations: const [
                      NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Ana Sayfa'),
                      NavigationDestination(icon: Icon(Icons.live_tv_rounded), label: 'Canlı'),
                      NavigationDestination(icon: Icon(Icons.calendar_view_day_rounded), label: 'Rehber'),
                      NavigationDestination(icon: Icon(Icons.movie_outlined), label: 'Filmler'),
                      NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Ayarlar'),
                    ],
                  ),
          );
        });
      },
    );
  }
}
