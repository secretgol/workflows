import SwiftUI

/// Dizi detayı. Xtream Codes girişiyle gerçek sezon ve bölüm listesi gösterilir;
/// M3U dizilerinde yapı örneği kalır ve yayın adresi doğrudan oynatılır.
/// Dar (iPhone) ve geniş (iPad) ekran için uyarlanır; sabit genişlik yoktur.
struct SeriesDetailScreen: View {
    let item: MediaItem
    @EnvironmentObject private var store: PlaylistStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var selectedSeason = 1
    @State private var xtreamSeasons: [Int] = []
    @State private var episodesBySeason: [Int: [EpisodeInfo]] = [:]
    @State private var isLoadingEpisodes = false
    @State private var loadError: String?

    private var compact: Bool { sizeClass == .compact }
    private var hPad: CGFloat { compact ? 16 : 48 }

    private var hasXtream: Bool { item.xtreamSeriesID != nil && store.credentials != nil }

    /// Xtream verisi yoksa gösterim amaçlı örnek sezonlar.
    private var seasonList: [Int] {
        hasXtream && !xtreamSeasons.isEmpty ? xtreamSeasons : [1, 2, 3, 4]
    }

    private var selectedEpisodes: [EpisodeInfo] { episodesBySeason[selectedSeason] ?? [] }

    var body: some View {
        ZStack(alignment: .top) {
            PlaceholderArt(symbol: "rectangle.stack", colors: [Color(hex: 0x1F2A44), Color(hex: 0x0B0F1A)])
                .ignoresSafeArea()
            LinearGradient(colors: [VSColor.background.opacity(0.2), VSColor.background],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: compact ? 18 : 26) {
                    header
                    if compact { seasonChips }
                    episodesSection
                }
                .padding(.top, compact ? 12 : 40)
                .padding(.bottom, 40)
            }
        }
        .task(id: item.id) { await loadEpisodes() }
    }

    // MARK: Üst bölüm

    private var description: String {
        if hasXtream {
            return isLoadingEpisodes ? "Bölümler yükleniyor…" : "Sezon seçin, bölüm listeden izleyin."
        }
        return "Açıklama, sağlayıcının verdiği bilgiyle doldurulur."
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DİZİ")
                .font(VSFont.inter(13, weight: "Bold"))
                .foregroundStyle(VSColor.accent)
                .tracking(3)
            Text(item.name)
                .font(VSFont.outfit(compact ? 34 : 56, bold: true))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.6)
            Text(description)
                .font(VSFont.inter(15))
                .foregroundStyle(VSColor.textMuted)

            playButton

            if !compact {
                HStack(spacing: 10) {
                    pill("Listeme ekle", "plus")
                    pill("Favorilere ekle", "heart")
                    pill("Fragman", "play.rectangle")
                }
            }
        }
        .padding(.horizontal, hPad)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var playButton: some View {
        // Xtream: seçili sezonun ilk bölümünü açar. M3U: dizi yayın adresini doğrudan açar.
        if let first = selectedEpisodes.first {
            NavigationLink {
                PlayerView(item: MediaItem(
                    id: "episode-\(first.id)", name: "\(item.name) · \(first.title)",
                    group: item.group, logo: first.image, stream: first.streamURL, kind: .movie))
            } label: {
                Label("Oynat", systemImage: "play.fill")
                    .font(VSFont.inter(16, weight: "SemiBold"))
                    .padding(.horizontal, 26).frame(height: 48)
                    .background(Capsule().fill(.white))
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        } else if !hasXtream {
            NavigationLink {
                PlayerView(item: item)
            } label: {
                Label("Oynat", systemImage: "play.fill")
                    .font(VSFont.inter(16, weight: "SemiBold"))
                    .padding(.horizontal, 26).frame(height: 48)
                    .background(Capsule().fill(.white))
                    .foregroundStyle(.black)
            }
            .buttonStyle(.plain)
        }
    }

    private func pill(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(VSFont.inter(15, weight: "Medium"))
            .padding(.horizontal, 18).frame(height: 44)
            .background(Capsule().fill(VSColor.pill.opacity(0.9)))
            .foregroundStyle(.white)
    }

    // MARK: Sezonlar

    /// iPhone: yatay kayan sezon çipleri.
    private var seasonChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(seasonList, id: \.self) { number in
                    seasonButton(number, chip: true)
                }
            }
            .padding(.horizontal, hPad)
        }
    }

    private func seasonButton(_ number: Int, chip: Bool = false) -> some View {
        let isOn = selectedSeason == number
        return Button {
            selectedSeason = number
        } label: {
            Text(hasXtream ? "\(number). Sezon" : "Sezon \(number)")
                .font(VSFont.outfit(chip ? 15 : 18, bold: isOn))
                .foregroundStyle(isOn ? .white : VSColor.textMuted)
                .padding(.horizontal, chip ? 14 : 16)
                .frame(height: chip ? 36 : 50)
                .frame(minWidth: chip ? nil : 220, alignment: chip ? .center : .leading)
                .background(RoundedRectangle(cornerRadius: chip ? 18 : 12)
                    .fill(isOn ? VSColor.selection : (chip ? VSColor.card : .clear)))
        }
        .buttonStyle(.plain)
    }

    // MARK: Bölümler

    @ViewBuilder
    private var episodesSection: some View {
        if compact {
            VStack(spacing: 10) { episodeRows }
                .padding(.horizontal, hPad)
        } else {
            HStack(alignment: .top, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(seasonList, id: \.self) { number in
                        seasonButton(number)
                    }
                }
                VStack(spacing: 12) { episodeRows }
            }
            .padding(.horizontal, hPad)
        }
    }

    @ViewBuilder
    private var episodeRows: some View {
        if hasXtream {
            if isLoadingEpisodes {
                ProgressView()
                    .tint(.white)
                    .padding(.vertical, 30)
            } else if let loadError {
                Text(loadError)
                    .font(VSFont.inter(14))
                    .foregroundStyle(VSColor.live)
                    .padding(.vertical, 20)
            } else if selectedEpisodes.isEmpty {
                Text("Bu sezonda bölüm bulunamadı.")
                    .font(VSFont.inter(14))
                    .foregroundStyle(VSColor.textMuted)
                    .padding(.vertical, 20)
            } else {
                ForEach(selectedEpisodes) { episode in
                    EpisodeRow(episode: episode)
                }
            }
        } else {
            ForEach(1...3, id: \.self) { number in
                EpisodeRow(sample: number, season: selectedSeason)
            }
        }
    }

    private func loadEpisodes() async {
        guard let seriesID = item.xtreamSeriesID else { return }
        guard let creds = store.credentials else {
            loadError = "Xtream girişi bulunamadı."
            return
        }
        isLoadingEpisodes = true
        loadError = nil
        defer { isLoadingEpisodes = false }
        do {
            let client = XtreamClient(creds: creds)
            let result = try await client.seriesInfo(seriesID: seriesID)
            xtreamSeasons = result.seasons
            episodesBySeason = result.episodes
            selectedSeason = result.seasons.first ?? 1
        } catch {
            loadError = error.localizedDescription
        }
    }
}

