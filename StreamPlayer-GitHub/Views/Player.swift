import SwiftUI
import AVKit

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

struct PlayerView: View {
    let item: MediaItem
    @State private var player: AVPlayer?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Medya ses modu: sessiz anahtarda da ses çalsın
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)
            player = AVPlayer(url: item.stream)
            player?.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
}
