import SwiftUI
import HarmonicCore
import UniformTypeIdentifiers

struct WorkstationView: View {
    @EnvironmentObject var m: AppModel
    var body: some View {
        VStack(spacing: 0) {
            transport
            Rectangle().fill(Studio.line).frame(height: 1)
            HStack(spacing: 0) {
                sidebar.frame(width: 176)
                Rectangle().fill(Studio.line).frame(width: 1)
                VStack(spacing: 0) {
                    keyBar
                    ScrollView {
                        VStack(spacing: 0) {
                            if m.browser == "Detect" { DetectionView().padding(12) }
                            else if m.browser == "Arrange" { arrangementIntro.padding(12) }
                            else { explorer.padding(12) }
                            Divider().overlay(Studio.line)
                            chordShelf.padding(12)
                            Divider().overlay(Studio.line)
                            progression.padding(12)
                        }
                    }.scrollIndicators(.hidden)
                }
                if m.inspector {
                    Rectangle().fill(Studio.line).frame(width: 1)
                    InspectorView().frame(width: 224)
                }
            }.layoutPriority(-1)
            Rectangle().fill(Studio.line).frame(height: 1)
            keyboardPanel
            statusBar.fixedSize(horizontal: false,vertical: true)
        }
        .background(Studio.background).foregroundStyle(Studio.text).tint(Studio.amber)
        .font(.system(size: 13))
        .alert("Harmonic Lab", isPresented: Binding(get: { m.errorMessage != nil },set: { if !$0 { m.errorMessage = nil } })) { Button("OK") { m.errorMessage = nil } } message: { Text(m.errorMessage ?? "") }
    }
    private var transport: some View {
        HStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "waveform.path").font(.system(size: 24,weight: .medium)).foregroundStyle(Studio.amber)
                VStack(alignment: .leading,spacing: 1) { Text("HARMONIC").font(.system(size: 13,weight: .bold,design: .rounded)).tracking(2); Text("LAB / 01").font(.system(size: 9,weight: .medium,design: .monospaced)).foregroundStyle(Studio.dim).tracking(2) }
            }.frame(width: 151,alignment: .leading).padding(.leading, 10)
            Rectangle().fill(Studio.line).frame(width: 1,height: 30)
            VStack(alignment: .leading,spacing: 3) {
                TextField("Session name",text: $m.project.name).textFieldStyle(.plain).font(.system(size: 13,weight: .medium)).frame(maxWidth: 250,alignment: .leading)
                Text("\(m.project.clips.count) chords  /  \(String(format: "%g", m.project.totalBeats / 4)) bars  /  4/4").font(.system(size: 10,design: .monospaced)).foregroundStyle(Studio.dim)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                IconButton(icon: "backward.end.fill",help: "Return to start") { m.stop() }
                Button { m.togglePlayback() } label: {
                    Group { if m.isRendering { ProgressView().controlSize(.small) } else { Image(systemName: m.isPlaying ? "stop.fill" : "play.fill") } }.frame(width: 42,height: 36)
                }.buttonStyle(StudioButton(active: true)).help("Play / stop · Space").accessibilityLabel("Play or stop progression")
                IconButton(icon: "repeat",help: "Loop progression",active: m.loop) { m.loop.toggle() }
            }
            HStack(spacing: 6) {
                Image(systemName: "metronome").foregroundStyle(Studio.dim)
                TextField("Tempo",value: Binding(get: { m.project.tempo },set: m.setTempo),format: .number.precision(.fractionLength(0))).textFieldStyle(.plain).multilineTextAlignment(.trailing).frame(width: 35)
                Text("BPM").font(.system(size: 9,weight: .medium)).foregroundStyle(Studio.dim)
                Stepper("Tempo",value: $m.project.tempo,in: 40...240).labelsHidden().controlSize(.mini)
            }.padding(.horizontal,8).padding(.vertical,6).background(Studio.sidebar,in: RoundedRectangle(cornerRadius: 6))
            Menu {
                Button("Export MIDI…") { DispatchQueue.main.async { m.exportMIDI() } }
                Button("Export WAV…") { DispatchQueue.main.async { m.exportWAV() } }
                Divider(); Button("Save Session…") { DispatchQueue.main.async { m.save() } }; Button("Open Session…") { DispatchQueue.main.async { m.open() } }
            } label: { Label("Export",systemImage: "square.and.arrow.up") }.menuStyle(.borderlessButton).fixedSize().padding(.horizontal,12).padding(.vertical,9).background(Studio.panel,in: RoundedRectangle(cornerRadius: 6)).disabled(m.project.clips.isEmpty)
            IconButton(icon: "sidebar.right",help: "Toggle chord inspector",active: m.inspector) { m.inspector.toggle() }
        }.padding(.horizontal,16).frame(height: 64)
    }
    private var sidebar: some View {
        VStack(alignment: .leading,spacing: 0) {
            Text("WORKSPACE").font(.system(size: 9,weight: .semibold)).tracking(1.6).foregroundStyle(Studio.dim).padding(.horizontal,20).padding(.top,24).padding(.bottom,12)
            ForEach([("Explore","square.grid.2x2"),("Arrange","rectangle.split.3x1"),("Detect","waveform")],id: \.0) { name,icon in
                Button { m.browser = name } label: {
                    HStack(spacing: 10) { Image(systemName: icon).frame(width: 16); Text(name); Spacer(); if m.browser == name { Circle().fill(Studio.amber).frame(width: 5,height: 5) } }
                        .font(.system(size: 12,weight: m.browser == name ? .semibold : .regular)).foregroundStyle(m.browser == name ? Studio.text : Studio.muted).padding(.horizontal,12).frame(height: 40).background(m.browser == name ? Studio.panel : Color.clear,in: RoundedRectangle(cornerRadius: 7))
                }.buttonStyle(.plain).padding(.horizontal,8)
            }
            Rectangle().fill(Studio.line).frame(height: 1).padding(20)
            Text("STARTING POINTS").font(.system(size: 9,weight: .semibold)).tracking(1.4).foregroundStyle(Studio.dim).padding(.horizontal,20).padding(.bottom,12)
            presetButton("Open horizons",subtitle: "I · vi · IV · V",indices: [0,5,3,4])
            presetButton("After hours",subtitle: "ii · V · I · vi",indices: [1,4,0,5])
            presetButton("Slow bloom",subtitle: "I · IV · vi · V",indices: [0,3,5,4])
            presetButton("Homeward",subtitle: "vi · IV · I · V",indices: [5,3,0,4])
            Spacer(minLength: 24)
            VStack(alignment: .leading,spacing: 10) {
                Text("MAKE ROOM FOR AN IDEA.").font(.system(size: 10,weight: .medium,design: .monospaced)).foregroundStyle(Studio.amber).lineSpacing(4)
                Text("Choose a scale.\nFind a chord.\nSee where it goes.").font(.system(size: 12)).foregroundStyle(Studio.dim).lineSpacing(5)
                Button { m.newProject() } label: { Label("New session",systemImage: "plus") }.buttonStyle(.plain).foregroundStyle(Studio.muted).padding(.top,8)
            }.padding(20)
            HStack(spacing: 5) { Circle().fill(Studio.teal).frame(width: 5,height: 5); Text("LOCAL · AUTOSAVED").font(.system(size: 8,weight: .medium,design: .monospaced)).tracking(0.5) }.foregroundStyle(Studio.dim).padding(20)
        }.background(Studio.sidebar)
    }
    private func presetButton(_ name: String,subtitle: String,indices: [Int]) -> some View {
        Button { m.loadPreset(indices,name: name) } label: {
            VStack(alignment: .leading,spacing: 5) { Text(name).font(.system(size: 12)); Text(subtitle).font(.system(size: 10,design: .monospaced)).foregroundStyle(Studio.dim) }.frame(maxWidth: .infinity,alignment: .leading).padding(.horizontal,20).padding(.vertical,11)
        }.buttonStyle(.plain).help("Replace progression with \(name)")
    }
    private var keyBar: some View {
        HStack(spacing: 12) {
            Text("KEY").font(.system(size: 9,weight: .semibold)).tracking(1).foregroundStyle(Studio.dim)
            Picker("Root note",selection: $m.project.root) { ForEach(0..<12,id: \.self) { Text(Music.note($0)).tag($0) } }.labelsHidden().frame(width: 74)
            Picker("Scale",selection: $m.project.scale) { ForEach(ScaleKind.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 155)
            Spacer()
            IconButton(icon: "arrow.uturn.backward",help: "Undo") { m.undo() }.disabled(!m.canUndo)
            IconButton(icon: "arrow.uturn.forward",help: "Redo") { m.redo() }.disabled(!m.canRedo)
        }.controlSize(.small).padding(.horizontal,20).frame(height: 50).background(Studio.sidebar.opacity(0.5))
    }
    private var explorer: some View {
        VStack(spacing: 0) {
            SectionHeading(letter: "A",title: "Explore",detail: "12 scales & modes") {
                HStack(spacing: 4) { Image(systemName: "magnifyingglass").foregroundStyle(Studio.dim); TextField("Find a scale or mood",text: $m.filter).textFieldStyle(.plain).font(.system(size: 11)).frame(width: 145) }.padding(7).background(Studio.sidebar,in: RoundedRectangle(cornerRadius: 5))
            }
            HStack { Text("SCALE").frame(width: 166,alignment: .leading); Text("CHARACTER"); Spacer(); Text("NOTES").frame(width: 172,alignment: .leading) }.font(.system(size: 8,weight: .semibold)).tracking(1).foregroundStyle(Studio.dim).padding(.horizontal,10).padding(.bottom,8)
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(m.visibleScales,id: \.kind) { scale in
                        Button { m.setScale(scale) } label: {
                            HStack(spacing: 8) {
                                HStack(spacing: 7) { Circle().fill(scale.kind == m.project.scale ? Studio.teal : Studio.line).frame(width: 5,height: 5); Text(scale.name).font(.system(size: 12,weight: scale.kind == m.project.scale ? .semibold : .regular)) }.frame(width: 166,alignment: .leading)
                                Text(scale.kind.character).font(.system(size: 10)).foregroundStyle(Studio.dim).lineLimit(1)
                                Spacer(minLength: 4)
                                HStack(spacing: 3) { ForEach(scale.kind.intervals,id: \.self) { i in Text(Music.note(i + scale.root)).font(.system(size: 8,weight: .medium,design: .monospaced)).frame(width: 21,height: 21).background(scale.kind == m.project.scale ? Studio.teal.opacity(0.12) : Studio.panel,in: RoundedRectangle(cornerRadius: 3)) } }.frame(width: 172,alignment: .leading)
                            }.padding(.horizontal,10).frame(height: 37).background(scale.kind == m.project.scale ? Studio.teal.opacity(0.08) : Color.clear,in: RoundedRectangle(cornerRadius: 5))
                        }.buttonStyle(.plain)
                    }
                    if m.visibleScales.isEmpty { Text("No scales match this search.").foregroundStyle(Studio.dim).padding(24) }
                }
            }.frame(height: 96).scrollIndicators(.visible)
        }
    }
    private var arrangementIntro: some View {
        VStack(alignment: .leading,spacing: 12) {
            SectionHeading(letter: "A",title: "Arrange",detail: "Your harmonic sketchbook") { EmptyView() }
            PianoRollView(project: m.project,playhead: m.playhead).frame(height: 140)
            Text("Select a clip below to change its voicing, length or position. Voice leading keeps nearby chord tones close.").font(.system(size: 11)).foregroundStyle(Studio.dim)
        }
    }
    private var chordShelf: some View {
        VStack(alignment: .leading,spacing: 0) {
            SectionHeading(letter: "B",title: m.scale.name,detail: "Current scale") {
                Picker("Chord extensions",selection: $m.sevenths) { Text("Triads").tag(false); Text("Sevenths").tag(true) }.labelsHidden().pickerStyle(.segmented).frame(width: 132)
                Stepper(value: $m.project.octave,in: 1...5) { Text("Oct \(m.project.octave)").font(.system(size: 10,design: .monospaced)) }.fixedSize()
            }
            HStack(spacing: 7) { ForEach(Array(m.scaleChords.enumerated()),id: \.offset) { index,chord in ChordTile(chord: chord,roman: m.scale.roman(for: chord),selected: m.selectedChord.root == chord.root && m.selectedChord.quality == chord.quality).frame(maxWidth: .infinity) } }
            HStack(spacing: 5) { Image(systemName: "cursorarrow"); Text("Click to audition. + to add. Drag a chord into your progression.") }.font(.system(size: 10)).foregroundStyle(Studio.dim).padding(.top,10)
        }
    }
    private var progression: some View {
        VStack(alignment: .leading,spacing: 0) {
            SectionHeading(letter: "C",title: "Progression",detail: "\(m.project.clips.count) chords") {
                HStack(spacing: 3) { Text("Transpose").font(.system(size: 10)).foregroundStyle(Studio.dim); IconButton(icon: "minus",help: "Transpose down a semitone") { m.transpose(-1) }; IconButton(icon: "plus",help: "Transpose up a semitone") { m.transpose(1) } }
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(Array(m.project.clips.enumerated()),id: \.element.id) { index,clip in
                        Button { m.select(clip) } label: {
                            VStack(alignment: .leading,spacing: 8) {
                                HStack { Text(String(format: "%02d", index + 1)).font(.system(size: 9,design: .monospaced)).foregroundStyle(Studio.dim); Spacer(); if m.currentPlayingIndex == index { Image(systemName: "speaker.wave.2.fill").foregroundStyle(Studio.amber).font(.system(size: 9)) } else { Text(m.scale.roman(for: clip.chord)).foregroundStyle(Studio.teal).font(.system(size: 10,weight: .medium)) } }
                                Text(clip.chord.name).font(.system(size: 23,weight: .medium,design: .rounded))
                                HStack { Text("\(String(format: "%g", clip.beats)) beats"); Spacer(); if clip.chord.inversion > 0 { Text("inv \(clip.chord.inversion)") } }.font(.system(size: 9,design: .monospaced)).foregroundStyle(Studio.dim)
                                Capsule().fill(m.currentPlayingIndex == index ? Studio.amber : Studio.teal.opacity(0.35)).frame(height: 3)
                            }.padding(12).frame(width: 122).background(m.selectedClip == clip.id ? Studio.panel : Studio.sidebar,in: RoundedRectangle(cornerRadius: 8)).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(m.currentPlayingIndex == index ? Studio.amber : m.selectedClip == clip.id ? Studio.teal : Studio.line,lineWidth: 1))
                        }.buttonStyle(.plain).accessibilityLabel("Clip \(index+1), \(clip.chord.name), \(Int(clip.beats)) beats")
                        .contextMenu { Button("Duplicate") { m.selectedClip = clip.id; m.duplicateSelected() }; Button("Delete",role: .destructive) { m.selectedClip = clip.id; m.removeSelected() } }
                    }
                    Button { m.add(m.selectedChord) } label: { VStack(spacing: 8) { Image(systemName: "plus").font(.system(size: 18,weight: .light)); Text("Add chord").font(.system(size: 10)) }.foregroundStyle(Studio.dim).frame(width: 100,height: 104).overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Studio.line,style: StrokeStyle(lineWidth: 1,dash: [4,4]))) }.buttonStyle(.plain)
                }.padding(.vertical,2)
            }.scrollIndicators(.visible)
            .dropDestination(for: String.self) { items,_ in
                guard let token = items.first, let chord = decodeChord(token) else { return false }; m.add(chord); return true
            }
            HStack(spacing: 10) {
                Picker("Motion",selection: $m.project.motion) { ForEach(Motion.allCases) { Text($0.rawValue).tag($0) } }.frame(width: 148)
                Toggle("Voice leading",isOn: $m.project.voiceLeading).toggleStyle(.checkbox).font(.system(size: 11))
                Spacer()
                Text("4/4").font(.system(size: 10,design: .monospaced)).foregroundStyle(Studio.dim)
            }.controlSize(.small).padding(.top,14)
        }
    }
    private var keyboardPanel: some View {
        HStack(spacing: 0) {
            VStack(alignment: .leading,spacing: 10) {
                Text("INSTRUMENT").font(.system(size: 8,weight: .semibold)).tracking(1.5).foregroundStyle(Studio.dim)
                Picker("Instrument",selection: $m.instrument) { ForEach(Instrument.allCases) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 146)
                HStack { Image(systemName: "speaker.wave.1").foregroundStyle(Studio.dim); Slider(value: $m.volume,in: 0...1).frame(width: 114) }.controlSize(.mini)
                Text("Original synthesized sounds").font(.system(size: 8)).foregroundStyle(Studio.dim)
            }.padding(.horizontal,16).frame(width: 176)
            VStack(spacing: 0) {
                HStack { Text(m.soundingNotes.sorted().map { Music.note($0) }.joined(separator: "  ")).font(.system(size: 10,design: .monospaced)).foregroundStyle(Studio.teal); Spacer(); Text("Click keys to latch notes for detection").font(.system(size: 9)).foregroundStyle(Studio.dim); Button("Clear",action: m.clearInput).buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(Studio.amber) }.frame(height: 29).padding(.horizontal,12)
                PianoKeyboard(notes: 48...83,active: m.soundingNotes.union(m.inputNotes),scale: m.scale.pitchClasses,root: m.project.root,onKey: m.toggleKey).frame(height: 104).padding(.horizontal,8).padding(.bottom,8)
            }
        }.background(Studio.sidebar)
    }
    private var statusBar: some View {
        HStack(spacing: 8) {
            Circle().fill(m.isPlaying ? Studio.amber : Studio.teal).frame(width: 4,height: 4)
            Text(m.notice).lineLimit(1)
            Spacer(); Button { m.toggleMIDIInput() } label: { Text(m.midiEnabled ? "MIDI IN ON" : "MIDI IN OFF") }.buttonStyle(.plain).foregroundStyle(m.midiEnabled ? Studio.teal : Studio.dim).help(m.midiStatus)
            Text("/ ").foregroundStyle(Studio.line)
            Button { m.toggleMIDIOutput() } label: { Text(m.midiOutput ? "MIDI OUT ON" : "MIDI OUT OFF") }.buttonStyle(.plain).foregroundStyle(m.midiOutput ? Studio.teal : Studio.dim).help("Virtual MIDI source for your DAW")
        }.font(.system(size: 9,design: .monospaced)).foregroundStyle(Studio.dim).padding(.horizontal,16).frame(height: 27).background(Studio.background)
    }
}

