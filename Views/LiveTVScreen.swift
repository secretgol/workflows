import SwiftUI

/// Kanal listesi. Satıra dokunmak doğrudan oynatıcıyı açar.
struct LiveTVScreen: View {
    @EnvironmentObject private var store: PlaylistStore
    @State private var search = ""

    private var filtered: [MediaItem] {
        search.isEmpty ? store.live : store.live.filter {
            $0.name.localizedCaseInsensitiveContains(search)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(filtered) { channel in
                    NavigationLink(value: channel) {
                        ChannelRow(item: channel)
                    }
                    .buttonStyle(.plain)
                }
                if store.live.isEmpty {
                    EmptyPlaylistView().frame(height: 300)
                }
            }
            .padding(22)
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .background(VSColor.background)
        .searchable(text: $search, prompt: "Kanal ara")
        .navigationTitle("Canlı TV")
        .navigationDestination(for: MediaItem.self) { MediaDestination(item: $0) }
    }
}

struct ChannelRow: View {
    let item: MediaItem

    var body: some View {
        HStack(spacing: 16) {
            // Kanal logosu yerine nötr kutu (logolar üçüncü taraf markadır)
            Text(String(item.name.prefix(3)).uppercased())
                .font(VSFont.outfit(15, bold: true))
                .foregroundStyle(.black.opacity(0.7))
                .frame(width: 72, height: 54)
                .background(RoundedRectangle(cornerRadius: 10).fill(.white))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(VSFont.outfit(18, bold: true))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(item.group)
                    .font(VSFont.inter(13, weight: "Medium"))
                    .foregroundStyle(VSColor.accent)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Image(systemName: "play.circle.fill")
                .font(.system(size: 26))
                .foregroundStyle(VSColor.accent)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(VSColor.cardAlt))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.06)))
    }
}
