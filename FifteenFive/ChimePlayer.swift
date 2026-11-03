import AVFoundation

@MainActor
final class ChimePlayer {
    static let fileName = "chime.wav"

    private let player: AVAudioPlayer? = Bundle.main
        .url(forResource: fileName, withExtension: nil)
        .flatMap { try? AVAudioPlayer(contentsOf: $0) }

    func play() {
        #if os(iOS)
        // .playback sounds with the ring switch on silent, matching the Clock app's timer.
        try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        player?.currentTime = 0
        player?.play()
    }

    func stop() {
        player?.stop()
    }
}
