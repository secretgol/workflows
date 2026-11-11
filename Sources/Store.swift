import Foundation

struct Channel: Identifiable, Hashable {
    let name: String
    let logo: URL?
    let group: String
    let url: URL
    var id: String { name + "|" + url.absoluteString }
}

enum M3UParser {
    static func parse(_ text: String) -> [Channel] {
        var result: [Channel] = []
        var pending: (name: String, logo: URL?, group: String)?
        for raw in text.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#EXTINF") {
                var name = "Kanal"
                if let comma = line.lastIndex(of: ",") {
                    let n = line[line.index(after: comma)...].trimmingCharacters(in: .whitespaces)
                    if !n.isEmpty { name = n }
                }
                pending = (name,
                           attr("tvg-logo", in: line).flatMap { URL(string: $0) },
                           attr("group-title", in: line) ?? "Diğer")
            } else if !line.isEmpty, !line.hasPrefix("#"), let p = pending, let url = URL(string: line) {
                result.append(Channel(name: p.name, logo: p.logo, group: p.group, url: url))
                pending = nil
            }
        }
        return result
    }

    private static func attr(_ key: String, in line: String) -> String? {
        guard let r = line.range(of: key + "=\"") else { return nil }
        let rest = line[r.upperBound...]
        guard let end = rest.firstIndex(of: "\"") else { return nil }
        let v = String(rest[..<end])
        return v.isEmpty ? nil : v
    }
}

@MainActor
final class Store: ObservableObject {
    @Published var channels: [Channel] = []
    @Published var loading = false
    @Published var error: String?

    @Published var playlist: String = UserDefaults.standard.string(forKey: "playlist") ?? "" {
        didSet { UserDefaults.standard.set(playlist, forKey: "playlist") }
    }
    @Published var favorites: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "fav") ?? []) {
        didSet { UserDefaults.standard.set(Array(favorites), forKey: "fav") }
    }

    func toggleFavorite(_ c: Channel) {
        if favorites.contains(c.id) { favorites.remove(c.id) } else { favorites.insert(c.id) }
    }

    func load() async {
        guard let url = URL(string: playlist.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme?.hasPrefix("http") == true else {
            error = "Geçerli bir M3U bağlantısı girin."
            return
        }
        loading = true
        error = nil
        defer { loading = false }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let text = String(decoding: data, as: UTF8.self)
            let list = M3UParser.parse(text)
            channels = list
            if list.isEmpty { error = "Listede kanal bulunamadı." }
        } catch {
            self.error = "Liste yüklenemedi: \(error.localizedDescription)"
        }
    }
}
