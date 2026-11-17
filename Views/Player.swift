import SwiftUI
import AVKit
import Combine
import MobileVLCKit

/// Öğe türüne göre doğru ekranı açar: diziler detay ekranına, diğerleri doğrudan oynatıcıya.
struct MediaDestination: View {
    let item: MediaItem

    var body: some View {
        if item.kind == .series {
            SeriesDetailScreen(item: item)
        } else {
            PlayerView(item: item)
        }
    }
}

// MARK: - Motor seçimi

enum PlaybackEngine {
    case av, vlc

    /// Yerleşik oynatıcının desteklediği biçimler. Geri kalan her şey (MPEG-TS,
    /// MKV, AVI, FLV, WebM…) doğrudan VLC motoruyla açılır.
    private static let avExtensions: Set<String> =
        ["m3u8", "mp4", "m4v", "mov", "mp3", "m4a", "aac", "flac", "wav"]

    static func preferred(for url: URL) -> PlaybackEngine {
        let ext = url.pathExtension.lowercased()
        if avExtensions.contains(ext) { return .av }
        let full = url.absoluteString.lowercased()
        if ext.isEmpty && full.contains(".m3u8") { return .av }
        return .vlc
    }
}

// MARK: - Apple (yerleşik) motor

/// AVPlayer durumunu izler. Hata olursa ekranda nedeni gösterilir ve VLC'ye geçilir.
@MainActor
final class AVPlaybackModel: ObservableObject {
    @Published var message = "Yükleniyor…"
    @Published var failed = false

    let player: AVPlayer
    private var cancellables = Set<AnyCancellable>()

    init(url: URL, userAgent: String?, referrer: String?) {
        // M3U'daki #EXTVLCOPT ayarları burada başlık olarak iletilir.
        var headers: [String: String] = [:]
        if let ua = userAgent, !ua.isEmpty { headers["User-Agent"] = ua }
        if let ref = referrer, !ref.isEmpty { headers["Referer"] = ref }

        let asset = headers.isEmpty
            ? AVURLAsset(url: url)
            : AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": headers])

        let item = AVPlayerItem(asset: asset)
        player = AVPlayer(playerItem: item)
        player.automaticallyWaitsToMinimizeStalling = true

        item.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                guard let self else { return }
                switch status {
                case .readyToPlay:
                    self.failed = false
                    self.message = "Oynatılıyor"
                case .failed:
                    self.failed = true
                    let reason = item.error?.localizedDescription ?? "Bilinmeyen hata"
                    self.message = "Yerleşik oynatıcı açamadı: \(reason)"
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
}

/// AVPlayerViewController: hazır kontroller, ses ve altyazı menüleri.
struct AVControllerContainer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        return vc
    }

    func updateUIViewController(_ vc: AVPlayerViewController, context: Context) {}
}

struct AVPlayerScreen: View {
    let item: MediaItem
    let onNeedVLC: () -> Void
    @StateObject private var model: AVPlaybackModel

    init(item: MediaItem, onNeedVLC: @escaping () -> Void) {
        self.item = item
        self.onNeedVLC = onNeedVLC
        _model = StateObject(wrappedValue: AVPlaybackModel(
            url: item.stream, userAgent: item.userAgent, referrer: item.referrer))
    }

    var body: some View {
        AVControllerContainer(player: model.player)
            .ignoresSafeArea()
            .onReceive(model.$failed) { if $0 { onNeedVLC() } }
            .onDisappear { model.player.pause() }
    }
}

// MARK: - VLC motoru (her format)

struct TrackOption: Identifiable, Hashable {
    let index: Int32
    let name: String
    var id: Int32 { index }
}

@MainActor
final class VLCPlaybackModel: NSObject, ObservableObject, VLCMediaPlayerDelegate {
    @Published var state: VLCMediaPlayerState = .opening
    @Published var audioTracks: [TrackOption] = []
    @Published var subtitleTracks: [TrackOption] = []

    let player: VLCMediaPlayer

    init(url: URL, userAgent: String?, referrer: String?) {
        let media = VLCMedia(url: url)
        if let ua = userAgent, !ua.isEmpty { media.addOption(":http-user-agent=\(ua)") }
        if let ref = referrer, !ref.isEmpty { media.addOption(":http-referrer=\(ref)") }
        player = VLCMediaPlayer(options: [])
        super.init()
        player.delegate = self
        player.media = media
    }

    func start(in view: UIView) {
        player.drawable = view
        player.play()
    }

    func togglePlay() {
        if player.state == .playing { player.pause() } else { player.play() }
    }