// MARK: - Bölüm satırı

/// Xtream bölümü gerçek veriyle; M3U dizilerinde yer tutucu örnekle çizilir.
/// Dar ekranda küçülerek satırdan taşmaz.
struct EpisodeRow: View {
    var episode: EpisodeInfo?
    var sample: Int = 0
    var season: Int = 1

    @Environment(\.horizontalSizeClass) private var sizeClass
    private var compact: Bool { sizeClass == .compact }

    var body: some View {
        HStack(spacing: compact ? 12 : 18) {
            art
                .frame(width: compact ? 128 : 210, height: compact ? 72 : 118)
                .clipShape(RoundedRectangle(cornerRadius: compact ? 8 : 10))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(VSFont.outfit(compact ? 15 : 20, bold: true))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(subtitle)
                    .font(VSFont.inter(compact ? 12 : 13))
                    .foregroundStyle(VSColor.textSoft)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(compact ? 10 : 14)
        .background(RoundedRectangle(cornerRadius: 16).fill(VSColor.card))
    }

    private var title: String {
        if let episode { return "\(episode.number). \(episode.title)" }
        return "\(sample). Bölüm"
    }

    private var subtitle: String {
        if let episode { return "\(episode.season). sezon" }
        return "\(season). sezon · \(20 + sample) dk"
    }

    @ViewBuilder
    private var art: some View {
        if let image = episode?.image {
            AsyncImage(url: image) { phase in
                if let img = phase.image {
                    img.resizable().scaledToFill()
                } else {
                    PlaceholderArt(symbol: "play.rectangle", colors: artColors)
                }
            }
        } else {
            PlaceholderArt(symbol: "play.rectangle", colors: artColors)
        }
    }

    private var artColors: [Color] { [Color(hex: 0x1B2236), Color(hex: 0x2B3550)] }
}
