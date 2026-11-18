import AppKit
import AVFoundation

public final class SoundManager: @unchecked Sendable {
    public static let shared = SoundManager()
    private var player: AVAudioPlayer?
    
    private init() {
        if let soundURL = Bundle.main.url(forResource: "ArrivalChime", withExtension: "wav") ??
                          Bundle.main.url(forResource: "ArrivalChime", withExtension: "mp3") {
            try? player = AVAudioPlayer(contentsOf: soundURL)
            player?.prepareToPlay()
        }
    }
    
    public func playChime() {
        DispatchQueue.main.async {
            if let p = self.player {
                p.currentTime = 0
                p.play()
            } else if let sysSound = NSSound(named: "Glass") ?? NSSound(named: "Ping") {
                sysSound.play()
            }
        }
    }
}
