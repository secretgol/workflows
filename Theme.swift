import SwiftUI

/// Renkler, ekran görüntülerinden piksel düzeyinde ölçüldü.
enum VSColor {
    static let background = Color(hex: 0x0B0F1A)   // ana zemin
    static let rail       = Color(hex: 0x06070C)   // sol kenar çubuğu
    static let card       = Color(hex: 0x131720)   // bölüm kartları
    static let cardAlt    = Color(hex: 0x141823)   // kanal listesi kartı
    static let selection  = Color(hex: 0x174B34)   // seçili menü öğesi arka planı
    static let accent     = Color(hex: 0x87ECAA)   // yeşil vurgu, ilerleme, seçim kenarı
    static let live       = Color(hex: 0xEB6280)   // LIVE rozeti
    static let imdb       = Color(hex: 0xF5C518)   // IMDb rozeti
    static let textMuted  = Color(hex: 0xA7B5D2)
    static let textSoft   = Color(hex: 0x7C8499)
    static let pill       = Color(hex: 0x44474C)   // ikincil buton
}

/// Ana sayfa kategori kartları ve ayar kartları için gradyanlar.
enum VSTone {
    static let liveTV   = [Color(hex: 0x3D2A10), Color(hex: 0x6E4A14)]
    static let movies   = [Color(hex: 0x14244A), Color(hex: 0x2B4C8C)]
    static let series   = [Color(hex: 0x2C1E4E), Color(hex: 0x5B4590)]
    static let favorite = [Color(hex: 0x4A1A22), Color(hex: 0x8A2F3E)]
    static let myList   = [Color(hex: 0x0B2B28), Color(hex: 0x1F6B62)]

    static let general  = [Color(hex: 0x3A1F15), Color(hex: 0x6B3A28)]
    static let language = [Color(hex: 0x4A3C18), Color(hex: 0x7A6530)]
    static let view     = [Color(hex: 0x3E4118), Color(hex: 0x5F6428)]
    static let design   = [Color(hex: 0x2F4A1C), Color(hex: 0x4E7A30)]
    static let menu     = [Color(hex: 0x1E4020), Color(hex: 0x2F6A34)]
    static let player   = [Color(hex: 0x1C4A2A), Color(hex: 0x2F7A46)]
    static let audio    = [Color(hex: 0x12403A), Color(hex: 0x1F6A5C)]
    static let genres   = [Color(hex: 0x123D40), Color(hex: 0x1E6468)]
    static let liveGuide = [Color(hex: 0x12334A), Color(hex: 0x1E5577)]
    static let playlists = [Color(hex: 0x162649), Color(hex: 0x27407A)]
    static let profiles = [Color(hex: 0x1F1D57), Color(hex: 0x352F8A)]
    static let apiKeys  = [Color(hex: 0x2C1A55), Color(hex: 0x4C2E8A)]
    static let parental = [Color(hex: 0x2B1A4E), Color(hex: 0x47297A)]
    static let memory   = [Color(hex: 0x3D1A44), Color(hex: 0x62296B)]
    static let diagnostics = [Color(hex: 0x3D1A2A), Color(hex: 0x66283F)]
    static let about    = [Color(hex: 0x4A1F26), Color(hex: 0x722F36)]
}

enum VSFont {
    static func outfit(_ size: CGFloat, bold: Bool = false) -> Font {
        .custom(bold ? "Outfit-Bold" : "Outfit-Regular", size: size)
    }
    static func inter(_ size: CGFloat, weight: String = "Regular") -> Font {
        .custom("Inter-\(weight)", size: size)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// Telif içeren görseller yerine kullanılan nötr yer tutucu.
struct PlaceholderArt: View {
    let symbol: String
    let colors: [Color]
    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            Image(systemName: symbol)
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.white.opacity(0.35))
        }
    }
}

/// Adresteki logo/afisi indirip gösterir; adres yoksa ya da yüklenemezse nötr yer tutucu çizer.
struct RemoteArt: View {
    let url: URL?
    let symbol: String
    let colors: [Color]

    var body: some View {
        ZStack {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .empty, .failure:
                        PlaceholderArt(symbol: symbol, colors: colors)
                    @unknown default:
                        PlaceholderArt(symbol: symbol, colors: colors)
                    }
                }
            } else {
                PlaceholderArt(symbol: symbol, colors: colors)
            }
        }
    }
}
