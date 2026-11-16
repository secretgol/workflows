import SwiftUI
import AVKit
import Combine

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

/// Oynatma durumunu izler. Hata olursa nedenini ekranda gösterir.
@MainActor
final class PlaybackModel: ObservableObject {
    @Published var message = "Yükleniyor…"
    @Published var failed = false

    let player: AVPlayer
    private var cancellables = Set<AnyCancellable>()

    init(url: URL) {
        let item = AVPlayerItem(url: url)
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
                    self.message = "Oynatılamadı: \(reason)"
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
}

struct PlayerView: View {
    let item: MediaItem
    @StateObject private var model: PlaybackModel

    init(item: MediaItem) {
        self.item = item
        _model = StateObject(wrappedValue: PlaybackModel(url: item.stream))
    }

    /// Uzantıya bakarak olası uyumluluk notu. iOS yerleşik oynatıcısı ham MPEG-TS'yi oynatmayabilir.
    private var formatNote: String? {
        let ext = item.stream.pathExtension.lowercased()
        return ext == "ts" ? "Bu yayın MPEG-TS (.ts) biçiminde. iOS yerleşik oynatıcısı bunu oynatmayabilir." : nil
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: model.player)
                .ignoresSafeArea()

            if model.failed {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 34))
                        .foregroundStyle(VSColor.live)
                    Text(model.message)
                        .font(VSFont.inter(15))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    if let formatNote {
                        Text(formatNote)
                            .font(VSFont.inter(13))
                            .foregroundStyle(VSColor.textMuted)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24)
                .background(RoundedRectangle(cornerRadius: 16).fill(VSColor.card.opacity(0.95)))
                .padding(24)
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)
            model.player.play()
        }
        .onDisappear {
            model.player.pause()
        }
    }
}
