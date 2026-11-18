import Foundation

// MARK: - Hatalar

enum XtreamError: LocalizedError {
    case badHost
    case badLogin
    case http(Int)
    case badResponse

    var errorDescription: String? {
        switch self {
        case .badHost: return "Geçerli bir sunucu adresi girin (örn. http://sunucu:8080)."
        case .badLogin: return "Kullanıcı adı, şifre ya da sunucu adresi hatalı."
        case .http(let code): return "Sunucu \(code) kodu döndürdü."
        case .badResponse: return "Sunucu yanıtı okunamadı."
        }
    }
}

// MARK: - Kimlik bilgileri

struct XtreamCredentials: Hashable {
    let host: URL
    let username: String
    let password: String

    init?(host: String, username: String, password: String) {
        guard let base = Self.normalizeHost(host),
              !username.trimmingCharacters(in: .whitespaces).isEmpty,
              !password.isEmpty else { return nil }
        self.host = base
        self.username = username.trimmingCharacters(in: .whitespaces)
        self.password = password
    }

    /// "http://" eklenmemiş adresleri düzeltir; kullanıcı tam panel bağlantısı yapıştırdıysa
    /// yalnızca sunucu kökünü alır (örn. http://sunucu:8080/c/ → http://sunucu:8080).
    static func normalizeHost(_ raw: String) -> URL? {
        var s = raw.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return nil }
        if !s.lowercased().hasPrefix("http") { s = "http://" + s }
        guard var comps = URLComponents(string: s), let scheme = comps.scheme, let h = comps.host else { return nil }
        var rebuilt = scheme + "://" + h
        if let port = comps.port { rebuilt += ":\(port)" }
        while rebuilt.hasSuffix("/") { rebuilt.removeLast() }
        return URL(string: rebuilt)
    }

    var apiURL: URL { host.appendingPathComponent("player_api.php") }

    func apiURL(action: String? = nil, extra: [String: String] = [:]) -> URL {
        var comps = URLComponents(url: apiURL, resolvingAgainstBaseURL: false)!
        var items = [
            URLQueryItem(name: "username", value: username),
            URLQueryItem(name: "password", value: password),
        ]
        if let action { items.append(URLQueryItem(name: "action", value: action)) }
        for (key, value) in extra { items.append(URLQueryItem(name: key, value: value)) }
        comps.queryItems = items
        return comps.url!
    }

    /// Xtream yayın adresi biçimi: /<root>/<kullanıcı>/<şifre>/<id>.<uzantı>
    func streamURL(root: String, id: Int, ext: String) -> URL {
        host.appendingPathComponent("\(root)/\(username)/\(password)/\(id).\(ext.isEmpty ? "mp4" : ext)")
    }
}

// MARK: - Dizi bölümü

struct EpisodeInfo: Identifiable, Hashable {
    let id: Int
    let season: Int
    let number: Int
    let title: String
    let streamURL: URL
    let image: URL?
}

// MARK: - İstemci

/// Xtream Codes API istemcisi. player_api.php üzerinden kategori, kanal, film
/// ve dizi listelerini çeker; bölüm listesini get_series_info ile okur.
@MainActor
final class XtreamClient {
    enum Kind {
        case live, vod, series

        var categoryAction: String {
            switch self {
            case .live: return "get_live_categories"
            case .vod: return "get_vod_categories"
            case .series: return "get_series_categories"
            }
        }

        var listAction: String {
            switch self {
            case .live: return "get_live_streams"
            case .vod: return "get_vod_streams"
            case .series: return "get_series"
            }
        }
    }

    private let creds: XtreamCredentials
    private let session: URLSession

    init(creds: XtreamCredentials) {
        self.creds = creds
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: Genel istek

    private func fetchJSON(_ url: URL) async throws -> Any {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw XtreamError.http(http.statusCode)
        }
        return try JSONSerialization.jsonObject(with: data)
    }

    // MARK: Giriş kontrolü

    func login() async throws {
        let json = try await fetchJSON(creds.apiURL())
        guard let dict = json as? [String: Any],
              let info = dict["user_info"] as? [String: Any] else {
            throw XtreamError.badResponse
        }
        let auth = (info["auth"] as? String) == "1" || (info["auth"] as? Int) == 1
        let status = (info["status"] as? String) ?? ""
        guard auth, status.lowercased().contains("active") else {
            throw XtreamError.badLogin
        }
    }

    // MARK: Kategoriler