func chordToken(_ chord: Chord) -> String { "harmonic:\(chord.root):\(chord.quality.rawValue):\(chord.octave)" }
func decodeChord(_ token: String) -> Chord? {
    let parts = token.split(separator: ":"); guard parts.count == 4,parts[0] == "harmonic",let root = Int(parts[1]),(0..<12).contains(root),let quality = ChordQuality(rawValue: String(parts[2])),let octave = Int(parts[3]),(1...5).contains(octave) else { return nil }
    return Chord(root: root,quality: quality,octave: octave)
}
struct ChordTile: View {
    @EnvironmentObject var m: AppModel
    var chord: Chord
    var roman: String
    var selected: Bool
    var body: some View {
        VStack(alignment: .leading,spacing: 9) {
            HStack { Text(roman).font(.system(size: 10,weight: .medium,design: .monospaced)).foregroundStyle(Studio.teal); Spacer(minLength: 0); Button { m.add(chord) } label: { Image(systemName: "plus").font(.system(size: 10)).frame(width: 22,height: 20) }.buttonStyle(.plain).help("Add \(chord.name) to progression").accessibilityLabel("Add \(chord.name)") }
            Button { m.audition(chord) } label: {
                VStack(alignment: .leading,spacing: 7) { Text(chord.name).font(.system(size: 19,weight: .medium,design: .rounded)).lineLimit(1).minimumScaleFactor(0.65); HStack(spacing: 2) { ForEach(0..<12,id: \.self) { pitch in Capsule().fill(chord.pitchClasses.contains(pitch) ? Studio.teal : Studio.line).frame(height: chord.pitchClasses.contains(pitch) ? 12 : 5) } }.frame(height: 12) }.frame(maxWidth: .infinity,alignment: .leading)
            }.buttonStyle(.plain).accessibilityLabel("Audition \(chord.name)")
        }.padding(9).background(selected ? Studio.teal.opacity(0.09) : Studio.sidebar,in: RoundedRectangle(cornerRadius: 7)).overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(selected ? Studio.teal.opacity(0.65) : Studio.line,lineWidth: 1)).draggable(chordToken(chord))
    }
}
