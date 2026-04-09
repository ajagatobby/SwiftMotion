
import AVFoundation
import AudioToolbox

/// Synthesized paper burning sound.
/// Paper burns differently from wood — it's a soft whoosh with
/// crispy crinkle sounds, not heavy crackles.
final class FireSoundEngine {
    static let shared = FireSoundEngine()

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode!
    private var sampleRate: Double = 44100

    private var isRunning = false
    private var isPlaying = false

    private var intensity: Float = 0
    private var targetIntensity: Float = 0
    private var crinkles: [Crinkle] = []
    private let lock = NSLock()

    // Filter states
    private var lp1: Float = 0
    private var lp2: Float = 0
    private var hp: Float = 0
    private var prevSample: Float = 0

    // Timing
    private var sampleCount: Int = 0

    private struct Crinkle {
        var samplesLeft: Int        // how many samples this crinkle lasts
        var amplitude: Float
        var filterState: Float = 0
        var cutoff: Float           // filter cutoff for this crinkle
    }

    // MARK: - Button Sounds

    /// Native system click — always sounds good
    func playButtonClick() {
        AudioServicesPlaySystemSound(1104)
    }

    /// Paper crinkle for fold action
    func playFoldSound() {
        AudioServicesPlaySystemSound(1104)
        setup()
        isPlaying = true
        lock.lock()
        crinkles.append(Crinkle(samplesLeft: 3000, amplitude: 0.25, cutoff: 0.06))
        crinkles.append(Crinkle(samplesLeft: 2000, amplitude: 0.15, cutoff: 0.1))
        crinkles.append(Crinkle(samplesLeft: 1200, amplitude: 0.1, cutoff: 0.18))
        lock.unlock()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
            if self?.targetIntensity == 0 { self?.isPlaying = false }
        }
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
            guard let self, self.isPlaying else {
                let abl = UnsafeMutableAudioBufferListPointer(bufferList)
                for buffer in abl {
                    let buf = UnsafeMutableBufferPointer<Float>(buffer)
                    for i in 0..<Int(frameCount) { buf[i] = 0 }
                }
                return noErr
            }

            let abl = UnsafeMutableAudioBufferListPointer(bufferList)
            let sr = Float(self.sampleRate)

            self.lock.lock()

            for frame in 0..<Int(frameCount) {
                self.intensity += (self.targetIntensity - self.intensity) * 0.003
                self.sampleCount += 1

                var sample: Float = 0
                let inten = self.intensity

                if inten > 0.001 {
                    // ── 1. Soft whoosh — heavily filtered noise ──
                    // This is the main "paper catching fire" sound
                    let white = Float.random(in: -1...1)

                    // Double lowpass for very soft warmth (~200Hz)
                    self.lp1 += (white - self.lp1) * (200.0 / sr)
                    self.lp2 += (self.lp1 - self.lp2) * (300.0 / sr)
                    sample += self.lp2 * 0.3 * inten

                    // ── 2. Breathy flutter — modulated noise ──
                    // Simulates the air draft of paper burning
                    let flutter = Float.random(in: -1...1)
                    let modFreq = 6.0 + inten * 4.0  // 6-10 Hz flutter
                    let mod = (1.0 + sin(Float(self.sampleCount) / sr * 2 * .pi * modFreq)) * 0.5
                    self.hp = 0.995 * (self.hp + flutter - self.prevSample)
                    self.prevSample = flutter
                    sample += self.hp * mod * 0.06 * inten

                    // ── 3. Crispy crinkles — short bursts of filtered noise ──
                    // Spawn randomly: paper curling and crinkling as it burns
                    let gapMs = 120 - Int(inten * 80)  // 40-120ms between crinkles
                    let gap = Int(Float(gapMs) * sr / 1000.0)

                    if self.sampleCount % gap == 0 && Float.random(in: 0...1) < inten * 0.6 {
                        let dur = Int(Float.random(in: 400...1800))
                        let amp = Float.random(in: 0.04...0.12) * inten
                        let cut = Float.random(in: 0.05...0.2)
                        self.crinkles.append(Crinkle(
                            samplesLeft: dur,
                            amplitude: amp,
                            cutoff: cut
                        ))
                    }
                }

                // Process crinkles
                var i = 0
                while i < self.crinkles.count {
                    if self.crinkles[i].samplesLeft <= 0 {
                        self.crinkles.remove(at: i)
                        continue
                    }

                    let noise = Float.random(in: -1...1)
                    // Each crinkle has its own bandpass filter
                    self.crinkles[i].filterState += (noise - self.crinkles[i].filterState) * self.crinkles[i].cutoff

                    // Envelope: quick attack, natural decay
                    let remaining = Float(self.crinkles[i].samplesLeft)
                    let total = remaining + 1
                    let env = min(1.0, remaining / (total * 0.8))

                    sample += self.crinkles[i].filterState * self.crinkles[i].amplitude * env
                    self.crinkles[i].samplesLeft -= 1
                    i += 1
                }

                // Gentle soft clip
                sample = tanh(sample * 2.5) * 0.35

                for buffer in abl {
                    let buf = UnsafeMutableBufferPointer<Float>(buffer)
                    buf[frame] = sample
                }
            }

            self.lock.unlock()
            return noErr
        }

        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!

        engine.attach(sourceNode)
        engine.connect(sourceNode, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0.5

        do {
            try engine.start()
            isRunning = true
        } catch {}
    }

    // MARK: - Control

    func startFire() {
        setup()
        isPlaying = true
        lock.lock()
        targetIntensity = 1.0
        lock.unlock()
    }

    func setIntensity(_ value: Float) {
        lock.lock()
        targetIntensity = max(0, min(1, value))
        lock.unlock()
    }

    func stopFire() {
        lock.lock()
        targetIntensity = 0
        intensity = 0
        crinkles.removeAll()
        lock.unlock()
        isPlaying = false
    }
}
