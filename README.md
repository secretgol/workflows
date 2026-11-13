# TeleBox - IPTV oynatıcı (Windows / macOS / Linux)

## Hızlı çalıştırma (Node.js 18+ kuruluysa)
    npm install
    npm start

## Tek tıkla çalışan program üretme (GitHub)
1. Yeni boş repo açın, bu klasörün TÜM içeriğini (`.github` dahil) repo köküne yükleyin.
2. Actions > Build Desktop > Run workflow.
3. Bitince Artifacts'tan indirin: Windows `.exe` (kurulumsuz), Linux `.AppImage`, macOS `.dmg`.

## Kanal listesi
Varsayılan: iptv-org Türkiye listesi (https://iptv-org.github.io/iptv/countries/tr.m3u).
Her açılışta güncel liste indirilir; internet yoksa son kayıtlı liste kullanılır.
Ayarlar'dan kendi M3U bağlantınızı girebilir veya dosyadan yükleyebilirsiniz.

## Kısayollar
↑ ↓ kanal değiştir · Boşluk duraklat · F tam ekran · M sessiz · çift tık tam ekran
