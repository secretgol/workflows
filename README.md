# Open IPTV

IPTV Deck tasarımından ilham alan, **Windows**, **iOS** ve **Android** için modern, açık kaynaklı Flutter IPTV oynatıcı. Uygulama içerik sağlamaz; kendi playlist'inizi eklersiniz.

## Özellikler
- **IPTV Deck Teması**: Sinema koyu obsidyen (`#05060B`) arayüz, elektrik camgöbeği (`#22D3EE`) odak/aksiyon vurguları ve şampanya altın (`#D9BC84`) rozetler
- **Windows & iOS Uyarlanabilir Arayüz**: Windows'ta sol navigasyon paneli, sağ film/dizi detay önizleme paneli ve klavye kısayolları; iOS'ta mobil alt gezinme çubuğu
- **Ana Sayfa & Global Arama**: Hero Spotlight, İzlemeye Devam Et, Favori Kanallar, Film/Dizi şeritleri; kanal, film, dizi ve TV programlarında anlık birleşik arama
- **Kaynaklar**: M3U URL, Yerel M3U dosyası, Xtream Codes ve Jellyfin/Emby sunucuları; özel User-Agent, 6/12/24 saat otomatik yenileme, EPG saat kayması (`±3 saat`)
- **Akıllı Kanal Yönetimi**: Aynı kanalın `4K / FHD / HD / RAW / HEVC` sürümlerini tek satırda otomatik gruplama, kanal yeniden adlandırma, gizleme ve **Özel Gruplarım**
- **14 Günlük TV Rehberi (EPG)**: Windows'ta üstte canlı mini önizleme + altta yatay zaman çizelgesi ve `ŞİMDİ` çizgisi; Catch-up (Xtream timeshift) ve program hatırlatıcıları
- **Gelişmiş Oynatıcı**: Kalite varyant seçici, kanal zap (`↑/↓`), `±10 sn` sarma, uyku zamanlayıcı, ses/altyazı parçaları, harici `.srt/.vtt` altyazı URL, en-boy oranı ve klavye kontrolü (`Space`, `M`, `←/→`, `↑/↓`, `Esc`)
- **Çoklu İzleme Pro**: `2`, `4`, `1+3`, `6`, `9` ızgara düzenleri, aktif seste camgöbeği çerçeve + `SES` rozeti, tümünü sustur, hücreyi tam ekrana büyüt, özel düzen kaydet/yükle
- **Çevrimdışı İndirme & Canlı Kayıt (DVR)**: Film/bölüm indirme ve canlı yayını `.ts` olarak yerel diske kaydetme (`Kitaplık -> İndirilenler / Kayıtlarım`)
- **Profiller & Yedekleme**: PIN korumalı Çocuk Profili, opsiyonel TMDB API entegrasyonu ve Windows ↔ iOS arası JSON yedekleme/geri yükleme

## GitHub'da Derleme
1. Bu klasörü yeni bir GitHub deposuna yükleyin (`main` veya `master` dalı).
2. **Actions** sekmesinde `Build Windows, APK and IPA` otomatik çalışır (veya **Run workflow** ile elle başlatılır).
3. Bitince **Artifacts** bölümünden `open-iptv-windows`, `open-iptv-ipa` ve `open-iptv-apk` indirilir.
4. **Windows**: ZIP dosyasını açıp `open_iptv.exe` dosyasını çalıştırın (klasörün tamamı birlikte kalmalıdır).
5. **iOS**: `open-iptv-unsigned.ipa` dosyasını Sideloadly / AltStore / kendi Apple sertifikanızla imzalayıp kurun.
