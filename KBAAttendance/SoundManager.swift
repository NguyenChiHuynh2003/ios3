import Foundation
import AVFoundation
import AudioToolbox

final class SoundManager {
    static let shared = SoundManager()
    private var audioPlayer: AVAudioPlayer?
    private var systemSoundID: SystemSoundID = 0

    private init() {
        prepareAudio()
    }

    func prepareAudio() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers, .duckOthers])
            try session.setActive(true)
        } catch {
            print("Failed to set AVAudioSession category: \(error)")
        }

        if let soundURL = Bundle.main.url(forResource: "message_sound", withExtension: "mp3") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.prepareToPlay()
                audioPlayer?.volume = 1.0
            } catch {
                print("Failed to initialize AVAudioPlayer: \(error)")
            }

            // Register with system alert sound service
            AudioServicesCreateSystemSoundID(soundURL as CFURL, &systemSoundID)
        } else {
            print("Sound file message_sound.mp3 not found in main bundle")
        }
    }

    func playMessageSound() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            // 1. Vibrate device
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)

            // 2. Play via system alert sound (respects system alert channel)
            if self.systemSoundID != 0 {
                AudioServicesPlayAlertSound(self.systemSoundID)
            }

            // 3. Play via AVAudioPlayer with active session
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {}

            if let player = self.audioPlayer {
                if player.isPlaying {
                    player.stop()
                    player.currentTime = 0
                }
                player.play()
            } else {
                self.prepareAudio()
                self.audioPlayer?.play()
            }
        }
    }
}
