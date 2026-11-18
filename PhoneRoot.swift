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

// MARK: - Ana sayfa: üstte arama, altında büyük afiş kartlı yatay raylar

struct PhoneHome: View {
    @EnvironmentObject private var store: PlaylistStore
    @State private var query = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header

                if store.items.isEmpty {
                    EmptyPlaylistView().frame(height: 360)
                } else if !query.trimmingCharacters(in: .whitespaces).isEmpty {
                    searchResults
                } else {
                    if !store.movies.isEmpty {
                        rail("Filmler", kind: .movie, items: Array(store.movies.prefix(15)))
                    }
                    if !store.series.isEmpty {
                        rail("Diziler", kind: .series, items: Array(store.series.prefix(15)))
                    }
                    if !store.live.isEmpty {
                        rail("Canlı TV", kind: .live, items: Array(store.live.prefix(15)))
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(VSColor.background)
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: MediaItem.self) { MediaDestination(item: $0) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image("Logo")
                .resizable().scaledToFit()
                .frame(width: 40, height: 40)
                .clipShape(Circle())
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(VSColor.textMuted)
                TextField("Kanal, film, dizi ara…", text: $query)
                    .font(VSFont.inter(15))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 14)
            .frame(height: 42)
            .background(Capsule().fill(VSColor.card))
        }
        .padding(.horizontal, 16)
    }

    private var searchResults: some View {
        let text = query.trimmingCharacters(in: .whitespaces)
        let results = store.items.filter { $0.name.localizedCaseInsensitiveContains(text) }
        return VStack(alignment: .leading, spacing: 12) {
            Text("Sonuçlar · \(results.count)")
                .font(VSFont.outfit(20, bold: true))
                .foregroundStyle(.white)
            if results.isEmpty {
                Text("Sonuç bulunamadı.")
                    .font(VSFont.inter(14))
                    .foregroundStyle(VSColor.textMuted)
            } else {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 18) {
                    ForEach(results.prefix(60)) { item in
                        NavigationLink(value: item) {
                            PhoneCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
    }

    private func rail(_ title: String, kind: MediaItem.Kind, items: [MediaItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(VSFont.outfit(20, bold: true))
                    .foregroundStyle(.white)
                Spacer()
                NavigationLink {
                    PhoneCategories(kind: kind)
                } label: {
                    HStack(spacing: 4) {
                        Text("Tümünü göster")
                            .font(VSFont.inter(13, weight: "Medium"))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(VSColor.accent)
                }
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 10) {
                    ForEach(items) { item in
                        NavigationLink(value: item) {
                            PhonePosterCard(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

/// Ana sayfa raylarında kullanılan geniş afiş kartı: görsel + sol altta isim.
struct PhonePosterCard: View {
    let item: MediaItem

    private var symbol: String {
        switch item.kind {
        case .live: return "tv"
        case .movie: return "film"
        case .series: return "rectangle.stack"
        }
    }

    var body: some View {
        RemoteArt(url: item.logo, symbol: symbol, colors: [Color(hex: 0x1B2236), Color(hex: 0x2B3550)])
            .frame(width: 200, height: 118)
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [.clear, Color.black.opacity(0.75)],
                               startPoint: .center, endPoint: .bottom)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                Text(item.name)
                    .font(VSFont.inter(12, weight: "SemiBold"))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
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
                .aspectRatio(2 / 3, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topLeading) {
                    if let rating = item.rating {
                        Text(String(format: "%.0f", rating))
                            .font(VSFont.inter(11, weight: "Bold"))
                            .foregroundStyle(.white)
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color(hex: 0x2E7CD6)))
                            .padding(6)
                    }
                }
            Text(item.name)
                .font(VSFont.inter(13, weight: "SemiBold"))
                .foregroundStyle(.white)
                .lineLimit(2)
            Text(item.summary ?? item.group)
                .font(VSFont.inter(11))
                .foregroundStyle(VSColor.textMuted)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
    }
}

// MARK: - Filmler ve diziler: solda kategori listesi, sağda afiş ızgarası (Smarters düzeni)

struct PhoneCategories: View {
    @EnvironmentObject private var store: PlaylistStore
    let kind: MediaItem.Kind
    @State private var selectedGroup: String?
    @State private var categoryQuery = ""

    private var source: [MediaItem] {
        kind == .movie ? store.movies : store.series
    }

    private var groups: [String] {
        Array(Dictionary(grouping: source, by: \.group).keys).sorted()
    }

    private var filteredGroups: [String] {
        let text = categoryQuery.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? groups : groups.filter { $0.localizedCaseInsensitiveContains(text) }
    }

    private var currentGroup: String? {
        selectedGroup ?? groups.first
    }

    private var visible: [MediaItem] {
        guard let group = currentGroup else { return source }
        return source.filter { $0.group == group }
    }

    var body: some View {
        HStack(spacing: 0) {
            // Sol: arama + kategori listesi (ad + içerik sayısı)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(VSColor.textMuted)
                    TextField("Kategoride ara", text: $categoryQuery)
                        .font(VSFont.inter(12))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
                .background(RoundedRectangle(cornerRadius: 8).fill(VSColor.card))
                .padding(10)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredGroups, id: \.self) { group in
                            categoryRow(group)
                        }
                    }
                }
            }
            .frame(width: 132)
            .background(Color(hex: 0x06070C))

            // Sağ: seçili kategorinin afiş ızgarası
            VStack(alignment: .leading, spacing: 10) {
                Text((currentGroup ?? (kind == .movie ? "Filmler" : "Diziler")).uppercased())
                    .font(VSFont.outfit(18, bold: true))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 10) {
                        ForEach(visible) { item in
                            NavigationLink(value: item) {
                                PhoneCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 14)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .background(VSColor.background)
        .navigationTitle(kind == .movie ? "Filmler" : "Diziler")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: MediaItem.self) { MediaDestination(item: $0) }
    }

    private func categoryRow(_ group: String) -> some View {
        let isOn = currentGroup == group
        let count = source.filter { $0.group == group }.count
        return Button {
            selectedGroup = group
        } label: {
            HStack {
                Text(group)
                    .font(VSFont.inter(12, weight: isOn ? "SemiBold" : "Regular"))
                    .foregroundStyle(isOn ? VSColor.accent : .white)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text("\(count)")
                    .font(VSFont.inter(11))
                    .foregroundStyle(VSColor.textMuted)
            }
            .padding(.horizontal, 10)
            .frame(height: 40)
            .background(isOn ? Color(hex: 0x12352E) : .clear)
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
                        Text("Sürüm 2.0").font(VSFont.inter(13)).foregroundStyle(VSColor.textMuted)
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
                    Text("2.0").foregroundStyle(VSColor.textMuted)
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
