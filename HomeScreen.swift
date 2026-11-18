import SwiftUI

struct HomeScreen: View {
    @EnvironmentObject private var store: PlaylistStore
    @State private var query = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                SearchField(text: $query)
                    .padding(.horizontal, 28)

                if store.items.isEmpty {
                    EmptyPlaylistView()
                        .frame(height: 360)
                } else {
                    HeroBanner(item: store.movies.first ?? store.live.first)

                    CategoryTiles()
                        .padding(.horizontal, 28)

                    if !store.live.isEmpty {
                        RailHeader(title: "Canlı TV", destination: .live)
                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 14) {
                                ForEach(store.live.prefix(20)) { item in
                                    NavigationLink(value: item) {
                                        LiveCard(item: item)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 28)
                        }
                    }
                }
            }
            .padding(.vertical, 22)
        }
        .navigationDestination(for: MediaItem.self) { MediaDestination(item: $0) }
    }
}

struct SearchField: View {
    @Binding var text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(VSColor.textMuted)
            TextField("Kanal, film, dizi ara…", text: $text)
                .font(VSFont.inter(16))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18)
        .frame(height: 48)
        .background(
            Capsule().fill(VSColor.card)
                .overlay(Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1))
        )
    }
}

/// Üstteki büyük öne çıkan alan. Yer tutucu görsel ve başlıkla.
struct HeroBanner: View {
    let item: MediaItem?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteArt(url: item?.logo, symbol: "film.stack", colors: [Color(hex: 0x3A1E22), Color(hex: 0x0B0F1A)])
                .frame(height: 360)
            LinearGradient(colors: [.clear, VSColor.background], startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 12) {
                Text("FİLM · HD")
                    .font(VSFont.inter(13, weight: "Bold"))
                    .foregroundStyle(VSColor.accent)
                    .tracking(3)
                Text(item?.name ?? "Başlık")
                    .font(VSFont.outfit(52, bold: true))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                HStack(spacing: 10) {
                    Text(item?.summary ?? item?.group ?? "")
                        .font(VSFont.inter(14))
                        .foregroundStyle(VSColor.textMuted)
                        .lineLimit(1)
                    Text(item?.group ?? "")
                        .font(VSFont.inter(12, weight: "Bold"))
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(VSColor.pill, in: RoundedRectangle(cornerRadius: 5))
                        .foregroundStyle(.white)
                }
                HStack(spacing: 12) {
                    if let item {
                        NavigationLink(value: item) {
                            Label("Şimdi izle", systemImage: "play.fill")
                                .font(VSFont.inter(16, weight: "SemiBold"))
                                .padding(.horizontal, 28).frame(height: 50)
                                .background(Capsule().fill(.white))
                                .foregroundStyle(.black)
                        }
                        .buttonStyle(.plain)
                    }
                    Label("Daha fazla bilgi", systemImage: "info.circle")
                        .font(VSFont.inter(16, weight: "SemiBold"))
                        .padding(.horizontal, 24).frame(height: 50)
                        .background(Capsule().fill(VSColor.pill))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .frame(height: 360)
        .clipped()
    }
}

/// Canlı TV / Filmler / Diziler / Favoriler / Listem kutuları.
struct CategoryTiles: View {
    var body: some View {
        HStack(spacing: 14) {
            tile("Canlı TV", "tv", VSTone.liveTV, .live)
            tile("Filmler", "film", VSTone.movies, .movies)
            tile("Diziler", "rectangle.stack", VSTone.series, .series)
            tile("Favoriler", "heart", VSTone.favorite, .favorites)
            tile("Listem", "bookmark", VSTone.myList, .myList)
        }
    }

    private func tile(_ title: String, _ symbol: String, _ colors: [Color], _ route: Route) -> some View {
        HStack {
            Image(systemName: symbol).font(.system(size: 22))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(VSFont.outfit(18, bold: true))
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .frame(height: 76)
        .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08)))
    }
}

struct RailHeader: View {
    let title: String
    let destination: Route

    private var destinationView: some View {
        switch destination {
        case .live: return AnyView(LiveTVScreen())
        case .movies: return AnyView(CategoriesScreen(kind: .movie))
        case .series: return AnyView(CategoriesScreen(kind: .series))
        default: return AnyView(PlaceholderScreen(title: destination.title))
        }
    }

    var body: some View {
        HStack {
            Text(title)
                .font(VSFont.outfit(24, bold: true))
                .foregroundStyle(.white)
            Spacer()
            NavigationLink { destinationView } label: {
                HStack(spacing: 4) {
                    Text("Tümünü göster")
                        .font(VSFont.inter(14, weight: "Medium"))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(VSColor.accent)
            }
        }
        .padding(.horizontal, 28)
    }
}

struct LiveCard: View {
    let item: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(Color(hex: 0x0B0F1A))
                if let logo = item.logo {
                    AsyncImage(url: logo) { phase in
                        if let img = phase.image {
                            img.resizable().scaledToFill()
                        } else {
                            initials
                        }
                    }
                } else {
                    initials
                }
            }
            .frame(height: 74)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(item.name)
                .font(VSFont.inter(14, weight: "SemiBold"))
                .foregroundStyle(.white)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text("CANLI")
                    .font(VSFont.inter(10, weight: "Bold"))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(VSColor.live, in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(.white)
                Text(item.group)
                    .font(VSFont.inter(12))
                    .foregroundStyle(VSColor.textSoft)
                    .lineLimit(1)
            }
        }
        .padding(14)
        .frame(width: 230, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(VSColor.card))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.07)))
    }

    private var initials: some View {
        Text(String(item.name.prefix(2)).uppercased())
            .font(VSFont.outfit(26, bold: true))
            .foregroundStyle(VSColor.textMuted)
    }
}

struct EmptyPlaylistView: View {
    @EnvironmentObject private var store: PlaylistStore

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 40))
                .foregroundStyle(VSColor.textSoft)
            Text("Henüz liste yüklenmedi")
                .font(VSFont.outfit(20, bold: true))
                .foregroundStyle(.white)
            Text("Ulusal kanalları tek dokunuşla yükleyebilir ya da Ayarlar › Liste'den Xtream Codes ile kendi listelerinizi ekleyebilirsiniz — kapak ve afiş resimleri Xtream ile gelir.")
                .font(VSFont.inter(14))
                .foregroundStyle(VSColor.textMuted)
                .multilineTextAlignment(.center)
            Button {
                Task { await store.loadLocalChannels() }
            } label: {
                Label("Ulusal kanalları yükle", systemImage: "antenna.radiowaves.left.and.right")
                    .font(VSFont.inter(15, weight: "SemiBold"))
                    .padding(.horizontal, 20).frame(height: 44)
                    .background(Capsule().fill(VSColor.accent))
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
            .disabled(store.isLoading)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
