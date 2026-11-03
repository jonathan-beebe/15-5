import AVFoundation

@MainActor
final class ChimePlayer {
    static let fileName = "chime.wav"

    private let player: AVAudioPlayer?

    init() {
        guard let url = Bundle.main.url(forResource: Self.fileName, withExtension: nil) else {
            logger.error("\(Self.fileName) is missing from the bundle, so the chime stays silent")
            player = nil
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
        } catch {
            logger.error("\(Self.fileName) failed to load, so the chime stays silent: \(error)")
            player = nil
        }
    }

    func play() {
        #if os(iOS)
        // .playback sounds with the ring switch on silent, matching the Clock app's timer.
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logger.error("The audio session failed to activate: \(error)")
        }
        #endif
        player?.currentTime = 0
        player?.play()
    }

    func stop() {
        player?.stop()
    }
}
