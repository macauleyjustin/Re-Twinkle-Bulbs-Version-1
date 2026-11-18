import Foundation
import AVFoundation

public struct MusicTrack: Identifiable, Equatable {
    public let id: String
    public let title: String
    public let url: URL? // nil => built-in synthesized public-domain carol
    public let builtInNotes: [(midi: UInt8, beats: Double)]?
    public let tempoBPM: Double

    public static func == (lhs: MusicTrack, rhs: MusicTrack) -> Bool { lhs.id == rhs.id }
}

/// Clean-room audio service handling UI sound effects (wave_165..388 equivalents) and festive background music.
public final class AudioEngineService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    public static let shared = AudioEngineService()

    public enum UIEffect: Int {
        case click = 0      // wave_165 (34ms)
        case softTick = 1   // wave_253 (13ms)
        case altTick = 2    // wave_254 (19ms)
        case menuChime = 9  // wave_166 (31ms)
        case pop = 11       // wave_257 (10ms)
        case celebrate = 12 // wave_388 (307ms)
    }

    @Published public private(set) var tracks: [MusicTrack] = []
    @Published public private(set) var isPlaying: Bool = false
    @Published public private(set) var currentTrackTitle: String = "Stopped"
    @Published public private(set) var currentTrackIndex: Int = 0

    private var sfxPlayers: [Int: AVAudioPlayer] = [:]
    private var musicAudioPlayer: AVAudioPlayer?
    private var midiPlayer: AVMIDIPlayer?
    private var synthTimer: Timer?
    private var synthStep: Int = 0
    private var pauseTimer: Timer?

    private var synthEngine: AVAudioEngine?
    private var synthSampler: AVAudioUnitSampler?

    static var importedMusicDirectory: URL {
        let appSup = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSup.appendingPathComponent("TwinkleBulbs/ImportedMusic", isDirectory: true)
    }

    override init() {
        super.init()
        try? FileManager.default.createDirectory(at: Self.importedMusicDirectory, withIntermediateDirectories: true)
        rebuildTrackList()
        prepareSFXCache()
    }

    func rebuildTrackList() {
        var list = Self.builtInCarols()
        if let files = try? FileManager.default.contentsOfDirectory(at: Self.importedMusicDirectory, includingPropertiesForKeys: nil) {
            let exts = Set(["mid", "midi", "wav", "mp3", "m4a", "aiff"])
            for f in files.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }) {
                if exts.contains(f.pathExtension.lowercased()) {
                    list.append(MusicTrack(
                        id: "imported:\(f.lastPathComponent)",
                        title: f.deletingPathExtension().lastPathComponent,
                        url: f,
                        builtInNotes: nil,
                        tempoBPM: 120
                    ))
                }
            }
        }
        tracks = list
    }

    // MARK: - UI Sound Effects (synthesized WAVs cleanly matching v6.0 SFX durations/characters)

    func playEffect(_ effect: UIEffect, enabled: Bool) {
        guard enabled else { return }
        if let player = sfxPlayers[effect.rawValue] {
            player.currentTime = 0
            player.play()
        }
    }

    private func prepareSFXCache() {
        let specs: [(Int, Double, Double, Double)] = [
            (UIEffect.click.rawValue, 880, 520, 0.034),
            (UIEffect.softTick.rawValue, 1320, 990, 0.014),
            (UIEffect.altTick.rawValue, 1175, 880, 0.020),
            (UIEffect.menuChime.rawValue, 1046.5, 1318.5, 0.032),
            (UIEffect.pop.rawValue, 660, 440, 0.012),
            (UIEffect.celebrate.rawValue, 1046.5, 1568.0, 0.300)
        ]
        for (tag, f0, f1, dur) in specs {
            let wavData = Self.makeToneWAV(startFreq: f0, endFreq: f1, durationSec: dur, volume: tag == UIEffect.celebrate.rawValue ? 0.35 : 0.22)
            if let p = try? AVAudioPlayer(data: wavData) {
                p.prepareToPlay()
                sfxPlayers[tag] = p
            }
        }
    }

    private static func makeToneWAV(startFreq: Double, endFreq: Double, durationSec: Double, volume: Double) -> Data {
        let rate = 22050
        let count = max(120, Int(Double(rate) * durationSec))
        var pcm = Data(capacity: count * 2)
        var phase = 0.0
        for i in 0..<count {
            let t = Double(i) / Double(count)
            let freq = startFreq + (endFreq - startFreq) * t
            let env = (1.0 - t) * min(1.0, Double(i) / 12.0)
            phase += 2.0 * .pi * freq / Double(rate)
            let sample = (sin(phase) + 0.25 * sin(phase * 2.0)) * env * volume
            let int16 = Int16(max(-32767, min(32767, sample * 32767.0)))
            var le = int16.littleEndian
            pcm.append(Data(bytes: &le, count: 2))
        }
        return wrapPCMAsWAV(pcm: pcm, sampleRate: rate, channels: 1, bitsPerSample: 16)
    }

    public static func wrapPCMAsWAV(pcm: Data, sampleRate: Int, channels: Int, bitsPerSample: Int) -> Data {
        var out = Data()
        let byteRate = UInt32(sampleRate * channels * bitsPerSample / 8)
        let blockAlign = UInt16(channels * bitsPerSample / 8)
        let subchunk2Size = UInt32(pcm.count)
        let chunkSize = UInt32(36 + pcm.count)

        out.append("RIFF".data(using: .ascii)!)
        out.append(contentsOf: withUnsafeBytes(of: chunkSize.littleEndian, Array.init))
        out.append("WAVEfmt ".data(using: .ascii)!)
        out.append(contentsOf: withUnsafeBytes(of: UInt32(16).littleEndian, Array.init))
        out.append(contentsOf: withUnsafeBytes(of: UInt16(1).littleEndian, Array.init))
        out.append(contentsOf: withUnsafeBytes(of: UInt16(channels).littleEndian, Array.init))
        out.append(contentsOf: withUnsafeBytes(of: UInt32(sampleRate).littleEndian, Array.init))
        out.append(contentsOf: withUnsafeBytes(of: byteRate.littleEndian, Array.init))
        out.append(contentsOf: withUnsafeBytes(of: blockAlign.littleEndian, Array.init))
        out.append(contentsOf: withUnsafeBytes(of: UInt16(bitsPerSample).littleEndian, Array.init))
        out.append("data".data(using: .ascii)!)
        out.append(contentsOf: withUnsafeBytes(of: subchunk2Size.littleEndian, Array.init))
        out.append(pcm)
        return out
    }

    // MARK: - Holiday Music Playback

    func syncWithSettings(_ settings: AppSettings, isScreenSaverActive: Bool) {
        let shouldPlay = settings.musicEnabled && (!settings.ssMusic || isScreenSaverActive)
        if shouldPlay && !isPlaying {
            play(settings: settings)
        } else if !shouldPlay && isPlaying {
            stop()
        }
    }

    func play(trackIndex: Int? = nil, settings: AppSettings) {
        stopPlaybackOnly()
        let pool = activeTrackIndices(settings: settings)
        guard !pool.isEmpty else { return }

        if let explicit = trackIndex, explicit >= 0, explicit < tracks.count {
            currentTrackIndex = explicit
        } else if settings.musicPlayMode == 1 {
            currentTrackIndex = pool.randomElement() ?? 0
        } else if !pool.contains(currentTrackIndex) {
            currentTrackIndex = pool[0]
        }

        let track = tracks[currentTrackIndex]
        currentTrackTitle = track.title
        isPlaying = true

        if let url = track.url {
            if ["mid", "midi"].contains(url.pathExtension.lowercased()) {
                do {
                    midiPlayer = try AVMIDIPlayer(contentsOf: url, soundBankURL: nil)
                    midiPlayer?.prepareToPlay()
                    midiPlayer?.play { [weak self] in
                        DispatchQueue.main.async {
                            self?.handleTrackCompleted(settings: settings)
                        }
                    }
                } catch {
                    playBuiltInCarolFallback(track, settings: settings)
                }
            } else {
                musicAudioPlayer = try? AVAudioPlayer(contentsOf: url)
                musicAudioPlayer?.delegate = self
                musicAudioPlayer?.play()
            }
        } else {
            playBuiltInCarolFallback(track, settings: settings)
        }

        schedulePauseTimerIfNeeded(settings: settings)
    }

    func playNext(settings: AppSettings) {
        let pool = activeTrackIndices(settings: settings)
        guard !pool.isEmpty else { return }
        if settings.musicPlayMode == 1 {
            currentTrackIndex = pool.randomElement() ?? pool[0]
        } else if let pos = pool.firstIndex(of: currentTrackIndex) {
            currentTrackIndex = pool[(pos + 1) % pool.count]
        } else {
            currentTrackIndex = pool[0]
        }
        play(trackIndex: currentTrackIndex, settings: settings)
    }

    func togglePlayStop(settings: AppSettings) {
        if isPlaying {
            stop()
        } else {
            play(settings: settings)
        }
    }

    func stop() {
        stopPlaybackOnly()
        pauseTimer?.invalidate()
        pauseTimer = nil
        isPlaying = false
        currentTrackTitle = "Stopped"
    }

    private func stopPlaybackOnly() {
        synthTimer?.invalidate()
        synthTimer = nil
        midiPlayer?.stop()
        midiPlayer = nil
        musicAudioPlayer?.stop()
        musicAudioPlayer = nil
        synthSampler?.stopNote(60, onChannel: 0)
        synthEngine?.stop()
    }

    private func schedulePauseTimerIfNeeded(settings: AppSettings) {
        pauseTimer?.invalidate()
        guard settings.enablePause, settings.pauseMinutes > 0 else { return }
        pauseTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(settings.pauseMinutes * 60), repeats: false) { [weak self] _ in
            self?.stop()
        }
    }

    private func handleTrackCompleted(settings: AppSettings) {
        guard isPlaying else { return }
        playNext(settings: settings)
    }

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        handleTrackCompleted(settings: SettingsStore.shared.settings)
    }

    private func activeTrackIndices(settings: AppSettings) -> [Int] {
        guard !tracks.isEmpty else { return [] }
        if settings.enabledTrackIDs.isEmpty {
            return Array(tracks.indices)
        }
        let matching = tracks.indices.filter { settings.enabledTrackIDs.contains(tracks[$0].id) }
        return matching.isEmpty ? Array(tracks.indices) : matching
    }

    // MARK: - Clean-Room Chime/Celesta Carol Synthesizer

    private func ensureSynthReady() {
        if synthEngine != nil { return }
        let engine = AVAudioEngine()
        let sampler = AVAudioUnitSampler()
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        try? engine.start()
        self.synthEngine = engine
        self.synthSampler = sampler
    }

    private func playBuiltInCarolFallback(_ track: MusicTrack, settings: AppSettings) {
        guard let notes = track.builtInNotes, !notes.isEmpty else { return }
        ensureSynthReady()
        if synthEngine?.isRunning == false { try? synthEngine?.start() }
        synthStep = 0
        playNextSynthStep(notes: notes, bpm: track.tempoBPM, settings: settings)
    }

    private func playNextSynthStep(notes: [(midi: UInt8, beats: Double)], bpm: Double, settings: AppSettings) {
        guard isPlaying else { return }
        if synthStep >= notes.count {
            handleTrackCompleted(settings: settings)
            return
        }
        let item = notes[synthStep]
        synthStep += 1
        let sec = max(0.08, item.beats * (60.0 / bpm))
        if item.midi > 0 {
            synthSampler?.startNote(item.midi, withVelocity: 78, onChannel: 0)
            DispatchQueue.main.asyncAfter(deadline: .now() + sec * 0.85) { [weak self] in
                guard let self, self.isPlaying, self.synthEngine?.isRunning == true else { return }
                self.synthSampler?.stopNote(item.midi, onChannel: 0)
            }
        }
        synthTimer = Timer.scheduledTimer(withTimeInterval: sec, repeats: false) { [weak self] _ in
            self?.playNextSynthStep(notes: notes, bpm: bpm, settings: settings)
        }
    }

    static func builtInCarols() -> [MusicTrack] {
        // Traditional public-domain melody note sequences
        let jingleBells: [(UInt8, Double)] = [
            (64,1),(64,1),(64,2), (64,1),(64,1),(64,2), (64,1),(67,1),(60,1.5),(62,0.5),(64,4),
            (65,1),(65,1),(65,1.5),(65,0.5), (65,1),(64,1),(64,1),(64,0.5),(64,0.5),
            (64,1),(62,1),(62,1),(64,1),(62,2),(67,2),
            (64,1),(64,1),(64,2), (64,1),(64,1),(64,2), (64,1),(67,1),(60,1.5),(62,0.5),(64,4),
            (65,1),(65,1),(65,1.5),(65,0.5), (65,1),(64,1),(64,1),(64,0.5),(64,0.5),
            (67,1),(67,1),(65,1),(62,1),(60,4)
        ]
        let deckTheHalls: [(UInt8, Double)] = [
            (67,1.5),(65,0.5),(64,1),(62,1),(60,1),(62,1),(64,1),(60,1),
            (62,0.5),(64,0.5),(65,0.5),(62,0.5),(64,1.5),(62,0.5),(60,1),(59,1),(60,2),
            (67,1.5),(65,0.5),(64,1),(62,1),(60,1),(62,1),(64,1),(60,1),
            (62,0.5),(64,0.5),(65,0.5),(62,0.5),(64,1.5),(62,0.5),(60,1),(59,1),(60,2)
        ]
        let silentNight: [(UInt8, Double)] = [
            (67,1.5),(69,0.5),(67,1),(64,3), (67,1.5),(69,0.5),(67,1),(64,3),
            (74,2),(74,1),(71,3), (72,2),(72,1),(67,3),
            (69,2),(69,1),(72,1.5),(71,0.5),(69,1), (67,1.5),(69,0.5),(67,1),(64,3),
            (74,2),(74,1),(77,1.5),(74,0.5),(71,1),(72,3),(76,3),
            (72,1.5),(67,0.5),(64,1),(67,1.5),(65,0.5),(62,1),(60,4)
        ]
        let firstNoel: [(UInt8, Double)] = [
            (64,0.5),(62,0.5),(60,1.5),(62,0.5),(64,0.5),(65,0.5),(67,2),
            (69,0.5),(71,0.5),(72,1),(71,1),(69,1),(67,2),
            (69,0.5),(71,0.5),(72,1),(71,1),(69,1),(67,1),(69,1),(71,1),(72,1),(67,1),(65,1),(64,2)
        ]
        let greensleeves: [(UInt8, Double)] = [
            (69,1),(72,2),(74,1),(76,1.5),(77,0.5),(76,1),(74,2),(71,1),(67,1.5),(69,0.5),(71,1),
            (72,2),(69,1),(69,1.5),(68,0.5),(69,1),(71,2),(68,1),(64,3),
            (69,1),(72,2),(74,1),(76,1.5),(77,0.5),(76,1),(74,2),(71,1),(67,1.5),(69,0.5),(71,1),
            (72,1.5),(71,0.5),(69,1),(68,1.5),(66,0.5),(68,1),(69,3)
        ]
        let weWishYou: [(UInt8, Double)] = [
            (62,1),(67,1),(67,0.5),(69,0.5),(67,0.5),(66,0.5),(64,1),(64,1),(64,1),
            (69,1),(69,0.5),(71,0.5),(69,0.5),(67,0.5),(66,1),(62,1),(62,1),
            (71,1),(71,0.5),(72,0.5),(71,0.5),(69,0.5),(67,1),(64,1),(62,0.5),(62,0.5),
            (64,1),(69,1),(66,1),(67,2)
        ]
        let joyToTheWorld: [(UInt8, Double)] = [
            (72,2),(71,1.5),(69,0.5),(67,3),(65,1),(64,2),(62,2),(60,3),(67,1),
            (69,3),(69,1),(71,3),(71,1),(72,3),(72,1),(72,1),(71,1),(69,1),(67,1),
            (67,1.5),(65,0.5),(64,1),(72,1),(72,1),(71,1),(69,1),(67,1),(67,1.5),(65,0.5),(64,1),
            (64,1),(64,1),(64,1),(64,0.5),(65,0.5),(67,3),(65,0.5),(64,0.5),
            (62,1),(62,1),(62,1),(62,0.5),(64,0.5),(65,3),(64,0.5),(62,0.5),
            (60,1),(72,2),(69,1),(67,1.5),(65,0.5),(64,1),(65,1),(64,2),(62,2),(60,3)
        ]
        let littleTown: [(UInt8, Double)] = [
            (64,1),(64,1),(64,1),(63,1),(64,1),(67,1),(65,1),(62,2),(60,1),(62,1),(64,1),(60,1),(64,1),(67,3),
            (64,1),(64,1),(69,1),(67,1),(65,1),(65,1),(64,2),(62,1),(60,1),(62,1),(64,1),(62,1),(64,1),(60,3)
        ]
        return [
            MusicTrack(id: "builtin:jingle_bells", title: "Jingle Bells", url: nil, builtInNotes: jingleBells, tempoBPM: 140),
            MusicTrack(id: "builtin:deck_halls", title: "Deck the Halls", url: nil, builtInNotes: deckTheHalls, tempoBPM: 132),
            MusicTrack(id: "builtin:silent_night", title: "Silent Night", url: nil, builtInNotes: silentNight, tempoBPM: 92),
            MusicTrack(id: "builtin:first_noel", title: "The First Noel", url: nil, builtInNotes: firstNoel, tempoBPM: 108),
            MusicTrack(id: "builtin:greensleeves", title: "Greensleeves", url: nil, builtInNotes: greensleeves, tempoBPM: 112),
            MusicTrack(id: "builtin:little_town", title: "O Little Town of Bethlehem", url: nil, builtInNotes: littleTown, tempoBPM: 104),
            MusicTrack(id: "builtin:joy_world", title: "Joy to the World", url: nil, builtInNotes: joyToTheWorld, tempoBPM: 126),
            MusicTrack(id: "builtin:we_wish", title: "We Wish You a Merry Christmas", url: nil, builtInNotes: weWishYou, tempoBPM: 136)
        ]
    }
}
