# Nova IPTV Box - Android TV & Android Box İçin Stabil IPTV Uygulaması

Bu proje, **Android TV** ve özellikle **Android Box (STB - Set-Top Box)** cihazlarının donanım kısıtlamaları ve kumanda (D-Pad) kullanım alışkanlıkları göz önünde bulundurularak sıfırdan geliştirilmiş, yüksek kararlılık ve akıcılık sunan bir IPTV oynatıcı uygulamasıdır.

---

## 🌟 Öne Çıkan Kararlılık ve Performans Özellikleri

1. **Android TV & Kumanda (D-Pad) Odaklı Tasarım:**
   - Dokunmatik ekrana ihtiyaç duymaz (`touchscreen` gereksinimi kapalıdır).
   - Kumanda yön tuşları (`YUKARI`, `AŞAĞI`, `SOL`, `SAĞ`, `OK`, `GERİ`, `MENÜ`) ile tam kontrol.
   - Odaklanılan kartlarda büyüme efekti (1.06x - 1.08x scale) ve parlak mavi çerçeve (`border_focused`) ile televizyonda rahat görüş.
   - Renkli kumanda tuşları desteği:
     - **MAVİ TUŞ / UZUN OK**: Kanalı Favorilere ekler / kaldırır.
     - **SARI TUŞ / MENÜ / SAĞ**: Ekran formatını (16:9, Tam Ekran, Orantılı, Zoom) değiştirir.
     - **SOL TUŞ**: Canlı yayın kesilmeden soldan hızlı kanal listesini açar.

2. **AndroidX Media3 (ExoPlayer) ile Donmayan Yayın:**
   - Düşük RAM'li (1GB - 2GB RAM) TV Box cihazları için optimize edilmiş bellek yönetimi (`DefaultLoadControl` live buffering: min 15s, max 50s, başlatma 2s).
   - Donanım hızlandırma ve **Software Codec Fallback**: Amlogic, Allwinner veya Rockchip yongalı kutularda donanım çözücünün desteklemediği veya çöktüğü H.264 / H.265 / TS akışlarında otomatik yazılımsal çözücüye geçer.
   - Kopan yayınlarda çökmeyi engelleyen **Otomatik Yeniden Bağlanma (Auto-reconnect)** ve görsel hata paneli.

3. **HTTP / Cleartext ve Sunucu Engeli Aşma:**
   - Android 9+ sürümlerinde IPTV sunucularının çoğunun kullandığı `http://` bağlantılarının engellenmesini önlemek için `android:usesCleartextTraffic="true"` aktiftir.
   - Birçok IPTV sağlayıcısının standart Java veya ExoPlayer User-Agent'larını engellemesi sebebiyle özel `IPTVSmarters/2.1.0` TV User-Agent başlığı tanımlanmıştır.

4. **Çift Protokol Desteği:**
   - **M3U / M3U8 Playlist:** 20.000+ kanallı devasa çalma listelerini belleği şişirmeden satır satır okuyan optimize edilmiş akış ayrıştırıcı.
   - **Xtream Codes API:** Sunucu adresi, kullanıcı adı ve şifre ile doğrudan kategori ve canlı yayın çekme.
   - **Hazır Test Kanalları:** Uygulama açıldığında test edebilmeniz için resmi ve yasal TRT 1, TRT Spor, TRT Haber, TRT Belgesel, Euronews, NASA TV, Red Bull TV gibi kanallar önceden tanımlanmıştır.

---

## 📂 Proje Dizin Yapısı

```
iptv android/
├── app/
│   ├── build.gradle.kts
│   ├── proguard-rules.pro
│   └── src/
│       └── main/
│           ├── AndroidManifest.xml
│           ├── java/com/iptv/tvbox/
│           │   ├── IPTVApplication.kt
│           │   ├── data/
│           │   │   ├── api/ (ApiClient.kt, XtreamApiService.kt)
│           │   │   ├── model/ (Channel.kt, Category.kt, XtreamModels.kt)
│           │   │   ├── parser/ (M3UParser.kt)
│           │   │   └── repository/ (IPTVRepository.kt)
│           │   ├── player/ (IPTVPlayerManager.kt)
│           │   └── ui/
│           │       ├── MainActivity.kt (TV Ana Menü, Grid, Kategoriler)
│           │       ├── PlayerActivity.kt (Tam Ekran Oynatıcı & Kumanda OSD)
│           │       ├── PlaylistSetupActivity.kt (M3U / Xtream Girişi)
│           │       ├── adapter/ (ChannelAdapter.kt, CategoryAdapter.kt)
│           │       └── util/ (FocusHelper.kt, PreferencesManager.kt, SamplePlaylists.kt)
│           └── res/
│               ├── drawable/ (Kumanda odak selektörleri, ikonlar, TV banner)
│               ├── layout/ (activity_main.xml, activity_player.xml, item_channel.xml, vb.)
│               └── values/ (colors.xml, strings.xml, themes.xml, dimens.xml)
├── build.gradle.kts
├── settings.gradle.kts
└── gradle.properties
```

---

## 🚀 Derleme ve Android Box'a Yükleme

### Yöntem 1: Android Studio ile (En Kolay)
1. **Android Studio**'yu açın.
2. `Open` seçeneğiyle bu klasörü (`c:\Users\secre\OneDrive\Masaüstü\ai klasörü\iptv android`) seçin.
3. Gradle senkronizasyonu tamamlandığında `Build` -> `Build Bundle(s) / APK(s)` -> `Build APK(s)` seçeneğine tıklayın.
4. Üretilen `app-debug.apk` dosyasını bir USB belleğe atarak Android Box'ınıza takın ve dosya yöneticisiyle yükleyin (veya ağ üzerinden LocalSend ile gönderin).

### Yöntem 2: Komut Satırı ile
```bash
./gradlew assembleDebug
```
Üretilen APK: `app/build/outputs/apk/debug/app-debug.apk`

---

## 🎮 Kumanda Kısayolları

| Tuş | İşlev |
|---|---|
| **YUKARI / AŞAĞI** | Oynatıcıda kanal değiştirir; menüde gezinir |
| **OK / ENTER** | Oynatıcıda bilgi çubuğunu açar/kapatır; menüde kanalı başlatır |
| **SOL** | Canlı yayın esnasında soldan hızlı kanal çekmecesini açar |
| **SAĞ / SARI TUŞ** | Görüntü formatını değiştirir (Fit, Fill, Zoom) |
| **MAVİ TUŞ** | Kanalı favorilere ekler veya çıkarır |
| **GERİ** | Önceki menüye döner / hızlı listeyi kapatır |
| **MENÜ** | Oynatma listesi ayar ekranını açar |
