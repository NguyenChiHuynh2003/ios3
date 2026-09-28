import Foundation
import AVFoundation
import AudioToolbox

final class SoundManager {
    static let shared = SoundManager()
    private var audioPlayer: AVAudioPlayer?

    private init() {
        prepareAudioSession()
        preparePlayer()
    }

    private func prepareAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set AVAudioSession category: \(error)")
        }
    }

    private func preparePlayer() {
        guard let soundURL = Bundle.main.url(forResource: "message_sound", withExtension: "mp3") else {
            print("Sound file message_sound.mp3 not found in main bundle")
            return
        }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
        } catch {
            print("Failed to initialize AVAudioPlayer: \(error)")
        }
    }

    func playMessageSound() {
        // Run on main queue or background
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // Vibrate feedback
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)

            if let player = self.audioPlayer {
                if player.isPlaying {
                    player.stop()
                    player.currentTime = 0
                }
                player.play()
            } else {
                // Try reloading if not yet initialized
                self.preparePlayer()
                self.audioPlayer?.play()
            }
        }
    }
}
