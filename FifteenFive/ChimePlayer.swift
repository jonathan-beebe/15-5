import AVFoundation

@MainActor
final class ChimePlayer {
    nonisolated static let fileName = "chime.wav"

    private let player: AVAudioPlayer?
    #if os(iOS)
    private var deactivation: Task<Void, Never>?
    #endif

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
        #if os(iOS)
        // .playback sounds with the ring switch on silent, matching the Clock app's timer.
        // .mixWithOthers leaves another app's audio playing, with the chime over it.
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
        } catch {
            logger.error("The audio session category failed to set: \(error)")
        }
        #endif
    }

    /// On iOS the audio session is active only for the length of the chime. An active session
    /// holds a connection to the audio system that nothing uses between chimes.
    func play() {
        guard let player else { return }
        #if os(iOS)
        deactivation?.cancel()
        do {
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            logger.error("The audio session failed to activate: \(error)")
        }
        #endif
        player.currentTime = 0
        player.play()
        #if os(iOS)
        deactivation = Task { [duration = player.duration] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled else { return }
            Self.deactivateSession()
        }
        #endif
    }

    func stop() {
        player?.stop()
        #if os(iOS)
        deactivation?.cancel()
        deactivation = nil
        Self.deactivateSession()
        #endif
    }

    #if os(iOS)
    /// Deactivating fails while the player still plays, so it runs after `stop()` or the chime's end.
    private static func deactivateSession() {
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("The audio session failed to deactivate: \(error)")
        }
    }
    #endif
}
