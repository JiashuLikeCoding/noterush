import Combine
import CoreMIDI

/// Lightweight monitor for MIDI source add/remove events.
/// Use this to notify the UI when a MIDI device becomes available.
final class MidiDeviceMonitor: ObservableObject {
    @Published private(set) var hasSources: Bool = false

    private var client = MIDIClientRef()

    func start() {
        guard client == 0 else { return }

        var newClient = MIDIClientRef()
        let status = MIDIClientCreateWithBlock("SightNote-MIDI-Monitor" as CFString, &newClient) { [weak self] _ in
            self?.refresh()
        }
        guard status == noErr else { return }
        client = newClient

        refresh()
    }

    func stop() {
        guard client != 0 else { return }
        MIDIClientDispose(client)
        client = MIDIClientRef()
        hasSources = false
    }

    deinit {
        stop()
    }

    private func refresh() {
        let count = MIDIGetNumberOfSources()
        DispatchQueue.main.async { [weak self] in
            self?.hasSources = count > 0
        }
    }
}
