import Foundation
import CoreMIDI
import HarmonicCore

private final class StreamReader: @unchecked Sendable {
    private let lock = NSLock()
    private var decoder = MIDIStreamDecoder()
    func read(_ bytes: [UInt8]) -> [(Int,Bool)] { lock.lock(); defer { lock.unlock() }; return decoder.feed(bytes) }
}

@MainActor final class MIDIService {
    private var client: MIDIClientRef = 0
    private var input: MIDIPortRef = 0
    private var source: MIDIEndpointRef = 0
    private var connected: [MIDIEndpointRef] = []
    var onNote: ((Int, Bool) -> Void)?
    var status = "MIDI input off"
    private func ensureClient() throws {
        if client == 0 {
            let result = MIDIClientCreateWithBlock("Harmonic Lab" as CFString, &client, nil)
            if result != noErr { throw MIDIError.code(result) }
        }
    }
    func listen(_ enabled: Bool) throws -> String {
        for endpoint in connected { MIDIPortDisconnectSource(input, endpoint) }; connected = []
        if input != 0 { MIDIPortDispose(input); input = 0 }
        guard enabled else { return "MIDI input off" }
        try ensureClient()
        let reader = StreamReader()
        let result = MIDIInputPortCreateWithBlock(client, "Harmonic Lab Input" as CFString, &input) { [weak self] packetList, _ in
            var messages: [(Int, Bool)] = []
            let offset = MemoryLayout<MIDIPacketList>.offset(of: \.packet)!
            do {
                var pointer = UnsafeRawPointer(packetList).advanced(by: offset).assumingMemoryBound(to: MIDIPacket.self)
                for _ in 0..<packetList.pointee.numPackets {
                    let dataOffset = MemoryLayout<MIDIPacket>.offset(of: \.data)!
                    let data = UnsafeRawPointer(pointer).advanced(by: dataOffset).assumingMemoryBound(to: UInt8.self)
                    messages += reader.read(Array(UnsafeBufferPointer(start: data,count: Int(pointer.pointee.length))))
                    pointer = UnsafePointer(MIDIPacketNext(pointer))
                }
            }
            DispatchQueue.main.async { for (note, down) in messages { self?.onNote?(note, down) } }
        }
        guard result == noErr else { throw MIDIError.code(result) }
        for index in 0..<MIDIGetNumberOfSources() {
            let endpoint = MIDIGetSource(index)
            if endpoint == source { continue }
            if MIDIPortConnectSource(input, endpoint, nil) == noErr { connected.append(endpoint) }
        }
        return connected.isEmpty ? "No MIDI source found · reconnect to refresh" : "Listening to \(connected.count) MIDI source\(connected.count == 1 ? "" : "s")"
    }
    func enableOutput() throws {
        try ensureClient()
        if source == 0 {
            let result = MIDISourceCreate(client, "Harmonic Lab Out" as CFString, &source)
            if result != noErr { throw MIDIError.code(result) }
        }
    }
    func send(note: Int, down: Bool, velocity: Int = 88) {
        guard source != 0 else { return }
        var list = MIDIPacketList()
        let bytes: [UInt8] = [down ? 0x90 : 0x80, UInt8(clamping: note), down ? UInt8(clamping: velocity) : 0]
        withUnsafeMutablePointer(to: &list) { ptr in
            let packet = MIDIPacketListInit(ptr)
            bytes.withUnsafeBufferPointer { data in
                _ = MIDIPacketListAdd(ptr, MemoryLayout<MIDIPacketList>.size, packet, 0, data.count, data.baseAddress!)
            }
            MIDIReceived(source, ptr)
        }
    }
    func panic() { for note in 0..<128 { send(note: note, down: false) } }
    func dispose() {
        panic()
        if input != 0 { MIDIPortDispose(input); input = 0 }
        if source != 0 { MIDIEndpointDispose(source); source = 0 }
        if client != 0 { MIDIClientDispose(client); client = 0 }
    }
}
enum MIDIError: LocalizedError { case code(OSStatus); var errorDescription: String? { if case .code(let status) = self { return "CoreMIDI returned error \(status)." }; return nil } }
