import SwiftUI

enum Route: String, CaseIterable, Identifiable {
    case home, live, movies, series, favorites, myList, history, settings

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .home: return "house"
        case .live: return "tv"
        case .movies: return "film"
        case .series: return "rectangle.stack"
        case .favorites: return "heart"
        case .myList: return "bookmark"
        case .history: return "clock"
        case .settings: return "gearshape"
        }
    }

    var title: String {
        switch self {
        case .home: return "Ana Sayfa"
        case .live: return "Canlı TV"
        case .movies: return "Filmler"
        case .series: return "Diziler"
        case .favorites: return "Favoriler"
        case .myList: return "Listem"
        case .history: return "Geçmiş"
        case .settings: return "Ayarlar"
        }
    }
}

/// Sol kenar çubuğu ve seçili sayfa. Geniş ekranlarda (iPad, yatay iPhone) kullanılır.
struct AppShell: View {
    @State private var selected: Route = .home

    var body: some View {
        HStack(spacing: 0) {
            SideRail(selected: $selected)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(VSColor.background)
        }
        .background(VSColor.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var content: some View {
        switch selected {
        case .home:     HomeScreen()
        case .live:     LiveTVScreen()
        case .movies:   CategoriesScreen(kind: .movie)
        case .series:   CategoriesScreen(kind: .series)
        case .settings: SettingsScreen()
        default:
            PlaceholderScreen(title: selected.title)
        }
    }
}

struct SideRail: View {
    @Binding var selected: Route

    private let items: [Route] = [.home, .live, .movies, .series, .favorites, .myList, .history]

    var body: some View {
        VStack(spacing: 14) {
            Image("Logo")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)
                .padding(.bottom, 14)

            ForEach(items) { route in
                railButton(route)
            }

            Spacer()

            railButton(.settings)
        }
        .padding(.vertical, 22)
        .frame(width: 104)
        .background(VSColor.rail)
    }

    private func railButton(_ route: Route) -> some View {
        let isOn = selected == route
        return Button {
            selected = route
        } label: {
            Image(systemName: route.symbol)
                .font(.system(size: 20, weight: .regular))
                .foregroundStyle(isOn ? VSColor.accent : .white.opacity(0.85))
                .frame(width: 58, height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isOn ? VSColor.selection : .clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(route.title)
    }
}

/// Henüz tasarlanmamış sayfalar için yer tutucu.
struct PlaceholderScreen: View {
    let title: String
    var body: some View {
        VStack(spacing: 10) {
            Text(title)
                .font(VSFont.outfit(34, bold: true))
                .foregroundStyle(.white)
            Text("Bu bölüm sonraki sürümde eklenecek.")
                .font(VSFont.inter(15))
                .foregroundStyle(VSColor.textMuted)
        }
    }
}
