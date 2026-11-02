import SwiftUI
import HarmonicCore

struct PianoKeyboard: View {
    let notes: ClosedRange<Int>
    let active: Set<Int>
    let scale: Set<Int>
    let root: Int
    let onKey: (Int) -> Void
    private func black(_ note: Int) -> Bool { [1,3,6,8,10].contains(Music.pc(note)) }
    var body: some View {
        GeometryReader { geometry in
            let whites = notes.filter { !black($0) }
            let width = geometry.size.width / Double(whites.count)
            ZStack(alignment: .topLeading) {
                HStack(spacing: 1) {
                    ForEach(whites,id: \.self) { note in
                        Button { onKey(note) } label: {
                            VStack(spacing: 0) {
                                if scale.contains(Music.pc(note)) { Capsule().fill(Music.pc(note) == root ? Studio.amber : Studio.teal.opacity(0.55)).frame(width: 12,height: 3).padding(.top,6) }
                                Spacer(); Text(Music.pc(note) == 0 ? Music.label(note) : Music.note(note)).font(.system(size: 9,weight: Music.pc(note) == root ? .bold : .regular,design: .monospaced)).foregroundStyle(Color(hex: 0x69716D)).padding(.bottom,8)
                            }.frame(maxWidth: .infinity).frame(height: geometry.size.height).background(active.contains(note) ? Studio.teal : Color(hex: 0xDADFD8),in: UnevenRoundedRectangle(bottomLeadingRadius: 4,bottomTrailingRadius: 4))
                        }.buttonStyle(.plain).accessibilityLabel("Piano \(Music.label(note))").accessibilityValue(active.contains(note) ? "On" : "Off")
                    }
                }
                ForEach(notes.filter { black($0) },id: \.self) { note in
                    let before = whites.filter { $0 < note }.count
                    Button { onKey(note) } label: {
                        VStack { Spacer(); if active.contains(note) { Circle().fill(Studio.background).frame(width: 4,height: 4).padding(.bottom,8) } }
                            .frame(width: width * 0.61,height: geometry.size.height * 0.64).background(active.contains(note) ? Studio.teal : Color(hex: 0x24292A),in: UnevenRoundedRectangle(bottomLeadingRadius: 4,bottomTrailingRadius: 4)).overlay(UnevenRoundedRectangle(bottomLeadingRadius: 4,bottomTrailingRadius: 4).strokeBorder(Color.black.opacity(0.5),lineWidth: 1))
                    }.buttonStyle(.plain).position(x: Double(before) * width,y: geometry.size.height * 0.32).accessibilityLabel("Piano \(Music.label(note))").accessibilityValue(active.contains(note) ? "On" : "Off")
                }
            }
        }
    }
}
struct PianoRollView: View {
    var project: Project
    var playhead: Double
    var body: some View {
        Canvas { context,size in
            let events = Arrangement.events(for: project)
            let beats = max(16,project.totalBeats)
            let low = min(45,events.map(\.note).min() ?? 48) - 1
            let high = max(76,events.map(\.note).max() ?? 72) + 1
            let row = size.height / Double(high-low+1)
            context.fill(Path(CGRect(origin: .zero,size: size)),with: .color(Studio.sidebar))
            for pitch in low...high {
                let y = Double(high-pitch) * row
                if [1,3,6,8,10].contains(Music.pc(pitch)) { context.fill(Path(CGRect(x: 0,y: y,width: size.width,height: row)),with: .color(Studio.background.opacity(0.4))) }
            }
            for beat in 0...Int(beats) {
                let x = Double(beat) / beats * size.width
                var path = Path(); path.move(to: CGPoint(x: x,y: 0)); path.addLine(to: CGPoint(x: x,y: size.height))
                context.stroke(path,with: .color(beat % 4 == 0 ? Studio.line : Studio.line.opacity(0.4)),lineWidth: 1)
            }
            for event in events {
                let rect = CGRect(x: event.start / beats * size.width + 1,y: Double(high-event.note) * row + 0.5,width: max(2,event.duration / beats * size.width - 2),height: max(2,row - 1))
                context.fill(Path(roundedRect: rect,cornerRadius: 1.5),with: .color(Studio.teal.opacity(0.8)))
            }
            if playhead > 0 {
                let x = playhead / beats * size.width
                context.fill(Path(CGRect(x: x,y: 0,width: 1.5,height: size.height)),with: .color(Studio.amber))
            }
        }.clipShape(RoundedRectangle(cornerRadius: 6)).overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Studio.line,lineWidth: 1)).accessibilityLabel("Piano roll showing \(project.clips.count) chords")
    }
}
