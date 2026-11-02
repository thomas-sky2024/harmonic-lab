import SwiftUI

enum Studio {
    static let background = Color(hex: 0x191C1D)
    static let sidebar = Color(hex: 0x202425)
    static let panel = Color(hex: 0x282D2E)
    static let line = Color(hex: 0x373E3F)
    static let text = Color(hex: 0xF0F1EC)
    static let muted = Color(hex: 0xA3AEAC)
    static let dim = Color(hex: 0x798582)
    static let amber = Color(hex: 0xE4B978)
    static let teal = Color(hex: 0x89C5BB)
    static let red = Color(hex: 0xDE8880)
}
extension Color {
    init(hex: UInt32) { self.init(.sRGB, red: Double((hex >> 16) & 255)/255, green: Double((hex >> 8) & 255)/255, blue: Double(hex & 255)/255, opacity: 1) }
}
struct StudioButton: ButtonStyle {
    var active = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .foregroundStyle(active ? Studio.background : Studio.text)
            .padding(.horizontal, 12).frame(minHeight: 32)
            .background(active ? Studio.amber : (configuration.isPressed ? Studio.line : Studio.panel), in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(active ? Color.clear : Studio.line, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.8 : 1)
    }
}
struct IconButton: View {
    let icon: String
    let help: String
    var active = false
    var action: () -> Void
    var body: some View {
        Button(action: action) { Image(systemName: icon).font(.system(size: 13, weight: .medium)).frame(width: 32,height: 32).foregroundStyle(active ? Studio.amber : Studio.muted).background(active ? Studio.amber.opacity(0.1) : Color.clear, in: RoundedRectangle(cornerRadius: 6)) }
            .buttonStyle(.plain).help(help).accessibilityLabel(help)
    }
}
struct SectionHeading<Trailing: View>: View {
    var letter: String
    var title: String
    var detail: String
    @ViewBuilder var trailing: () -> Trailing
    var body: some View {
        HStack(spacing: 10) {
            Text(letter).font(.system(size: 12,weight: .bold,design: .monospaced)).foregroundStyle(Studio.amber).frame(width: 24,height: 24).background(Studio.amber.opacity(0.1),in: RoundedRectangle(cornerRadius: 5))
            Text(title).font(.system(size: 15,weight: .semibold)); Text(detail).font(.system(size: 11)).foregroundStyle(Studio.dim)
            Spacer(minLength: 8); trailing()
        }.padding(.bottom, 12)
    }
}
