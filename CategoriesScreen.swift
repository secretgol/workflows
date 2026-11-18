import SwiftUI

struct CategoriesScreen: View {
    @EnvironmentObject private var store: PlaylistStore
    let kind: MediaItem.Kind
    @State private var selectedGroup: String?

    private var source: [MediaItem] {
        kind == .movie ? store.movies : store.series
    }

    /// Grup adına göre kategoriler, öğe sayısıyla birlikte.
    private var categories: [(name: String, count: Int)] {
        Dictionary(grouping: source, by: \.group)
            .map { (name: $0.key, count: $0.value.count) }
            .sorted { $0.name < $1.name }
    }

    private var visible: [MediaItem] {
        guard let g = selectedGroup ?? categories.first?.name else { return source }
        return source.filter { $0.group == g }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(kind == .movie ? "Filmler · Kategoriler" : "Diziler · Kategoriler")
                .font(VSFont.outfit(38, bold: true))
                .foregroundStyle(.white)

            HStack(spacing: 12) {
                chip("Otomatik tür", "wand.and.stars")
                chip("Varsayılan", "arrow.up.arrow.down")
                chip("Liste", "square.grid.2x2")
                Spacer()
                Text("\(categories.count) kategori")
                    .font(VSFont.inter(14))
                    .foregroundStyle(VSColor.textMuted)
            }

            if source.isEmpty {
                EmptyPlaylistView()
            } else {
                HStack(alignment: .top, spacing: 26) {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(categories, id: \.name) { cat in
                                categoryRow(cat.name, cat.count)
                            }
                        }
                    }
                    .frame(width: 300)

                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 18) {
                            ForEach(visible) { item in
                                NavigationLink(value: item) {
                                    PosterTile(item: item)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(28)
        .navigationDestination(for: MediaItem.self) { MediaDestination(item: $0) }
    }

    private func categoryRow(_ name: String, _ count: Int) -> some View {
        let isOn = (selectedGroup ?? categories.first?.name) == name
        return Button {
            selectedGroup = name
        } label: {
            HStack {
                Text(name)
                    .font(VSFont.inter(17, weight: isOn ? "SemiBold" : "Regular"))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Text("\(count)")
                    .font(VSFont.inter(15))
                    .foregroundStyle(VSColor.textMuted)
            }
            .padding(.horizontal, 18)
            .frame(height: 52)
            .background(RoundedRectangle(cornerRadius: 12).fill(isOn ? Color(hex: 0x41444B) : .clear))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(isOn ? VSColor.accent : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private func chip(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(VSFont.inter(14, weight: "Medium"))
            .foregroundStyle(.white)
            .padding(.horizontal, 16).frame(height: 40)
            .background(Capsule().fill(VSColor.card))
            .overlay(Capsule().stroke(Color.white.opacity(0.1)))
    }
}

struct PosterTile: View {
    let item: MediaItem
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RemoteArt(url: item.logo,
                      symbol: item.kind == .series ? "rectangle.stack" : "film",
                      colors: [Color(hex: 0x1B2236), Color(hex: 0x2B3550)])
                .aspectRatio(2 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(item.name)
                .font(VSFont.inter(13, weight: "SemiBold"))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(item.summary ?? item.group)
                .font(VSFont.inter(11))
                .foregroundStyle(VSColor.textMuted)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
}
