import Foundation

/// Kullanıcının kendi M3U listesinden okunan tek bir kayıt.
struct MediaItem: Identifiable, Hashable {
    enum Kind: String { case live, movie, series }

    let id: String
    let name: String
    let group: String
    let logo: URL?
    let stream: URL
    let kind: Kind
}

enum M3UParser {
    /// Basit M3U/M3U8 ayrıştırıcı: bir #EXTINF satırı ve onu izleyen URL satırı.
    static func parse(_ text: String) -> [MediaItem] {
        var items: [MediaItem] = []
        var pendingName: String?
        var pendingGroup = "Diğer"
        var pendingLogo: URL?

        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("#EXTINF") {
                pendingName = line.components(separatedBy: ",").last?
                    .trimmingCharacters(in: .whitespaces)
                pendingGroup = attribute("group-title", in: line) ?? "Diğer"
                pendingLogo = attribute("tvg-logo", in: line).flatMap(URL.init(string:))
            } else if !line.isEmpty, !line.hasPrefix("#"), let url = URL(string: line) {
                items.append(MediaItem(
                    id: "\(items.count)-\(line)",
                    name: pendingName ?? url.lastPathComponent,
                    group: pendingGroup,
                    logo: pendingLogo,
                    stream: url,
                    kind: classify(group: pendingGroup, url: line)
                ))
                pendingName = nil
                pendingGroup = "Diğer"
                pendingLogo = nil
            }
        }
        return items
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
}

@MainActor
final class PlaylistStore: ObservableObject {
    @Published private(set) var items: [MediaItem] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    var live: [MediaItem]   { items.filter { $0.kind == .live } }
    var movies: [MediaItem] { items.filter { $0.kind == .movie } }
    var series: [MediaItem] { items.filter { $0.kind == .series } }

    func load(from urlString: String) async {
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
            guard let text = String(data: data, encoding: .utf8) else {
                errorMessage = "Liste okunamadı."
                return
            }
            items = M3UParser.parse(text)
            if items.isEmpty {
                errorMessage = "Listede oynatılabilir kayıt bulunamadı."
            }
        } catch {
            errorMessage = "Liste indirilemedi: \(error.localizedDescription)"
        }
    }
}
