import SwiftUI

@main
struct StreamPlayerApp: App {
    @StateObject private var store = PlaylistStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .task {
                    // Kayıtlı kaynak varsa (M3U ya da Xtream) açılışta yükle
                    await store.restoreOnLaunch()
                }
        }
    }
}

/// Dar ekran (iPhone) sekmeli, geniş ekran (iPad) kenar çubuklu düzen kullanır.
struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        if sizeClass == .compact {
            PhoneRootView()
        } else {
            NavigationStack {
                AppShell()
            }
        }
    }
}
