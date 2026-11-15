import SwiftUI

struct LiveTVScreen: View {
    @EnvironmentObject private var store: PlaylistStore
    @State private var selected: MediaItem?

    var body: some View {
        HStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(store.live) { channel in
                        Button {
                            selected = channel
                        } label: {
                            ChannelRow(item: channel, isSelected: selected == channel)
                        }
                        .buttonStyle(.plain)
                    }
                    if store.live.isEmpty { EmptyPlaylistView().frame(height: 300) }
                }
                .padding(.vertical, 22)
                .padding(.horizontal, 22)
            }
            .frame(width: 560)

            NowPlayingPanel(channel: selected ?? store.live.first)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .navigationDestination(for: MediaItem.self) { MediaDestination(item: $0) }
    }
}

struct ChannelRow: View {
    let item: MediaItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 16) {
            // Kanal logosu yerine nötr kutu (logolar üçüncü taraf markadır)
            Text(String(item.name.prefix(3)).uppercased())
                .font(VSFont.outfit(15, bold: true))
                .foregroundStyle(.black.opacity(0.7))
                .frame(width: 84, height: 62)
                .background(RoundedRectangle(cornerRadius: 10).fill(.white))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(VSFont.outfit(20, bold: true))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text("Şimdi yayında · \(item.group)")
                    .font(VSFont.inter(14, weight: "Medium"))
                    .foregroundStyle(VSColor.accent)
                    .lineLimit(1)
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(height: 4)
                    .overlay(alignment: .leading) {
                        Capsule().fill(VSColor.accent).frame(width: 220, height: 4)
                    }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(VSColor.cardAlt))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isSelected ? VSColor.accent : Color.white.opacity(0.06), lineWidth: isSelected ? 2 : 1)
        )
    }
}

struct NowPlayingPanel: View {
    let channel: MediaItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer()
            if let channel {
                HStack(spacing: 12) {
                    Text("CANLI")
                        .font(VSFont.inter(13, weight: "Bold"))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(VSColor.live, in: RoundedRectangle(cornerRadius: 6))
                        .foregroundStyle(.white)
                    Text(channel.name)
                        .font(VSFont.inter(15))
                        .foregroundStyle(VSColor.textMuted)
                }
                Text(channel.name)
                    .font(VSFont.outfit(54, bold: true))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Text("Program bilgisi, sağlayıcının EPG kaynağı eklendiğinde burada görünür.")
                    .font(VSFont.inter(17))
                    .foregroundStyle(VSColor.textMuted)
                NavigationLink(value: channel) {
                    Label("İzle", systemImage: "play.fill")
                        .font(VSFont.inter(16, weight: "SemiBold"))
                        .padding(.horizontal, 28).frame(height: 50)
                        .background(Capsule().fill(.white))
                        .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            } else {
                Text("Bir kanal seçin")
                    .font(VSFont.outfit(30, bold: true))
                    .foregroundStyle(VSColor.textMuted)
            }
            Spacer()
        }
        .padding(.horizontal, 60)
    }
}
