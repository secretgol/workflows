import SwiftUI

/// iPhone için kök görünüm: beş sade sekme.
struct PhoneRootView: View {
    var body: some View {
        TabView {
            NavigationStack { PhoneHome() }
                .tabItem { Label("Ana Sayfa", systemImage: "house") }

            NavigationStack { LiveTVScreen() }
                .tabItem { Label("Canlı TV", systemImage: "tv") }

            NavigationStack { PhoneCategories(kind: .movie) }
                .tabItem { Label("Filmler", systemImage: "film") }

            NavigationStack { PhoneCategories(kind: .series) }
                .tabItem { Label("Diziler", systemImage: "rectangle.stack") }

            NavigationStack { PhoneSettings() }
                .tabItem { Label("Ayarlar", systemImage: "gearshape") }
        }
        .tint(VSColor.accent)
    }
}

// MARK: - Ana sayfa: yalnızca dikey raylar

struct PhoneHome: View {
    @EnvironmentObject private var store: PlaylistStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                if store.items.isEmpty {
                    EmptyPlaylistView().frame(height: 360)
                } else {
                    PhoneRail(title: "Canlı TV", items: Array(store.live.prefix(12)))
                    PhoneRail(title: "Filmler", items: Array(store.movies.prefix(12)))
                    PhoneRail(title: "Diziler", items: Array(store.series.prefix(12)))
                }
            }
            .padding(.vertical, 16)
        }
        .background(VSColor.background)
        .navigationTitle("Ana Sayfa")
        .navigationDestination(for: MediaItem.self) { MediaDestination(item: $0) }
    }
}

struct PhoneRail: View {
    let title: String
    let items: [MediaItem]

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(VSFont.outfit(20, bold: true))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(items) { item in
                            NavigationLink(value: item) {
                                PhoneCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }
}

struct PhoneCard: View {
    let item: MediaItem

    private var symbol: String {
        switch item.kind {
        case .live: return "tv"
        case .movie: return "film"
        case .series: return "rectangle.stack"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            PlaceholderArt(symbol: symbol, colors: [Color(hex: 0x1B2236), Color(hex: 0x2B3550)])
                .frame(width: 130, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(item.name)
                .font(VSFont.inter(13, weight: "SemiBold"))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(width: 130, alignment: .leading)
        }
    }
}

// MARK: - Filmler ve diziler: grup listesi, sonra ızgara

struct PhoneCategories: View {
    @EnvironmentObject private var store: PlaylistStore
    let kind: MediaItem.Kind

    private var source: [MediaItem] {
        kind == .movie ? store.movies : store.series
    }

    private var groups: [GroupInfo] {
        Dictionary(grouping: source, by: \.group)
            .map { GroupInfo(name: $0.key, count: $0.value.count) }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        List {
            if source.isEmpty {
                Text("Liste yüklenmedi. Ayarlar'dan M3U adresinizi ekleyin.")
                    .font(VSFont.inter(14))
                    .foregroundStyle(VSColor.textMuted)
                    .listRowBackground(VSColor.card)
            }
            ForEach(groups) { group in
                NavigationLink {
                    PhoneGrid(items: source.filter { $0.group == group.name }, title: group.name)
                } label: {
                    HStack {
                        Text(group.name)
                            .font(VSFont.inter(16))
                            .foregroundStyle(.white)
                        Spacer()
                        Text("\(group.count)")
                            .font(VSFont.inter(14))
                            .foregroundStyle(VSColor.textMuted)
                    }
                }
                .listRowBackground(VSColor.card)
            }
        }
        .scrollContentBackground(.hidden)
        .background(VSColor.background)
        .navigationTitle(kind == .movie ? "Filmler" : "Diziler")
        .navigationDestination(for: MediaItem.self) { MediaDestination(item: $0) }
    }
}

struct GroupInfo: Identifiable {
    let name: String
    let count: Int
    var id: String { name }
}

struct PhoneGrid: View {
    let items: [MediaItem]
    let title: String

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 18) {
                ForEach(items) { item in
                    NavigationLink(value: item) {
                        PhoneCard(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
        }
        .background(VSColor.background)
        .navigationTitle(title)
        .navigationDestination(for: MediaItem.self) { MediaDestination(item: $0) }
    }
}

// MARK: - Ayarlar: sade liste

struct PhoneSettings: View {
    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image("Logo").resizable().scaledToFit().frame(width: 52, height: 52)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stream Player").font(VSFont.outfit(20, bold: true)).foregroundStyle(.white)
                        Text("Sürüm 1.0").font(VSFont.inter(13)).foregroundStyle(VSColor.textMuted)
                    }
                }
                .listRowBackground(VSColor.card)
            }

            Section {
                NavigationLink {
                    PlaylistForm()
                } label: {
                    Label("Liste (M3U) adresi", systemImage: "list.bullet.rectangle")
                }
                .listRowBackground(VSColor.card)
            } footer: {
                Text("Uygulama içerik sunmaz. Yalnızca sizin sağladığınız listeyi oynatır.")
            }

            Section {
                HStack {
                    Text("Sürüm")
                    Spacer()
                    Text("1.0").foregroundStyle(VSColor.textMuted)
                }
                .listRowBackground(VSColor.card)
            }
        }
        .scrollContentBackground(.hidden)
        .background(VSColor.background)
        .navigationTitle("Ayarlar")
    }
}

/// Liste kaynaklarını yönetme formu: M3U adresi, Xtream Codes girişi, ulusal kanallar.
struct PlaylistForm: View {
    @EnvironmentObject private var store: PlaylistStore
    @AppStorage("playlistURL") private var playlistURL = ""
    @AppStorage("xtreamHost") private var xtreamHost = ""
    @AppStorage("xtreamUser") private var xtreamUser = ""
    @AppStorage("xtreamPass") private var xtreamPass = ""

    var body: some View {
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
                .listRowBackground(VSColor.card)
            }

            Section("Kendi M3U listem") {
                TextField("https://…/liste.m3u", text: $playlistURL)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .listRowBackground(VSColor.card)

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
                .listRowBackground(VSColor.card)
            }

            Section("Xtream Codes") {
                TextField("http://sunucu:8080", text: $xtreamHost)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .autocorrectionDisabled()
                    .listRowBackground(VSColor.card)
                TextField("Kullanıcı adı", text: $xtreamUser)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .listRowBackground(VSColor.card)
                SecureField("Şifre", text: $xtreamPass)
                    .listRowBackground(VSColor.card)

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
                .listRowBackground(VSColor.card)
            }

            Section {
                if let message = store.errorMessage {
                    Text(message).foregroundStyle(.red).font(VSFont.inter(14))
                } else if !store.items.isEmpty {
                    Text("\(store.items.count) kayıt yüklendi")
                        .foregroundStyle(VSColor.accent).font(VSFont.inter(14))
                    Text("Canlı \(store.live.count) · Film \(store.movies.count) · Dizi \(store.series.count)")
                        .foregroundStyle(VSColor.textMuted).font(VSFont.inter(13))
                }
            }
            .listRowBackground(VSColor.card)
        }
        .scrollContentBackground(.hidden)
        .background(VSColor.background)
        .navigationTitle("Liste")
        .navigationBarTitleDisplayMode(.inline)
    }
}