    /// Kategori kimliği → kategori adı eşlemesi döndürür.
    func categories(for kind: Kind) async throws -> [String: String] {
        let json = try await fetchJSON(creds.apiURL(action: kind.categoryAction))
        guard let rows = json as? [[String: Any]] else { throw XtreamError.badResponse }
        var map: [String: String] = [:]
        for row in rows {
            guard let id = row.string("category_id") else { continue }
            map[id] = row.string("category_name") ?? "Diğer"
        }
        return map
    }

    // MARK: İçerik listeleri

    /// Kanal/film/dizi listesini MediaItem listesine dönüştürür.
    func streams(for kind: Kind, categories: [String: String]) async throws -> [MediaItem] {
        let json = try await fetchJSON(creds.apiURL(action: kind.listAction))
        guard let rows = json as? [[String: Any]] else { throw XtreamError.badResponse }

        var out: [MediaItem] = []
        for row in rows {
            let rawID = row.string("stream_id") ?? row.string("series_id")
            guard let id = Int(rawID ?? "") else { continue }
            let name = row.string("name") ?? row.string("title") ?? "İsimsiz"
            let group = categories[row.string("category_id") ?? ""] ?? "Diğer"
            let icon = row.string("stream_icon") ?? row.string("icon") ?? row.string("cover")

            switch kind {
            case .live:
                out.append(MediaItem(
                    id: "xt-live-\(id)", name: name, group: group,
                    logo: Self.tolerantURL(icon),
                    stream: creds.streamURL(root: "live", id: id, ext: "ts"),
                    kind: .live))
            case .vod:
                let ext = row.string("container_extension") ?? "mp4"
                out.append(MediaItem(
                    id: "xt-vod-\(id)", name: name, group: group,
                    logo: Self.tolerantURL(icon),
                    stream: creds.streamURL(root: "movie", id: id, ext: ext),
                    kind: .movie,
                    summary: row.string("plot"),
                    rating: Self.ratingValue(row)))
            case .series:
                out.append(MediaItem(
                    id: "xt-series-\(id)", name: name, group: group,
                    logo: Self.tolerantURL(icon),
                    stream: creds.streamURL(root: "series", id: id, ext: "mp4"),
                    kind: .series,
                    xtreamSeriesID: id,
                    summary: row.string("plot"),
                    rating: Self.ratingValue(row)))
            }
        }
        return out
    }

    // MARK: Dizi bölümleri

    /// Gerçek sezon ve bölüm listesi. Bölüm yayın adresi /series/<u>/<p>/<id>.<ext>
    func seriesInfo(seriesID: Int) async throws -> (seasons: [Int], episodes: [Int: [EpisodeInfo]]) {
        let json = try await fetchJSON(
            creds.apiURL(action: "get_series_info", extra: ["series_id": String(seriesID)]))
        guard let dict = json as? [String: Any],
              let eps = dict["episodes"] as? [String: [[String: Any]]] else {
            throw XtreamError.badResponse
        }

        var bySeason: [Int: [EpisodeInfo]] = [:]
        for (key, list) in eps {
            let season = Int(key) ?? 0
            var rows: [EpisodeInfo] = []
            for row in list {
                guard let id = Int(row.string("id") ?? "") else { continue }
                let ext = row.string("container_extension") ?? "mp4"
                let info = row["info"] as? [String: Any]
                let number = Int(row.string("episode_num") ?? "") ?? 0
                let title = row.string("title") ?? "\(number). Bölüm"
                let image = info?.string("movie_image") ?? row.string("movie_image")
                rows.append(EpisodeInfo(
                    id: id,
                    season: season,
                    number: number,
                    title: title,
                    streamURL: creds.streamURL(root: "series", id: id, ext: ext),
                    image: Self.tolerantURL(image)))
            }
            rows.sort { $0.number < $1.number }
            bySeason[season] = rows
        }
        return (bySeason.keys.sorted(), bySeason)
    }

    /// Sağlayıcının verdiği puanı sayıya çevirir (afiş rozeti için).
    static func ratingValue(_ row: [String: Any]) -> Double? {
        if let d = row["rating"] as? Double { return d }
        if let s = row.string("rating") { return Double(s) }
        return nil
    }

    /// Boşluk veya Türkçe karakter içeren adresleri de kabul eder.
    static func tolerantURL(_ raw: String?) -> URL? {
        guard let raw, !raw.isEmpty else { return nil }
        if let url = URL(string: raw) { return url }
        guard let encoded = raw.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: encoded)
    }
}

// MARK: - JSON yardımcıları

private extension Dictionary where Key == String, Value == Any {
    func string(_ key: String) -> String? {
        if let s = self[key] as? String { return s }
        if let n = self[key] as? NSNumber { return n.stringValue }
        return nil
    }
}
