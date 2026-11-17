import SwiftUI

struct SettingsScreen: View {
    @EnvironmentObject private var store: PlaylistStore
    @AppStorage("playlistURL") private var playlistURL = ""
    @State private var showPlaylist = false

    private struct Card: Identifiable {
        let id = UUID()
        let title: String
        let subtitle: String
        let symbol: String
        let colors: [Color]
    }

    private let cards: [Card] = [
        .init(title: "Genel", subtitle: "Başlangıç, çıkış, otomatik başlatma", symbol: "gearshape", colors: VSTone.general),
        .init(title: "Dil ve bölge", subtitle: "Dil, saat, saat dilimi", symbol: "globe", colors: VSTone.language),
        .init(title: "Görünüm", subtitle: "Kart boyutu, ızgara", symbol: "square.grid.2x2", colors: VSTone.view),
        .init(title: "Tasarım", subtitle: "Renkler, yazı tipi, animasyonlar", symbol: "sparkles", colors: VSTone.design),
        .init(title: "Menü", subtitle: "Sıra ve girişler", symbol: "list.bullet", colors: VSTone.menu),
        .init(title: "Oynatıcı", subtitle: "Arama, giriş, kalite", symbol: "play", colors: VSTone.player),
        .init(title: "Ses ve altyazı", subtitle: "Diller, CC, altyazı stili", symbol: "music.note", colors: VSTone.audio),
        .init(title: "Türler ve kategoriler", subtitle: "Otomatik türler, kategoriler", symbol: "tag", colors: VSTone.genres),
        .init(title: "Canlı TV ve rehber", subtitle: "Program rehberi, kanal listeleri", symbol: "dot.radiowaves.left.and.right", colors: VSTone.liveGuide),
        .init(title: "Playlists", subtitle: "Liste yönetimi, güncelleme", symbol: "arrow.down.circle", colors: VSTone.playlists),
        .init(title: "Profiller", subtitle: "Geçmiş, favoriler, kişi bazlı kilit", symbol: "person", colors: VSTone.profiles),
        .init(title: "API anahtarları", subtitle: "TMDB, IMDb, Rotten Tomatoes", symbol: "star", colors: VSTone.apiKeys),
        .init(title: "Ebeveyn denetimi", subtitle: "PIN, yetişkin içeriği", symbol: "lock", colors: VSTone.parental),
        .init(title: "Bellek", subtitle: "Önbellek, geçmiş, devam", symbol: "internaldrive", colors: VSTone.memory),
        .init(title: "Tanılama", subtitle: "Durum ve sorun giderme", symbol: "waveform.path.ecg", colors: VSTone.diagnostics),
        .init(title: "Hakkında", subtitle: "Sürüm, kaynaklar, sıfırlama", symbol: "info.circle", colors: VSTone.about),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Ayarlar")
                        .font(VSFont.outfit(42, bold: true))
                        .foregroundStyle(.white)
                    Text("Görünüm, oynatma ve hesap ayarları")
                        .font(VSFont.inter(16))
                        .foregroundStyle(VSColor.textMuted)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 14)], spacing: 14) {
                    ForEach(cards) { card in
                        Button {
                            if card.title == "Playlists" { showPlaylist = true }
                        } label: {
                            SettingsTile(title: card.title, subtitle: card.subtitle,
                                         symbol: card.symbol, colors: card.colors)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(28)
        }
        .sheet(isPresented: $showPlaylist) {
            PlaylistSheet()
                .environmentObject(store)
        }
    }
}

struct SettingsTile: View {
    let title: String
    let subtitle: String
    let symbol: String
    let colors: [Color]

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 18))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.white.opacity(0.10)))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(VSFont.outfit(20, bold: true))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(VSFont.inter(13))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .leading)
        .background(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.08)))
    }
}

/// Liste kaynaklarını yönetme: M3U adresi, Xtream Codes girişi, ulusal kanallar.
struct PlaylistSheet: View {
    @EnvironmentObject private var store: PlaylistStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("playlistURL") private var playlistURL = ""
    @AppStorage("xtreamHost") private var xtreamHost = ""
    @AppStorage("xtreamUser") private var xtreamUser = ""
    @AppStorage("xtreamPass") private var xtreamPass = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Ulusal kanallar (TR)") {
                    Button {
                        Task { await store.loadLocalChannels() }
                    } label: {
                        HStack {
                            Label("Türkiye kanal listesini yükle", systemImage: "antenna.radiowaves.left.and.right")
                            Spacer()
                            if store.isLoading { ProgressView() }
                        }
                    }
                    .disabled(store.isLoading)
                }

                Section("Kendi M3U listem") {
                    TextField("https://…/liste.m3u", text: $playlistURL)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    Button {
                        Task { await store.loadM3U(from: playlistURL) }
                    } label: {
                        HStack {
                            Text("Listeyi yükle")
                            Spacer()
                            if store.isLoading { ProgressView() }
                        }
                    }
                    .disabled(playlistURL.trimmingCharacters(in: .whitespaces).isEmpty || store.isLoading)
                }

                Section("Xtream Codes") {
                    TextField("http://sunucu:8080", text: $xtreamHost)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()
                    TextField("Kullanıcı adı", text: $xtreamUser)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Şifre", text: $xtreamPass)
                    Button {
                        Task { await store.loadXtream(host: xtreamHost, user: xtreamUser, pass: xtreamPass) }
                    } label: {
                        HStack {
                            Text("Giriş yap ve listeyi yükle")
                            Spacer()
                            if store.isLoading { ProgressView() }
                        }
                    }
                    .disabled(xtreamHost.trimmingCharacters(in: .whitespaces).isEmpty
                              || xtreamUser.trimmingCharacters(in: .whitespaces).isEmpty
                              || xtreamPass.isEmpty || store.isLoading)
                }

                Section {
                    if let message = store.errorMessage {
                        Text(message).foregroundStyle(.red).font(VSFont.inter(13))
                    } else if !store.items.isEmpty {
                        Text("\(store.items.count) kayıt · canlı \(store.live.count) · film \(store.movies.count) · dizi \(store.series.count)")
                            .foregroundStyle(VSColor.textMuted).font(VSFont.inter(13))
                    }
                } footer: {
                    Text("Uygulama içerik sunmaz; yalnızca sizin sağladığınız listeyi oynatır.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(VSColor.background)
            .navigationTitle("Playlists")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}
