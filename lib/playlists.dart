import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'models.dart';
import 'store.dart';
import 'theme.dart';
import 'util.dart';

/// Ayarlar: Profiller, Playlist & Medya Sunucuları (M3U / Yerel M3U / Xtream / Jellyfin-Emby),
/// Varyant Gruplama, TMDB API Anahtarı ve Yedekleme/Geri Yükleme (Windows <-> iOS).
class SettingsView extends StatelessWidget {
  final AppState s;
  const SettingsView(this.s, {super.key});

  void _snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

  Future<String?> _pin(BuildContext c, String title) async {
    final t = TextEditingController();
    final res = await showDialog<String>(
      context: c,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: t, obscureText: true, keyboardType: TextInputType.number, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, t.text), child: const Text('Tamam')),
        ],
      ),
    );
    t.dispose();
    return res;
  }

  Future<void> _switch(BuildContext context) async {
    final target = await showDialog<Profile>(
      context: context,
      builder: (ctx) => SimpleDialog(title: const Text('Profil seç'), children: [
        for (final p in s.profiles)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, p),
            child: Row(children: [
              Expanded(child: Text('${p.name}${p.kids ? '  (çocuk)' : ''}${p.pin.isNotEmpty ? '  🔒' : ''}')),
              if (s.profiles.length > 1 && p.id != s.profile.id && !s.profile.kids)
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 18),
                  tooltip: 'Profili sil',
                  onPressed: () async {
                    await s.removeProfile(p);
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                ),
            ]),
          ),
      ]),
    );
    if (target == null || target.id == s.profile.id || !context.mounted) return;
    final cur = s.profile;
    if (cur.kids && cur.pin.isNotEmpty) {
      final v = await _pin(context, '${cur.name} profilinin PIN kodu');
      if (v != cur.pin) {
        if (context.mounted) _snack(context, 'PIN yanlış');
        return;
      }
    }
    if (!context.mounted) return;
    if (target.pin.isNotEmpty) {
      final v = await _pin(context, '${target.name} profilinin PIN kodu');
      if (v != target.pin) {
        if (context.mounted) _snack(context, 'PIN yanlış');
        return;
      }
    }
    await s.switchProfile(target);
  }

  Future<void> _addProfile(BuildContext context) async {
    final name = TextEditingController(), pin = TextEditingController();
    var kids = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: const Text('Profil ekle'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: 'Ad')),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Çocuk profili'),
                subtitle: const Text('Ayarlar gizlenir, yetişkin kategorileri süzülür. PIN gerekir.'),
                value: kids,
                onChanged: (v) => set(() => kids = v),
              ),
              TextField(
                controller: pin,
                obscureText: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: kids ? 'PIN (en az 4 hane)' : 'PIN (isteğe bağlı)'),
              ),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ekle')),
          ],
        ),
      ),
    );
    final pName = name.text.trim();
    final pPin = pin.text.trim();
    name.dispose();
    pin.dispose();
    if (ok != true || pName.isEmpty) return;
    if (kids && pPin.length < 4) {
      if (context.mounted) _snack(context, 'Çocuk profili için en az 4 haneli PIN gerekir.');
      return;
    }
    await s.addProfile(Profile(id: 'p${DateTime.now().millisecondsSinceEpoch}', name: pName, kids: kids, pin: pPin));
  }

  Future<void> _editSource(BuildContext context, [Source? existing]) async {
    final name = TextEditingController(text: existing?.name ?? '');
    final url = TextEditingController(text: existing?.url ?? '');
    final user = TextEditingController(text: existing?.user ?? '');
    final pass = TextEditingController(text: existing?.pass ?? '');
    final epg = TextEditingController(text: existing?.epgUrl ?? '');
    final ua = TextEditingController(text: existing?.userAgent ?? '');
    String type = existing?.type ?? 'm3u';
    int refreshH = existing?.refreshHours ?? 12;
    int epgOff = existing?.epgOffsetMin ?? 0;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(existing == null ? 'Kaynak ekle' : 'Kaynağı düzenle'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final t in [('m3u', 'M3U URL'), ('xtream', 'Xtream'), ('local_m3u', 'Yerel M3U'), ('jellyfin', 'Jellyfin/Emby')])
                    ChoiceChip(
                      label: Text(t.$2),
                      selected: type == t.$1,
                      onSelected: (_) => set(() => type = t.$1),
                    ),
                ]),
                const SizedBox(height: 12),
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Ad')),
                const SizedBox(height: 10),
                TextField(
                  controller: url,
                  decoration: InputDecoration(
                    labelText: switch (type) {
                      'm3u' => 'M3U bağlantısı (http://...)',
                      'local_m3u' => 'Dosya yolu (C:\\...\\liste.m3u)',
                      'jellyfin' => 'Sunucu adresi (http://host:8096)',
                      _ => 'Sunucu (http://host:port)',
                    },
                  ),
                ),
                if (type == 'xtream') ...[
                  const SizedBox(height: 10),
                  TextField(controller: user, decoration: const InputDecoration(labelText: 'Kullanıcı adı')),
                  const SizedBox(height: 10),
                  TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Şifre')),
                ],
                if (type == 'jellyfin') ...[
                  const SizedBox(height: 10),
                  TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'API Anahtarı (API Key)')),
                ],
                const SizedBox(height: 10),
                TextField(controller: epg, decoration: const InputDecoration(labelText: 'Ek XMLTV EPG adresi (isteğe bağlı)')),
                const SizedBox(height: 10),
                TextField(controller: ua, decoration: const InputDecoration(labelText: 'Özel User-Agent (isteğe bağlı)')),
                const SizedBox(height: 12),
                Row(children: [
                  const Text('Yenileme:', style: TextStyle(color: kTextSoft, fontSize: 13)),
                  const SizedBox(width: 8),
                  for (final h in [6, 12, 24])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text('${h}s'),
                        selected: refreshH == h,
                        onSelected: (_) => set(() => refreshH = h),
                      ),
                    ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Text('EPG Saat Kayması: ${epgOff >= 0 ? '+$epgOff' : '$epgOff'} dk', style: const TextStyle(color: kTextSoft, fontSize: 12.5)),
                  Expanded(
                    child: Slider(
                      value: epgOff.toDouble(),
                      min: -180,
                      max: 180,
                      divisions: 12,
                      activeColor: kCyan,
                      onChanged: (v) => set(() => epgOff = v.round()),
                    ),
                  ),
                ]),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(existing == null ? 'Ekle' : 'Kaydet'),
            ),
          ],
        ),
      ),
    );

    final sName = name.text.trim();
    final sUrl = type == 'local_m3u' ? url.text.trim() : normalizeUrl(url.text);
    final sUser = user.text.trim();
    final sPass = pass.text.trim();
    final sEpg = normalizeUrl(epg.text);
    final sUa = ua.text.trim();
    name.dispose();
    url.dispose();
    user.dispose();
    pass.dispose();
    epg.dispose();
    ua.dispose();

    if (ok == true && sUrl.isNotEmpty) {
      final src = Source(
        id: existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: sName.isEmpty ? 'Playlist' : sName,
        type: type,
        url: sUrl,
        user: sUser,
        pass: sPass,
        epgUrl: sEpg,
        userAgent: sUa,
        refreshHours: refreshH,
        epgOffsetMin: epgOff,
      );
      if (existing == null) {
        await s.addSource(src);
      } else {
        await s.updateSource(src);
      }
    }
  }

  Future<void> _editTmdb(BuildContext context) async {
    final ctrl = TextEditingController(text: s.tmdbApiKey);
    final val = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('TMDB API Anahtarı'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'API Key (v3)',
            hintText: 'Film/dizi özet ve puanları için isteğe bağlı',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('Kaydet')),
        ],
      ),
    );
    ctrl.dispose();
    if (val != null) await s.setTmdbKey(val);
  }

  Future<void> _importBackup(BuildContext context) async {
    final ctrl = TextEditingController();
    final raw = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Yedek İçe Aktar (JSON)'),
        content: SizedBox(
          width: 440,
          child: TextField(
            controller: ctrl,
            maxLines: 8,
            decoration: const InputDecoration(hintText: 'Dışa aktarılan JSON yedeğini buraya yapıştırın…'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('İçe Aktar')),
        ],
      ),
    );
    ctrl.dispose();
    if (raw == null || raw.isEmpty) return;
    try {
      await s.importBackupJson(raw);
      if (context.mounted) _snack(context, 'Yedek başarıyla yüklendi.');
    } catch (e) {
      if (context.mounted) _snack(context, 'Geçersiz yedek verisi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final kids = s.profile.kids;
    final profileTile = ListTile(
      leading: Icon(kids ? Icons.child_care : Icons.person, color: kCyan),
      title: Text('Profil: ${s.profile.name}'),
      subtitle: Text(kids ? 'Çocuk profili' : 'Profili değiştirmek için dokunun'),
      trailing: kids ? const Icon(Icons.lock_outline) : const Icon(Icons.swap_horiz),
      onTap: () => _switch(context),
    );
    if (kids) return ListView(children: [profileTile]);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
        children: [
          Card(
            child: Column(children: [
              profileTile,
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.person_add_alt, color: kGold),
                title: const Text('Yeni profil ekle'),
                onTap: () => _addProfile(context),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Row(children: [
            const Text('KAYNAKLAR VE PLAYLISTLER', style: TextStyle(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.w700)),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => _editSource(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Kaynak Ekle'),
            ),
          ]),
          const SizedBox(height: 8),
          Card(
            child: s.sources.isEmpty
                ? const Padding(padding: EdgeInsets.all(24), child: Text('Henüz playlist yok. Sağ üstten ekleyin.'))
                : Column(children: [
                    for (final p in s.sources)
                      ListTile(
                        leading: Icon(
                          p.type == 'xtream'
                              ? Icons.dns_rounded
                              : p.type == 'jellyfin'
                                  ? Icons.video_library_rounded
                                  : Icons.link_rounded,
                          color: s.active?.id == p.id ? kCyan : kTextMuted,
                        ),
                        title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${p.type.toUpperCase()} · ${p.refreshHours}s yenileme${p.epgOffsetMin != 0 ? ' · EPG ${p.epgOffsetMin}dk' : ''}'),
                        selected: s.active?.id == p.id,
                        onTap: () => s.select(p),
                        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                          IconButton(icon: const Icon(Icons.edit_outlined), tooltip: 'Düzenle', onPressed: () => _editSource(context, p)),
                          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Yenile', onPressed: () => s.refresh(p)),
                          IconButton(icon: const Icon(Icons.delete_outline), tooltip: 'Sil', onPressed: () => s.removeSource(p)),
                        ]),
                      ),
                  ]),
          ),
          const SizedBox(height: 16),
          const Text('TERCİHLER VE ENTEGRASYONLAR', style: TextStyle(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              SwitchListTile(
                secondary: const Icon(Icons.layers_outlined, color: kCyan),
                title: const Text('Kanal varyantlarını otomatik grupla'),
                subtitle: const Text('Aynı kanalın 4K / FHD / HD / RAW sürümlerini tek satırda toplar'),
                value: s.groupVariants,
                onChanged: s.setGroupVariants,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.movie_filter_outlined, color: kGold),
                title: const Text('TMDB API Anahtarı'),
                subtitle: Text(s.tmdbApiKey.isEmpty ? 'Ayarlı değil (isteğe bağlı)' : 'Kayıtlı (film/dizi özeti aktif)'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _editTmdb(context),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          const Text('YEDEKLEME (WINDOWS ↔ iOS AKTARIM)', style: TextStyle(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.copy_all_rounded, color: kCyan),
                title: const Text('Yedeği panoya kopyala (JSON)'),
                subtitle: const Text('Diğer cihazda içe aktarmak için'),
                onTap: () async {
                  await Clipboard.setData(ClipboardData(text: s.exportBackupJson()));
                  if (context.mounted) _snack(context, 'Yedek JSON panoya kopyalandı.');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.save_alt_rounded, color: kGold),
                title: const Text('Yedeği dosyaya kaydet'),
                subtitle: const Text('Belgeler/OpenIPTV/open_iptv_backup.json'),
                onTap: () async {
                  final path = await s.saveBackupFile();
                  if (context.mounted) _snack(context, 'Kaydedildi: $path');
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.upload_rounded, color: kOk),
                title: const Text('Yedek içe aktar (JSON yapıştır)'),
                onTap: () => _importBackup(context),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}
