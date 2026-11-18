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
            RemoteArt(url: item.logo, symbol: symbol, colors: [Color(hex: 0x1B2236), Color(hex: 0x2B3550)])
                .frame(width: 130, height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            Text(item.name)
                .font(VSFont.inter(13, weight: "SemiBold"))
                .foregroundStyle(.white)
                .lineLimit(2)
                .frame(width: 130, alignment: .leading)
            Text(item.summary ?? item.group)
                .font(VSFont.inter(11))
                .foregroundStyle(VSColor.textMuted)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(width: 130, alignment: .leading)
        }
    }
}

// MARK: - Filmler ve diziler: üstte kategori çipleri, altında doğrudan afiş ızgarası

struct PhoneCategories: View {
    @EnvironmentObject private var store: PlaylistStore
    let kind: MediaItem.Kind
    @State private var selectedGroup: String?

    private var source: [MediaItem] {
        kind == .movie ? store.movies : store.series
    }

    private var groups: [String] {
        Array(Dictionary(grouping: source, by: \.group).keys).sorted()
    }

    private var visible: [MediaItem] {
        if let selectedGroup {
            return source.filter { $0.group == selectedGroup }
        }
        return source
    }

    var body: some View {
        VStack(spacing: 0) {
            if source.isEmpty {
                ScrollView {
                    EmptyPlaylistView()
                        .frame(height: 360)
                }
            } else {
                categoryChips
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 18) {
                        ForEach(visible) { item in
                            NavigationLink(value: item) {
                                PhoneCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
        }
        .background(VSColor.background)
        .navigationTitle(kind == .movie ? "Filmler" : "Diziler")
        .navigationDestination(for: MediaItem.self) { MediaDestination(item: $0) }
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("Tümü", selected: selectedGroup == nil) { selectedGroup = nil }
                ForEach(groups, id: \.self) { group in
                    chip(group, selected: selectedGroup == group) { selectedGroup = group }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(VSFont.inter(14, weight: selected ? "SemiBold" : "Regular"))
                .foregroundStyle(selected ? .black : .white)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 34)
                .background(Capsule().fill(selected ? VSColor.accent : VSColor.card))
                .overlay(Capsule().stroke(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
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
            Section("Xtream Codes (önerilen — kapak ve afiş resimleri bununla gelir)") {
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

            Section("M3U listesi (kapak bilgisi taşıyorsa afiş gösterir)") {
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
