# Stream Player – iOS (SwiftUI)

Sağlanan ekran görüntülerindeki koyu, kenar çubuklu arayüzün iOS sürümü. Kod sıfırdan yazıldı,
Android uygulamasından kopyalanan kod yok.

## Ekran eşlemesi

| Ekran görüntüsü | iOS dosyası | Durum |
|---|---|---|
| homescreen.jpg | `Views/HomeScreen.swift` | Arama, öne çıkan alan, 5 kategori kutusu, canlı TV rayı |
| channel_list.jpg | `Views/LiveTVScreen.swift` | Kanal listesi ve sağda canlı yayın paneli |
| categories_list.jpg | `Views/CategoriesScreen.swift` | Kategori listesi (sayılarla) ve poster ızgarası |
| settings.jpg | `Views/SettingsScreen.swift` | Renkli kart ızgarası; "Playlists" kartı liste adresi ekranı açar |
| details_series.jpg | `Views/SeriesDetailScreen.swift` | Dizi detayı, sezon listesi, bölüm kartları |
| (her ekranda) | `Views/AppShell.swift` | Sol kenar çubuğu ve sayfa geçişi |

## Renk ve yazı tipi

Renkler ekran görüntülerinden piksel düzeyinde ölçüldü (`Theme/Theme.swift`):
zemin `#0B0F1A`, kenar çubuğu `#06070C`, kart `#131720`, seçili yeşil `#87ECAA`,
LIVE rozeti `#EB6280`, IMDb rozeti `#F5C518`. Yazı tipleri Outfit (başlık) ve Inter (metin).

## Logo

Uygulama logosu `Assets.xcassets/` içinde: uygulama simgesi (`AppIcon`, 1024 px, opak) ve
kenar çubuğu ile ayarlarda kullanılan logo (`Logo`, şeffaf PNG). Logo, uygulamanın lacivert ve yeşil
paletiyle çizildi, IPVIO logosuyla ilgisi yok.

## Telif ve marka

Ekran görüntülerindeki film posterleri, kanal logoları ve uygulama logosu projeye alınmadı.
Bunların yerine nötr yer tutucular (SF Symbols ve gradyanlar) kullanılıyor. Kendi içeriğinizi
ve kendi logonuzu ekleyin.

## İçerik kaynakları

Uygulama kendi başına hiçbir içerik sunmaz; üç kaynağı destekler:

1. **Xtream Codes (önerilen):** Sunucu adresi, kullanıcı adı ve şifreyle canlı + film + dizi
   listeleri; dizilerde gerçek sezon ve bölümler. **Kapak ve afiş resimleri bu yöntemle gelir.**
2. **Ulusal kanallar (hazır):** Ayarlar › Liste bölümünden tek dokunuşla iptv-org'un
   Türkiye listesi (TRT 1, ATV, Kanal D, NOW, Show, Star, TV8 vb. 100+ kanal) yüklenir.
3. **M3U listeniz:** http(s) .m3u/.m3u8 adresi. `tvg-logo` taşıyorsa afiş gösterir;
   `#EXTVLCOPT` satırlarındaki user-agent ve referrer bilgileri de oynatıcıya iletilir.

## Xcode'da kurulum

Gereksinimler: macOS, Xcode 15+, iOS 17+.

1. Xcode'da File > New > Project > iOS > App (SwiftUI, Swift), ad: `StreamPlayer`.
2. `App/`, `Theme/`, `Models/`, `Views/` klasörlerini projeye sürükleyin ("Copy items if needed").
3. (Xcode'u elle kullanacaksanız) `Resources/Fonts/` içindeki 7 yazı tipini ekleyin, hedef üyeliğini işaretleyin.
4. `Resources/Info.plist` anahtarlarını projeye ekleyin:
   - `UIAppFonts` (7 dosya adı)
   - `NSAppTransportSecurity > NSAllowsArbitraryLoads` (http listeleri için)
5. iPad veya yatay iPhone simülatöründe çalıştırın (⌘R). Sol kenar çubuğu geniş ekran için tasarlandı.
6. Ayarlar > Playlists bölümünden kendi M3U adresinizi girip yükleyin.



## iPhone ve iPad düzeni

- **iPhone (dar ekran):** Alt sekmeler: Ana Sayfa, Canlı TV, Filmler, Diziler, Ayarlar. Menüler
  düz listelerdir. Kanala tek dokunuşla oynatıcı açılır.
- **iPad (geniş ekran):** Sol kenar çubuğu düzeni.

Oynatıcı artık bağlantı hatasını ekranda gösterir. Yayın açılmazsa neden yazılır.

## GitHub'dan IPA üretme

Bu depoda `.github/workflows/ios-ipa.yml` var. Her `main` dalı push'unda GitHub, bir macOS
makinesinde projeyi derler ve imzasız bir IPA üretir.

1. Bu klasörün içeriğini (project.yml, App, Theme, Models, Views, Resources, .github) yeni bir
   GitHub deposuna yükleyin.
2. Depo sayfasında **Actions** sekmesine girin, **Build IPA** iş akışını çalıştırın
   (ya da `main` dalına bir push yapın).
3. İş bittikten sonra çalıştırmanın sayfasında **Artifacts** bölümünden
   `StreamPlayer-unsigned-ipa` dosyasını indirin.

Önemli notlar:
- Üretilen IPA imzasızdır. iPhone'a doğrudan kurulamaz. Kurmak için Apple ID ile imzalayan
  bir araç (Sideloadly, AltStore) ya da Apple Developer hesabı ve sertifika gerekir.
- App Store veya TestFlight için Apple Developer Program üyeliği ve imza sertifikaları gerekir.
  Bunları GitHub Secrets olarak ekleyip iş akışına imzalama adımı ekleyebiliriz.
- Bu iş akışı henüz çalıştırılmadı. İlk derlemede hata çıkarsa Actions sayfasındaki günlüğü
  paylaşın, düzeltelim.

## Bilinen sınırlar

- Dikey iPhone: Alt sekmeli (TabView) düzen kullanılır; tüm ekranlar dar ekrana uyarlandı.
- Yayın formatı: HLS (.m3u8) ve MP4 yerleşik oynatıcıyla; MPEG-TS (.ts), MKV, AVI vb. VLC
  (MobileVLCKit) ile oynatılır. Yerleşik oynatıcı açamazsa otomatik VLC'ye geçilir.
- EPG (program rehberi): M3U listesi program bilgisi taşımaz. Canlı panelde yer tutucu metin var.
- Sezon ve bölüm: Xtream Codes girişiyle gerçek sezon ve bölümler listelenir. M3U
  dizilerinde örnek veri gösterilir.
- Yer tutucu sayfalar: Favoriler, Listem ve Geçmiş bölümleri henüz tasarlanmadı.
- Ayarlar alt sayfaları: Yalnızca Playlists çalışıyor; diğer kartlar henüz işlevsiz.
- Derleme doğrulaması: Kod bir Mac'te derlenip test edilmedi. Hata alırsanız mesajı gönderin.

## Lisans

Yazı tipleri Outfit ve Inter, SIL Open Font License ile lisanslıdır. Dağıtımda OFL metnini ekleyin.
