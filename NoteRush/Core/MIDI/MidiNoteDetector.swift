import Combine
import CoreMIDI

final class MidiNoteDetector: ObservableObject {
    @Published private(set) var isRunning: Bool = false
    @Published private(set) var lastDetectedLetter: NoteLetter?
    @Published private(set) var lastDetectedNoteNumber: Int = 0

    var onDetect: ((NoteLetter) -> Void)?

    private var client = MIDIClientRef()
    private var inPort = MIDIPortRef()
    private var connectedSources: [MIDIEndpointRef] = []

    private var lastEmittedLetter: NoteLetter?
    private var lastEmitTime: UInt64 = 0
    private let repeatCooldownNanos: UInt64 = 250_000_000 // 0.25s

    func start() {
        guard !isRunning else { return }

        var newClient = MIDIClientRef()
        guard MIDIClientCreateWithBlock("SightNote-MIDI" as CFString, &newClient, nil) == noErr else {
            return
        }
        client = newClient

        var newPort = MIDIPortRef()
        let status = MIDIInputPortCreateWithBlock(client, "SightNote-MIDI-In" as CFString, &newPort) { [weak self] packetList, _ in
            self?.handle(packetList: packetList)
        }
        guard status == noErr else {
            MIDIClientDispose(client)
            client = MIDIClientRef()
            return
        }
        inPort = newPort

        // Connect all current sources.
        let count = MIDIGetNumberOfSources()
        for i in 0..<count {
            let src = MIDIGetSource(i)
            guard src != 0 else { continue }
            MIDIPortConnectSource(inPort, src, nil)
            connectedSources.append(src)
        }

        isRunning = true
    }

    func stop() {
        guard isRunning else { return }

        for src in connectedSources {
            MIDIPortDisconnectSource(inPort, src)
        }
        connectedSources.removeAll()

        if inPort != 0 {
            MIDIPortDispose(inPort)
            inPort = MIDIPortRef()
        }
        if client != 0 {
            MIDIClientDispose(client)
            client = MIDIClientRef()
        }

        isRunning = false
    }

    deinit {
        stop()
    }

    private func handle(packetList: UnsafePointer<MIDIPacketList>) {
        var packet: MIDIPacket = packetList.pointee.packet

        for _ in 0..<packetList.pointee.numPackets {
            let bytes = Mirror(reflecting: packet.data).children
            var data: [UInt8] = []
            data.reserveCapacity(Int(packet.length))
            var i = 0
            for child in bytes {
                if i >= Int(packet.length) { break }
                if let b = child.value as? UInt8 {
                    data.append(b)
                    i += 1
                }
            }

            // Parse messages (very small parser for note-on/note-off)
            var idx = 0
            while idx < data.count {
                let status = data[idx]
                // Channel voice messages are 3 bytes (note on/off) in most cases
                if (status & 0xF0) == 0x90, idx + 2 < data.count {
                    let note = Int(data[idx + 1])
                    let vel = data[idx + 2]
                    if vel > 0 {
                        emit(noteNumber: note)
                    }
                    idx += 3
                    continue
                }
                if (status & 0xF0) == 0x80, idx + 2 < data.count {
                    idx += 3
                    continue
                }

                // Skip unknown byte.
                idx += 1
            }

            packet = MIDIPacketNext(&packet).pointee
        }
    }

    private func emit(noteNumber: Int) {
        guard let letter = NoteLetter.fromSemitone(noteNumber) else { return }

        let now = DispatchTime.now().uptimeNanoseconds
        if letter == lastEmittedLetter, now - lastEmitTime < repeatCooldownNanos {
            return
        }

        lastEmittedLetter = letter
        lastEmitTime = now

        DispatchQueue.main.async { [weak self] in
            self?.lastDetectedLetter = letter
            self?.lastDetectedNoteNumber = noteNumber
            self?.onDetect?(letter)
        }
    }
}
