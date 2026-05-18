import SwiftUI

// MARK: - Press scale (replaces web hover/active :scale-*)

struct PressStyle: ButtonStyle {
    var pressed: CGFloat = 0.95
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? pressed : 1)
            .animation(anim(.easeOut(duration: 0.15)), value: configuration.isPressed)
    }
}

extension View {
    func pressable(_ scale: CGFloat = 0.95) -> some View { buttonStyle(PressStyle(pressed: scale)) }
}

// MARK: - Pill toggle (knob translateX 180ms ease-out)

struct PillToggle: View {
    @Binding var isOn: Bool
    var large: Bool = false

    private var trackW: CGFloat { large ? 44 : 32 }
    private var trackH: CGFloat { large ? 24 : 20 }
    private var knob: CGFloat { large ? 20 : 16 }
    private var travel: CGFloat { large ? 20 : 13 }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: trackH / 2)
                .fill(isOn ? Color.warm900 : Color.warm200)
                .frame(width: trackW, height: trackH)
                .animation(anim(.easeInOut(duration: 0.15)), value: isOn)
            Circle()
                .fill(.white)
                .frame(width: knob, height: knob)
                .shadow(color: .black.opacity(large ? 0.12 : 0), radius: large ? 1 : 0, y: large ? 1 : 0)
                .padding(.leading, 2)
                .offset(x: isOn ? travel : 0)
                .animation(anim(.easeOut(duration: 0.18)), value: isOn)
        }
        .frame(width: trackW, height: trackH)
    }
}

// MARK: - Segmented control (bg-warm-100, selected = white card)

struct SegItem: Identifiable, Hashable {
    let id: String
    let label: String
    var dot: Color? = nil
}

struct Segmented: View {
    let items: [SegItem]
    @Binding var selection: String
    var corner: CGFloat = 12      // inner button radius
    var outerCorner: CGFloat = 16
    var vPad: CGFloat = 8
    var font: Font = .inter(14, .bold)

    var body: some View {
        HStack(spacing: 4) {
            ForEach(items) { item in
                Button {
                    selection = item.id
                } label: {
                    HStack(spacing: 8) {
                        if let dot = item.dot {
                            Circle().fill(dot).frame(width: 12, height: 12)
                        }
                        Text(item.label)
                    }
                    .font(font)
                    .foregroundStyle(selection == item.id ? Color.black : Color.warm400)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, vPad)
                    .background(
                        RoundedRectangle(cornerRadius: corner)
                            .fill(selection == item.id ? Color.white : Color.clear)
                            .shadow(color: selection == item.id ? .black.opacity(0.06) : .clear,
                                    radius: 1, y: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: outerCorner).fill(Color.warm100))
        .animation(anim(.easeInOut(duration: 0.3)), value: selection)
    }
}

// MARK: - Reveal transition (AnimatePresence opacity + y, height collapse)

extension AnyTransition {
    /// Section reveal — opacity + y(-8), like the PWA's inner AnimatePresence.
    static var reveal: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: -8)),
            removal: .opacity.combined(with: .offset(y: -8))
        )
    }
    /// Banner — opacity + y(-8) both directions.
    static var bannerSlide: AnyTransition {
        .opacity.combined(with: .offset(y: -8))
    }
}