    func restart() {
        player.stop()
        player.play()
    }

    func stop() {
        player.stop()
    }

    func selectAudio(_ index: Int32) {
        player.currentAudioTrackIndex = index
    }

    func selectSubtitle(_ index: Int32) {
        player.currentVideoSubTitleIndex = index
    }

    nonisolated func mediaPlayerStateChanged(_ aNotification: Notification) {
        Task { @MainActor in
            self.state = self.player.state
            self.refreshTracks()
        }
    }

    private func refreshTracks() {
        // VLC bu listeleri [Any] döndürür; NSNumber/String'e çeviririz.
        func options(_ names: [Any]?, _ indexes: [Any]?) -> [TrackOption] {
            guard let names, let indexes else { return [] }
            return zip(names, indexes).compactMap { rawName, rawIndex in
                guard let index = (rawIndex as? NSNumber)?.int32Value else { return nil }
                let name = rawName as? String ?? "Parça \(index)"
                return TrackOption(index: index, name: name)
            }
        }
        audioTracks = options(player.audioTrackNames, player.audioTrackIndexes)
        subtitleTracks = options(player.videoSubTitlesNames, player.videoSubTitlesIndexes)
    }
}

struct VLCVideoView: UIViewRepresentable {
    @ObservedObject var model: VLCPlaybackModel

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .black
        DispatchQueue.main.async { model.start(in: view) }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct VLCPlayerScreen: View {
    let item: MediaItem
    let onNeedAV: () -> Void
    @StateObject private var model: VLCPlaybackModel

    init(item: MediaItem, onNeedAV: @escaping () -> Void) {
        self.item = item
        self.onNeedAV = onNeedAV
        _model = StateObject(wrappedValue: VLCPlaybackModel(
            url: item.stream, userAgent: item.userAgent, referrer: item.referrer))
    }

    var body: some View {
        ZStack {
            VLCVideoView(model: model)
                .ignoresSafeArea()

            if model.state == .opening || model.state == .buffering {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.4)
            }

            if model.state == .error {
                VStack(spacing: 14) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 34))
                        .foregroundStyle(VSColor.live)
                    Text("VLC oynatıcı da bu yayını açamadı.")
                        .font(VSFont.inter(15))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Button {
                        onNeedAV()
                    } label: {
                        Label("Yerleşik oynatıcıyı dene", systemImage: "play.circle")
                            .font(VSFont.inter(15, weight: "SemiBold"))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 20).frame(height: 44)
                            .background(Capsule().fill(.white))
                    }
                    .buttonStyle(.plain)
                    Button("Tekrar dene") { model.restart() }
                        .font(VSFont.inter(15))
                        .foregroundStyle(VSColor.textMuted)
                }
                .padding(24)
                .background(RoundedRectangle(cornerRadius: 16).fill(VSColor.card.opacity(0.95)))
                .padding(24)
            }

            // Alt kontrol çubuğu: oynat/duraklat, ses ve altyazı seçimi.
            VStack {
                Spacer()
                HStack(spacing: 14) {
                    Button {
                        model.togglePlay()
                    } label: {
                        Image(systemName: model.state == .playing ? "pause.fill" : "play.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 40, height: 40)
                    }
                    Spacer()
                    if !model.audioTracks.isEmpty {
                        Menu {
                            ForEach(model.audioTracks) { track in
                                Button(track.name) { model.selectAudio(track.index) }
                            }
                        } label: {
                            Label("Ses", systemImage: "speaker.wave.2")
                        }
                    }
                    if !model.subtitleTracks.isEmpty {
                        Menu {
                            ForEach(model.subtitleTracks) { track in
                                Button(track.name) { model.selectSubtitle(track.index) }
                            }
                        } label: {
                            Label("Altyazı", systemImage: "captions.bubble")
                        }
                    }
                }
                .font(VSFont.inter(14, weight: "Medium"))
                .foregroundStyle(.white)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.black.opacity(0.55)))
                .padding(16)
            }
        }
        .onDisappear { model.stop() }
    }
}

// MARK: - Kök oynatıcı görünümü

struct PlayerView: View {
    let item: MediaItem
    @State private var engine: PlaybackEngine

    init(item: MediaItem) {
        self.item = item
        _engine = State(initialValue: PlaybackEngine.preferred(for: item.stream))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch engine {
            case .av:
                AVPlayerScreen(item: item) { engine = .vlc }
            case .vlc:
                VLCPlayerScreen(item: item) { engine = .av }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)
        }
    }
}
