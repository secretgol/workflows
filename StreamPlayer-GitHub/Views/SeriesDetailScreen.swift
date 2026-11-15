import SwiftUI

/// Dizi detayı. Sezon ve bölüm verisi M3U listesinden gelmez; bu ekran yapı örneğidir.
/// Gerçek sezon/bölüm bilgisi için Xtream Codes gibi bir kaynak bağlanmalıdır.
struct SeriesDetailScreen: View {
    let item: MediaItem
    @State private var season = 1

    private let seasons = ["Sezon 1", "Sezon 2", "Sezon 3", "Sezon 4"]

    var body: some View {
        ZStack(alignment: .topLeading) {
            PlaceholderArt(symbol: "rectangle.stack", colors: [Color(hex: 0x1F2A44), Color(hex: 0x0B0F1A)])
                .ignoresSafeArea()
            LinearGradient(colors: [VSColor.background.opacity(0.2), VSColor.background],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            HStack(alignment: .top, spacing: 26) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("DİZİ")
                        .font(VSFont.inter(13, weight: "Bold"))
                        .foregroundStyle(VSColor.accent)
                        .tracking(3)
                    Text(item.name)
                        .font(VSFont.outfit(56, bold: true))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                    Text("Açıklama, sağlayıcının verdiği bilgiyle doldurulur.")
                        .font(VSFont.inter(15))
                        .foregroundStyle(VSColor.textMuted)

                    HStack(spacing: 10) {
                        Button {} label: {
                            Label("Oynat", systemImage: "play.fill")
                                .font(VSFont.inter(16, weight: "SemiBold"))
                                .padding(.horizontal, 26).frame(height: 48)
                                .background(Capsule().fill(.white))
                                .foregroundStyle(.black)
                        }
                        pill("Listeme ekle", "plus")
                        pill("Favorilere ekle", "heart")
                        pill("Fragman", "play.rectangle")
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 48)
            .padding(.top, 40)

            VStack(alignment: .leading, spacing: 18) {
                Spacer().frame(height: 330)
                HStack(alignment: .top, spacing: 22) {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(seasons.indices, id: \.self) { i in
                            Button { season = i + 1 } label: {
                                Text(seasons[i])
                                    .font(VSFont.outfit(18, bold: season == i + 1))
                                    .foregroundStyle(season == i + 1 ? .white : VSColor.textMuted)
                                    .padding(.horizontal, 16).frame(width: 220, height: 50, alignment: .leading)
                                    .background(RoundedRectangle(cornerRadius: 12)
                                        .fill(season == i + 1 ? VSColor.selection : .clear))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    VStack(spacing: 12) {
                        ForEach(1...3, id: \.self) { n in
                            EpisodeRow(number: n, season: season)
                        }
                    }
                }
                .padding(.horizontal, 48)
            }
        }
    }

    private func pill(_ title: String, _ symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(VSFont.inter(15, weight: "Medium"))
            .padding(.horizontal, 18).frame(height: 44)
            .background(Capsule().fill(VSColor.pill.opacity(0.9)))
            .foregroundStyle(.white)
    }
}

struct EpisodeRow: View {
    let number: Int
    let season: Int

    var body: some View {
        HStack(spacing: 18) {
            PlaceholderArt(symbol: "play.rectangle", colors: [Color(hex: 0x1B2236), Color(hex: 0x2B3550)])
                .frame(width: 210, height: 118)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 6) {
                Text("\(number). Bölüm")
                    .font(VSFont.outfit(20, bold: true))
                    .foregroundStyle(.white)
                Text("\(season). sezon · \(20 + number) dk")
                    .font(VSFont.inter(13))
                    .foregroundStyle(VSColor.textSoft)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(VSColor.card))
    }
}
