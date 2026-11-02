# Specification and evidence boundaries

## Reference observations

Scaler 3.3.2 at `/Applications/Scaler 3.app` exposes a transport, Detect section, scale explorer, Current Scale section, Main Track, instrument selection, keyboard/fretboard controls, Motion, Humanize, Keys Lock and Voice Grouping. These were read from the visible layout and accessibility labels.

The installed trial is expired. Interactions behind the registration overlay and exact outputs of Scaler workflows have not been observed. Ghidra evidence `ev_bfbb3c8989eac414aa19dc82d90794362515b3db0954234c91995ce11c0cdb79` provides static pseudocode for `EssentiaAnalyser::tryToDetectChord`, including chord comparison and frame accumulation. It does not establish Scaler's complete detection pipeline or runtime accuracy.

## Independent implementation choices

- New name, visual tokens, icon and sounds. A/B/C stage structure follows the observed workflow; this is not a pixel-for-pixel reconstruction.
- Music theory uses explicit scale interval tables, tertian chord construction, pitch-class template matching and a greedy voice-leading search.
- Audio detection uses Accelerate FFT and approximate chroma matching. It does not reproduce the decompiled Scaler routine.
- Synthesis is additive and uses original envelopes. Project format and MIDI/WAV encoding are implemented independently.

## Verification checklist

| Question | Status | Evidence |
|---|---|---|
| Runs as a standalone native macOS app? | Answered | Release build, local code signature and native UI launch |
| Scale/chord sets are internally valid across roots? | Answered | Tests for every supported scale/root and triad/seventh setting |
| Core MIDI/WAV files work with an independent decoder? | Answered | Apple AudioToolbox and AVAudioFile integration test |
| UI detect/add/undo and file export work? | Answered | Native UI walkthrough and saved verification artifacts |
| MIDI input/output work without hardware? | Answered | Virtual source generated C/E/G; app detected C. Receiver observed 24 note-ons and 148 note-offs including panic, over 8 pitches |
| Audio import returns reviewable chords? | Partially answered | Exported demo analyzed into four segments; ambiguous Am7/C6 labeling |
| Matches Scaler's complete feature set, sound and interactions? | Unresolved | Requires an interactive authorized reference and substantially broader implementation |
| Real hardware, DAW routing and arbitrary real recordings? | Unresolved | Not covered by local synthetic/virtual tests |

No Scaler executable, extracted resource or decompiled body is incorporated into the application bundle. REA evidence remains separately in `../scaler3-rea`.
