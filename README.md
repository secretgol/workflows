# TeleBox - Windows IPTV oynatıcı

## Çalıştırma (Node.js 18+ kuruluysa)
    npm install
    npm start

## Kurulumsuz .exe üretme (GitHub)
1. Yeni boş repo açın, bu klasörün TÜM içeriğini (`.github` dahil) repo köküne yükleyin.
2. Actions > Build Windows > Run workflow.
3. Bitince Artifacts > TeleBox-Windows > zip içinden `TeleBox-1.1.0-portable.exe`.

## Kanal listesi
- Kendi M3U dosyanız: pencereye sürükleyip bırakın ya da "M3U dosyası seç…" / Ayarlar > "Dosyadan yükle".
  Liste diske kaydedilir, bir sonraki açılışta otomatik yüklenir.
- M3U bağlantısı: Ayarlar'dan girin (her açılışta yenilenir).

## Oynatma
Uzantısız canlı akışlar (http://sunucu:port/kullanıcı/şifre/numara) önce MPEG-TS olarak, olmazsa HLS (.m3u8) olarak denenir.
Görüntü gelmezse VLC kuruluysa sağ alttaki VLC düğmesiyle kanal VLC'de açılır.

## Kısayollar
↑ ↓ kanal · Boşluk duraklat · F tam ekran · M sessiz · çift tık tam ekran
