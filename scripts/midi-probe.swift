// Local integration probe for the app's CoreMIDI input/output. No hardware required.
import Foundation
import CoreMIDI

let mode = CommandLine.arguments.dropFirst().first ?? "listen"
var client: MIDIClientRef = 0
guard MIDIClientCreateWithBlock("Harmonic QA" as CFString,&client,nil) == noErr else { fatalError("MIDI client unavailable") }
defer { MIDIClientDispose(client) }
if mode == "send" {
    var source: MIDIEndpointRef = 0
    guard MIDISourceCreate(client,"Harmonic QA Input" as CFString,&source) == noErr else { fatalError("Source unavailable") }
    defer { MIDIEndpointDispose(source) }
    func send(_ down: Bool) {
        for note: UInt8 in [60,64,67] {
            var list = MIDIPacketList(); let bytes: [UInt8] = [down ? 0x90 : 0x80,note,down ? 96 : 0]
            withUnsafeMutablePointer(to: &list) { pointer in
                let packet = MIDIPacketListInit(pointer)
                bytes.withUnsafeBufferPointer { _ = MIDIPacketListAdd(pointer,MemoryLayout<MIDIPacketList>.size,packet,0,3,$0.baseAddress!) }
                MIDIReceived(source,pointer)
            }
        }
    }
    print("Source ready: Harmonic QA Input"); fflush(stdout)
    let timer = Timer.scheduledTimer(withTimeInterval: 2,repeats: true) { _ in send(true) }
    RunLoop.current.run(until: Date().addingTimeInterval(35)); timer.invalidate(); send(false)
} else {
    var port: MIDIPortRef = 0
    let lock = NSLock(); var noteOns = 0; var noteOffs = 0; var received: Set<UInt8> = []
    guard MIDIInputPortCreateWithBlock(client,"Harmonic QA Receiver" as CFString,&port,{ packetList,_ in
        var pointer = UnsafeRawPointer(packetList).advanced(by: MemoryLayout<MIDIPacketList>.offset(of: \.packet)!).assumingMemoryBound(to: MIDIPacket.self)
        for _ in 0..<packetList.pointee.numPackets {
            let bytes = UnsafeRawPointer(pointer).advanced(by: MemoryLayout<MIDIPacket>.offset(of: \.data)!).assumingMemoryBound(to: UInt8.self)
            let data = Array(UnsafeBufferPointer(start: bytes,count: Int(pointer.pointee.length)))
            lock.lock()
            var offset = 0
            while offset + 2 < data.count {
                let command = data[offset] & 0xf0
                if command == 0x90 && data[offset+2] > 0 { noteOns += 1; received.insert(data[offset+1]) }
                if command == 0x80 || (command == 0x90 && data[offset+2] == 0) { noteOffs += 1 }
                offset += 3
            }
            lock.unlock()
            pointer = UnsafePointer(MIDIPacketNext(pointer))
        }
    }) == noErr else { fatalError("Input unavailable") }
    defer { MIDIPortDispose(port) }
    var found = false
    for index in 0..<MIDIGetNumberOfSources() {
        let endpoint = MIDIGetSource(index);var name: Unmanaged<CFString>?
        if MIDIObjectGetStringProperty(endpoint,kMIDIPropertyName,&name) == noErr,let name = name?.takeRetainedValue(),String(name).contains("Harmonic Lab Out") {
            guard MIDIPortConnectSource(port,endpoint,nil) == noErr else { continue }; found = true
        }
    }
    guard found else { fatalError("Enable Harmonic Lab MIDI OUT before running the receiver") }
    print("Receiver ready");fflush(stdout)
    RunLoop.current.run(until: Date().addingTimeInterval(20))
    lock.lock();let result: [String:Any] = ["note_ons":noteOns,"note_offs":noteOffs,"pitches":received.sorted()];lock.unlock()
    let data = try JSONSerialization.data(withJSONObject: result,options: [.sortedKeys]);print(String(data: data,encoding: .utf8)!)
}
