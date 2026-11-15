import SwiftUI

@main
struct StreamPlayerApp: App {
    @StateObject private var store = PlaylistStore()
    @AppStorage("playlistURL") private var playlistURL = ""

    var body: some Scene {
        WindowGroup {
            NavigationStack {
                AppShell()
            }
            .environmentObject(store)
            .preferredColorScheme(.dark)
            .task {
                // Kayıtlı liste varsa açılışta yükle
                if !playlistURL.isEmpty && store.items.isEmpty {
                    await store.load(from: playlistURL)
                }
            }
        }
    }
}
