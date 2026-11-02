import SwiftUI
import AppKit

@main struct HarmonicLabApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            WorkstationView().environmentObject(model)
                .preferredColorScheme(.dark)
                .frame(minWidth: 1160, minHeight: 780)
                .onOpenURL { model.openSession($0) }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in model.stop(); model.midi.dispose() }
        }
        .defaultSize(width: 1280, height: 860)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Session") { model.newProject() }.keyboardShortcut("n")
                Button("Open Session…") { model.open() }.keyboardShortcut("o")
                Divider()
                Button("Import MIDI Chords…") { model.importMIDI() }
                Button("Analyze Audio File…") { model.browser = "Detect"; DispatchQueue.main.async { model.importAudio() } }.keyboardShortcut("i",modifiers: [.command,.shift])
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save Session…") { model.save() }.keyboardShortcut("s")
                Divider()
                Button("Export MIDI…") { model.exportMIDI() }.keyboardShortcut("e")
                Button("Export WAV…") { model.exportWAV() }.keyboardShortcut("e", modifiers: [.command,.shift])
            }
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") { model.undo() }.keyboardShortcut("z").disabled(!model.canUndo)
                Button("Redo") { model.redo() }.keyboardShortcut("z", modifiers: [.command,.shift]).disabled(!model.canRedo)
            }
            CommandMenu("Transport") {
                Button(model.isPlaying ? "Stop" : "Play") { model.togglePlayback() }.keyboardShortcut(.space, modifiers: [])
                Button("Stop All Notes") { model.stop(); model.clearInput() }.keyboardShortcut(.escape, modifiers: [])
                Toggle("Loop", isOn: $model.loop).keyboardShortcut("l")
            }
        }
    }
}
