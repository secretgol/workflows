import SwiftUI
import AVKit

@main
struct IPTVPlayerApp: App {
    @StateObject private var store = Store()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var store: Store
    @State private var search = ""
    @State private var group = "Tümü"
    @State private var showSettings = false
    @State private var playing: Channel?

    private var groups: [String] {
        ["Tümü", "Favoriler"] + Array(Set(store.channels.map(\.group))).sorted()
    }

    private var filtered: [Channel] {
        store.channels.filter { c in
            let g = group == "Tümü" || (group == "Favoriler" ? store.favorites.contains(c.id) : c.group == group)
            return g && (search.isEmpty || c.name.localizedCaseInsensitiveContains(search))
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.channels.isEmpty && !store.loading {
                    VStack(spacing: 12) {
                        Image(systemName: "tv").font(.system(size: 48)).foregroundStyle(.secondary)
                        Text(store.error ?? "Başlamak için M3U listenizi ekleyin.")
                            .multilineTextAlignment(.center).foregroundStyle(.secondary)
                        Button("Liste Ekle") { showSettings = true }.buttonStyle(.borderedProminent)
                    }.padding()
                } else {
                    List(filtered) { c in
                        Button { playing = c } label: { row(c) }
                            .swipeActions {
                                Button { store.toggleFavorite(c) } label: { Label("Favori", systemImage: "star") }
                                    .tint(.yellow)
                            }
                    }
                    .listStyle(.plain)
                    .overlay { if store.loading { ProgressView() } }
                }
            }
            .navigationTitle("IPTV")
            .searchable(text: $search, prompt: "Kanal ara")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Picker("Grup", selection: $group) {
                        ForEach(groups, id: \.self) { Text($0).tag($0) }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: { Image(systemName: "gearshape") }
                }
            }
            .refreshable { await store.load() }
            .task { if !store.playlist.isEmpty && store.channels.isEmpty { await store.load() } }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .fullScreenCover(item: $playing) { PlayerView(channel: $0) }
        }
    }

    private func row(_ c: Channel) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: c.logo) { img in
                img.resizable().scaledToFit()
            } placeholder: {
                Image(systemName: "tv").foregroundStyle(.secondary)
            }
            .frame(width: 44, height: 44)
            VStack(alignment: .leading) {
                Text(c.name).foregroundStyle(.primary)
                Text(c.group).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if store.favorites.contains(c.id) {
                Image(systemName: "star.fill").foregroundStyle(.yellow)
            }
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("M3U Bağlantısı") {
                    TextField("https://...", text: $store.playlist)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                }
                Section {
                    Button("Kaydet ve Yükle") {
                        Task { await store.load(); if store.error == nil { dismiss() } }
                    }
                }
                if let e = store.error { Text(e).foregroundStyle(.red) }
            }
            .navigationTitle("Ayarlar")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Kapat") { dismiss() } } }
        }
    }
}

struct PlayerView: View {
    let channel: Channel
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer

    init(channel: Channel) {
        self.channel = channel
        _player = State(initialValue: AVPlayer(url: channel.url))
    }

    var body: some View {
        VideoPlayer(player: player)
            .ignoresSafeArea()
            .overlay(alignment: .topLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title).foregroundStyle(.white.opacity(0.85))
                }.padding()
            }
            .onAppear {
                try? AVAudioSession.sharedInstance().setCategory(.playback)
                try? AVAudioSession.sharedInstance().setActive(true)
                player.play()
            }
            .onDisappear { player.pause() }
    }
}
