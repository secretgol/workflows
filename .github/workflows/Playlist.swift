import Foundation

/// Kullanıcının listesinden okunan tek bir kayıt: M3U veya Xtream Codes kaynağından gelir.
struct MediaItem: Identifiable, Hashable {
    enum Kind: String { case live, movie, series }

    let id: String
    let name: String
    let group: String
    let logo: URL?
    let stream: URL
    let kind: Kind
    /// M3U'daki #EXTVLCOPT satırlarından okunan yayın ayarları (bazı sağlayıcılar ister).
    let userAgent: String?
    let referrer: String?
    /// Xtream Codes dizisinin ID'si; gerçek sezon/bölüm listesi bununla çekilir.
    let xtreamSeriesID: Int?

    init(id: String, name: String, group: String, logo: URL?, stream: URL, kind: Kind,
         userAgent: String? = nil, referrer: String? = nil, xtreamSeriesID: Int? = nil) {
        self.id = id
        self.name = name
        self.group = group
        self.logo = logo
        self.stream = stream
        self.kind = kind
        self.userAgent = userAgent
        self.referrer = referrer
        self.xtreamSeriesID = xtreamSeriesID
    }
}

// MARK: - M3U ayrıştırıcı

enum M3UParser {
    /// Basit M3U/M3U8 ayrıştırıcı: #EXTINF + #EXTVLCOPT satırları ve onları izleyen URL satırı.
    static func parse(_ text: String) -> [MediaItem] {
        var items: [MediaItem] = []
        var pendingName: String?
        var pendingGroup = "Diğer"
        var pendingLogo: URL?
        var pendingUserAgent: String?
        var pendingReferrer: String?

        let clean = text.replacingOccurrences(of: "\u{FEFF}", with: "")
        for raw in clean.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("#EXTINF") {
                pendingName = extinfName(line)
                pendingGroup = attribute("group-title", in: line) ?? "Diğer"
                pendingLogo = attribute("tvg-logo", in: line).flatMap(XtreamClient.tolerantURL)
            } else if line.hasPrefix("#EXTVLCOPT:") {
                // Örnek: #EXTVLCOPT:http-user-agent=VLC
                let opt = line.dropFirst("#EXTVLCOPT:".count)
                let pair = opt.split(separator: "=", maxSplits: 1)
                if pair.count == 2 {
                    switch pair[0].lowercased() {
                    case "http-user-agent": pendingUserAgent = String(pair[1])
                    case "http-referrer": pendingReferrer = String(pair[1])
                    default: break
                    }
                }
            } else if !line.isEmpty, !line.hasPrefix("#"), let url = makeURL(line) {
                items.append(MediaItem(
                    id: "\(items.count)-\(line)",
                    name: pendingName ?? url.lastPathComponent,
                    group: pendingGroup,
                    logo: pendingLogo,
                    stream: url,
                    kind: classify(group: pendingGroup, url: line),
                    userAgent: pendingUserAgent,
                    referrer: pendingReferrer))
                pendingName = nil
                pendingGroup = "Diğer"
                pendingLogo = nil
                pendingUserAgent = nil
                pendingReferrer = nil
            }
        }
        return items
    }

    /// Boşluk veya Türkçe karakter içeren adresleri de kabul eder.
    static func makeURL(_ raw: String) -> URL? {
        if let url = URL(string: raw) { return url }
        guard let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: encoded)
    }

    /// #EXTINF adı: tırnak içinde olmayan İLK virgülden sonrasıdır.
    /// (Kanal adında virgül varsa eskiden isim bozuluyordu.)
    private static func extinfName(_ line: String) -> String? {
        var inQuote = false
        for (offset, ch) in line.enumerated() {
            if ch == "\"" {
                inQuote.toggle()
            } else if ch == "," && !inQuote {
                let index = line.index(line.startIndex, offsetBy: offset + 1)
                return String(line[index...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    private static func attribute(_ key: String, in line: String) -> String? {
        guard let range = line.range(of: "\(key)=\"") else { return nil }
        let rest = line[range.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        return String(rest[..<end])
    }

    /// Grup adına ve bağlantıya göre tür tahmini. Kendi listenize göre değiştirebilirsiniz.
    private static func classify(group: String, url: String) -> MediaItem.Kind {
        let g = group.lowercased()
        let u = url.lowercased()
        if g.contains("dizi") || g.contains("series") || u.contains("/series/") { return .series }
        if g.contains("film") || g.contains("movie") || g.contains("vod") || u.contains("/movie/") { return .movie }
        return .live
    }

    /// Liste UTF-8 değilse (bazı sağlayıcılar Windows-1254 gönderir) yine okunur.
    static func decode(_ data: Data) -> String {
        if let s = String(data: data, encoding: .utf8) { return s }
        for encoding in [String.Encoding.windowsCP1254, .isoLatin1] {
            if let s = String(data: data, encoding: encoding) { return s }
        }
        return String(decoding: data, as: UTF8.self)
    }
}

// MARK: - Depo

enum ListSource: String {
    case m3u, xtream
}

@MainActor
final class PlaylistStore: ObservableObject {
    /// iptv-org projesinin Türkiye kanal listesi: TRT 1, ATV, Kanal D, NOW, Show,
    /// Star, TV8 vb. ulusal kanallar dahil 100+ kanal. Liste topluluk bakımlıdır.
    static let localChannelsURL = "https://iptv-org.github.io/iptv/countries/tr.m3u"

    @Published private(set) var items: [MediaItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    @Published private(set) var source: ListSource?
    /// Aktif Xtream girişi (dizi bölüm listesi için gerekir).
    @Published private(set) var credentials: XtreamCredentials?

    var live: [MediaItem]   { items.filter { $0.kind == .live } }
    var movies: [MediaItem] { items.filter { $0.kind == .movie } }
    var series: [MediaItem] { items.filter { $0.kind == .series } }

    private enum Keys {
        static let source = "listSource"
        static let playlistURL = "playlistURL"
        static let xtreamHost = "xtreamHost"
        static let xtreamUser = "xtreamUser"
        static let xtreamPass = "xtreamPass"
    }

    /// Ulusal kanal listesini (TR) yükler.
    func loadLocalChannels() async {
        await loadM3U(from: Self.localChannelsURL)
    }

    /// Açılışta kayıtlı kaynağı (M3U ya da Xtream) yeniden yükler.
    func restoreOnLaunch() async {
        guard items.isEmpty else { return }
        let defaults = UserDefaults.standard
        switch defaults.string(forKey: Keys.source) {
        case ListSource.m3u.rawValue:
            if let url = defaults.string(forKey: Keys.playlistURL), !url.isEmpty {
                await loadM3U(from: url)
            }
        case ListSource.xtream.rawValue:
            if let host = defaults.string(forKey: Keys.xtreamHost),
               let user = defaults.string(forKey: Keys.xtreamUser),
               let pass = defaults.string(forKey: Keys.xtreamPass) {
                await loadXtream(host: host, user: user, pass: pass)
            }
        default:
            break
        }
    }

    // MARK: M3U listesi

    func loadM3U(from urlString: String) async {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespaces)),
              url.scheme?.hasPrefix("http") == true else {
            errorMessage = "Geçerli bir liste adresi girin (http veya https)."
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let parsed = M3UParser.parse(M3UParser.decode(data))
            guard !parsed.isEmpty else {
                errorMessage = "Listede oynatılabilir kayıt bulunamadı."
                return
            }
            items = parsed
            source = .m3u
            credentials = nil
            UserDefaults.standard.set(urlString, forKey: Keys.playlistURL)
            UserDefaults.standard.set(ListSource.m3u.rawValue, forKey: Keys.source)
        } catch {
            errorMessage = "Liste indirilemedi: \(error.localizedDescription)"
        }
    }

    // MARK: Xtream Codes

    func loadXtream(host: String, user: String, pass: String) async {
        guard let creds = XtreamCredentials(host: host, username: user, password: pass) else {
            errorMessage = XtreamError.badHost.localizedDescription
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let client = XtreamClient(creds: creds)
            try await client.login()

            var all: [MediaItem] = []
            all += try await client.streams(for: .live, categories: try await client.categories(for: .live))
            all += try await client.streams(for: .vod, categories: try await client.categories(for: .vod))
            all += try await client.streams(for: .series, categories: try await client.categories(for: .series))

            guard !all.isEmpty else {
                errorMessage = "Sunucuda içerik bulunamadı."
                return
            }

            items = all
            credentials = creds
            source = .xtream
            let defaults = UserDefaults.standard
            defaults.set(ListSource.xtream.rawValue, forKey: Keys.source)
            defaults.set(host, forKey: Keys.xtreamHost)
            defaults.set(user, forKey: Keys.xtreamUser)
            defaults.set(pass, forKey: Keys.xtreamPass)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
