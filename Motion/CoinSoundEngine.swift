//
//  CoinSoundEngine.swift
//  Motion
//
//  Synthesized coin flip sound effects using AVAudioEngine.
//  Bell-like chimes, metallic dings, and ambient chords — no audio files needed.

import AVFoundation

final class CoinSoundEngine {
    static let shared = CoinSoundEngine()

    private let engine = AVAudioEngine()
    private let reverb = AVAudioUnitReverb()
    private var sourceNode: AVAudioSourceNode!
    private var sampleRate: Double = 44100

    // ── Active voices ──
    private var voices: [Voice] = []
    private let voiceLock = NSLock()

    private var isRunning = false

    // MARK: - Voice (a single decaying tone with partials)

    private struct Partial {
        var phaseIncrement: Float  // freq / sampleRate
        var phase: Float = 0
        var amplitude: Float
        var decayRate: Float       // per-sample multiplier (e.g., 0.99997)
    }

    private struct Voice {
        var partials: [Partial]
        var envelope: Float = 0
        var attackRemaining: Int   // samples of attack ramp
        var attackLength: Int
        var alive: Bool = true
    }

    // MARK: - Setup

    func setup() {
        guard !isRunning else { return }

        #if os(iOS)
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.ambient, mode: .default, options: .mixWithOthers)
            try session.setActive(true)
        } catch {}
        #endif

        sampleRate = engine.outputNode.inputFormat(forBus: 0).sampleRate
        if sampleRate == 0 { sampleRate = 44100 }

        sourceNode = AVAudioSourceNode { [weak self] _, _, frameCount, bufferList -> OSStatus in
            guard let self else { return noErr }
            let abl = UnsafeMutableAudioBufferListPointer(bufferList)

            self.voiceLock.lock()
            let voiceCount = self.voices.count
            self.voiceLock.unlock()

            for frame in 0..<Int(frameCount) {
                var sample: Float = 0

                self.voiceLock.lock()
                for v in 0..<self.voices.count {
                    guard self.voices[v].alive else { continue }

                    // Attack ramp
                    if self.voices[v].attackRemaining > 0 {
                        self.voices[v].envelope = Float(self.voices[v].attackLength - self.voices[v].attackRemaining) / Float(self.voices[v].attackLength)
                        self.voices[v].attackRemaining -= 1
                    } else {
                        self.voices[v].envelope = 1.0
                    }

                    var voiceSample: Float = 0
                    var totalAmp: Float = 0

                    for p in 0..<self.voices[v].partials.count {
                        let partial = self.voices[v].partials[p]
                        voiceSample += sin(2.0 * .pi * partial.phase) * partial.amplitude
                        totalAmp += partial.amplitude

                        // Advance phase
                        self.voices[v].partials[p].phase += partial.phaseIncrement
                        if self.voices[v].partials[p].phase > 1.0 {
                            self.voices[v].partials[p].phase -= 1.0
                        }

                        // Exponential decay
                        self.voices[v].partials[p].amplitude *= partial.decayRate
                    }

                    // Kill voice when too quiet
                    if totalAmp < 0.001 {
                        self.voices[v].alive = false
                    }

                    sample += voiceSample * self.voices[v].envelope
                }

                // Remove dead voices periodically
                if voiceCount > 0 && frame == 0 {
                    self.voices.removeAll { !$0.alive }
                }
                self.voiceLock.unlock()

                // Soft clip
                sample = tanh(sample)

                for buffer in abl {
                    let buf = UnsafeMutableBufferPointer<Float>(buffer)
                    buf[frame] = sample
                }
            }
            return noErr
        }

        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!

        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = 32

        engine.attach(sourceNode)
        engine.attach(reverb)
        engine.connect(sourceNode, to: reverb, format: format)
        engine.connect(reverb, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.35

        do {
            try engine.start()
            isRunning = true
        } catch {}
    }

    // MARK: - Sound: Launch Chime (rising E5 → A5)

    func playLaunchChime() {
        let notes: [(freq: Float, delay: Double)] = [
            (659.26, 0.0),   // E5
            (880.00, 0.07),  // A5
        ]

        for note in notes {
            DispatchQueue.main.asyncAfter(deadline: .now() + note.delay) {
                self.addBellVoice(
                    fundamental: note.freq,
                    amplitude: 0.18,
                    attackMs: 5,
                    decaySeconds: 0.5
                )
            }
        }
    }

    // MARK: - Sound: Spin Shimmer

    func playSpinShimmer(duration: Double) {
        // High detuned cluster — creates a gentle shimmer
        let freqs: [Float] = [2093, 2217, 2349, 2489]
        for freq in freqs {
            addVoice(partials: [
                (freq, 0.012, Float(duration * 0.6)),
            ], attackMs: 300)
        }
    }

    // MARK: - Sound: Landing Ding (metallic ping)

    func playLandDing() {
        // Metallic = inharmonic partials with fast decay
        let fundamental: Float = 1318.51 // E6
        addVoice(partials: [
            (fundamental * 1.0,  0.22, 0.9),
            (fundamental * 2.76, 0.12, 0.4),  // inharmonic — metallic
            (fundamental * 5.4,  0.06, 0.18),
            (fundamental * 8.93, 0.03, 0.08),
        ], attackMs: 1)
    }

    // MARK: - Sound: Result Chord (C major — C5 + E5 + G5)

    func playResultChord() {
        let chord: [(freq: Float, delay: Double)] = [
            (523.25, 0.0),   // C5
            (659.26, 0.03),  // E5
            (783.99, 0.06),  // G5
        ]

        for note in chord {
            DispatchQueue.main.asyncAfter(deadline: .now() + note.delay) {
                self.addBellVoice(
                    fundamental: note.freq,
                    amplitude: 0.13,
                    attackMs: 10,
                    decaySeconds: 1.4
                )
            }
        }
    }

    // MARK: - Voice Builders

    private func addBellVoice(fundamental: Float, amplitude: Float, attackMs: Int, decaySeconds: Float) {
        // Bell partials: fundamental + harmonic + octave + bright overtone
        let ratios: [(Float, Float)] = [
            (1.0,  1.0),
            (2.0,  0.45),
            (3.0,  0.20),
            (4.07, 0.10),  // slightly inharmonic — bell character
        ]

        var partials: [Partial] = []
        for (ratio, ampScale) in ratios {
            let freq = fundamental * ratio
            let amp = amplitude * ampScale
            // Higher partials decay faster
            let decay = decaySeconds / (0.5 + ratio * 0.5)
            let decayRate = decayPerSample(seconds: decay)

            partials.append(Partial(
                phaseIncrement: freq / Float(sampleRate),
                amplitude: amp,
                decayRate: decayRate
            ))
        }

        let attackSamples = max(1, Int(Float(attackMs) * Float(sampleRate) / 1000.0))

        voiceLock.lock()
        voices.append(Voice(
            partials: partials,
            attackRemaining: attackSamples,
            attackLength: attackSamples
        ))
        voiceLock.unlock()
    }

    private func addVoice(partials: [(freq: Float, amp: Float, decaySec: Float)], attackMs: Int) {
        var ps: [Partial] = []
        for (freq, amp, decay) in partials {
            ps.append(Partial(
                phaseIncrement: freq / Float(sampleRate),
                amplitude: amp,
                decayRate: decayPerSample(seconds: decay)
            ))
        }

        let attackSamples = max(1, Int(Float(attackMs) * Float(sampleRate) / 1000.0))

        voiceLock.lock()
        voices.append(Voice(
            partials: ps,
            attackRemaining: attackSamples,
            attackLength: attackSamples
        ))
        voiceLock.unlock()
    }

    private func decayPerSample(seconds: Float) -> Float {
        // Exponential decay: amplitude * rate^n = target
        // After 'seconds' worth of samples, amplitude should be ~0.001 (–60dB)
        let samples = seconds * Float(sampleRate)
        return pow(0.001, 1.0 / max(samples, 1))
    }
}
