import SwiftUI

struct FinishedView: View {
    @Bindable var model: AppModel
    let engine: AudioEngine
    @State private var pulse = false
    @State private var streakShown = false

    private var message: String {
        let mins = model.targetDuration / 60
        let name = chapter(model.selectedSurah)?.nameSimple ?? ""
        if model.mode == "surah" && model.surahTimerEnabled {
            return "\(mins) minutes with Surah \(name). May Allah bless your consistency."
        } else if model.mode == "surah" {
            return "Surah \(name), beginning to end. May Allah bless your consistency."
        }
        return "\(mins) minutes with the words of Allah. May He bless your consistency."
    }

    var body: some View {
        VStack(spacing: 48) {
            ZStack {
                RoundedRectangle(cornerRadius: 40)
                    .fill(LinearGradient(colors: [.goldDeep, .gold],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 128, height: 128)
                    .rotationEffect(.degrees(12))
                    .shadow(color: Color.goldDeep.opacity(0.35), radius: 25, x: 0, y: 25)
                    .overlay(
                        Bi("heart-fill", size: 56).foregroundStyle(.white)
                            .rotationEffect(.degrees(12))
                    )
                RoundedRectangle(cornerRadius: 48)
                    .stroke(Color.goldSoft, lineWidth: 1)
                    .frame(width: 160, height: 160)
                    .scaleEffect(pulse ? 1.2 : 1)
                    .opacity(pulse ? 0.7 : 0.3)
            }
            .onAppear {
                if !UIAccessibility.isReduceMotionEnabled {
                    withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { pulse = true }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    withAnimation(anim(.easeOut(duration: 0.5))) { streakShown = true }
                }
            }

            VStack(spacing: 16) {
                Text("Barakallahu\nFeekum.")
                    .font(.playfair(48, bold: true, italic: true))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.warm900)
                    .lineSpacing(2)
                Text(message)
                    .font(.inter(20))
                    .foregroundStyle(Color.warm500)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
                    .frame(maxWidth: 384)
            }

            if model.streak.count > 0 {
                HStack(spacing: 12) {
                    Text("🔥").font(.system(size: 20))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("LISTENING STREAK")
                            .font(.mono(10)).tracking(1.2).foregroundStyle(Color.warm400)
                        Text("\(model.streak.count) day\(model.streak.count == 1 ? "" : "s")")
                            .font(.mono(18, .bold)).foregroundStyle(Color.warm900)
                    }
                }
                .padding(.horizontal, 20).padding(.vertical, 12)
                .background(Capsule().fill(Color.white))
                .overlay(Capsule().stroke(Color.warm200, lineWidth: 1))
                .shadowCard()
                .opacity(streakShown ? 1 : 0)
                .offset(y: streakShown ? 0 : 12)
            }

            VStack(spacing: 16) {
                Button { model.view = .setup } label: {
                    Text("New Session")
                        .font(.inter(20, .bold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(.vertical, 24)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.black))
                        .shadowOverlay()
                }
                .pressable(0.98)
                Button { engine.handleRepeat() } label: {
                    Text("REPEAT").font(.inter(14, .bold)).tracking(1.2)
                        .foregroundStyle(Color.warm500)
                        .padding(.vertical, 16)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 48)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}
