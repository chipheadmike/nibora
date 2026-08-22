//
//  SpeechVoicePreferences.swift
//  Nibora
//

import Foundation
import AVFoundation

/// Persists the user's chosen system voice for reading entries aloud. nil
/// means "use whatever AVSpeechSynthesizer picks by default" for the
/// current language.
@Observable
final class SpeechVoicePreferences {
    var voiceIdentifier: String? {
        didSet { UserDefaults.standard.set(voiceIdentifier, forKey: Keys.voiceIdentifier) }
    }
    /// AVSpeechUtterance.rate range: AVSpeechUtteranceMinimumSpeechRate...AVSpeechUtteranceMaximumSpeechRate.
    var rate: Double {
        didSet { UserDefaults.standard.set(rate, forKey: Keys.rate) }
    }
    /// AVSpeechUtterance.pitchMultiplier range: 0.5...2.0.
    var pitch: Double {
        didSet { UserDefaults.standard.set(pitch, forKey: Keys.pitch) }
    }

    static let defaultRate = Double(AVSpeechUtteranceDefaultSpeechRate)
    static let rateRange = Double(AVSpeechUtteranceMinimumSpeechRate)...Double(AVSpeechUtteranceMaximumSpeechRate)
    static let defaultPitch = 1.0
    static let pitchRange = 0.5...2.0

    private enum Keys {
        static let voiceIdentifier = "speechVoicePreferences.voiceIdentifier"
        static let rate = "speechVoicePreferences.rate"
        static let pitch = "speechVoicePreferences.pitch"
    }

    init() {
        voiceIdentifier = UserDefaults.standard.string(forKey: Keys.voiceIdentifier)
        rate = UserDefaults.standard.object(forKey: Keys.rate) as? Double ?? Self.defaultRate
        pitch = UserDefaults.standard.object(forKey: Keys.pitch) as? Double ?? Self.defaultPitch
    }

    func resetRateAndPitch() {
        rate = Self.defaultRate
        pitch = Self.defaultPitch
    }

    static var availableVoices: [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().sorted { $0.name < $1.name }
    }
}
