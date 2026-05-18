import SwiftUI

struct SetupView: View {
    @Bindable var model: AppModel
    let engine: AudioEngine
    @State private var underline = false

    var body: some View {
        VStack(spacing: 48) {
            if model.showResumePrompt, let ls = model.lastSession {
                ResumeBanner(ls: ls,
                             onResume: { engine.handleResume() },
                             onDismiss: { engine.dismissResume() })
                    .transition(.bannerSlide)
            }
            if model.showReminderBanner {
                ReminderBanner(time: model.reminderTime) { model.showReminderBanner = false }
                    .transition(.bannerSlide)
            }

            // Greeting block
            VStack(alignment: .leading, spacing: 24) {
                Rectangle()
                    .fill(Color.gold)
                    .frame(width: 40, height: 4)
                    .scaleEffect(x: underline ? 1 : 0, anchor: .leading)
                let g = getGreeting()
                Text("\(g.line1)\n\(g.line2)")
                    .font(.resolide(48))
                    .tracking(-1.2)
                    .lineSpacing(5)
                    .foregroundStyle(Color.warm900)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(model.mode == "surah"
                     ? "Pick a surah. Listen from the first verse to the last."
                     : "Choose how long and who recites. We'll never cut off mid-verse.")
                    .font(.inter(20))
                    .foregroundStyle(Color.warm500)
                    .lineSpacing(6)
                    .frame(maxWidth: 384, alignment: .leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 32) {
                Segmented(items: [SegItem(id: "random", label: "Randomize Surah"),
                                  SegItem(id: "surah", label: "Choose Surah")],
                          selection: $model.mode,
                          corner: 12, outerCorner: 16, vPad: 12)

                Group {
                    if model.mode == "surah" {
                        SurahPicker(model: model).transition(.reveal)
                    } else {
                        DurationPicker(model: model).transition(.reveal)
                    }
                }
                .animation(anim(.easeOut(duration: 0.25)), value: model.mode)

                ReciterPicker(model: model)
            }

            Button { engine.startPlayback() } label: {
                HStack(spacing: 12) {
                    Text("Start Listening")
                    Bi("play-fill", size: 22)
                }
                .font(.inter(20, .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.black))
                .shadowDropdown()
            }
            .pressable(0.98)
        }
        .onAppear {
            withAnimation(anim(.easeOut(duration: 0.4))) { underline = true }
        }
    }
}

// MARK: - Field label (chevron/clock/globe + mono uppercase)

struct FieldLabel: View {
    let icon: String
    let text: String
    var body: some View {
        HStack(spacing: 8) {
            Bi(icon, size: 14)
            Text(text.uppercased()).font(.mono(12)).tracking(1.2)
        }
        .foregroundStyle(Color.warm400)
    }
}

// MARK: - Styled dropdown (matches the PWA <select> box)

struct StyledDropdown<T: Hashable>: View {
    let selection: Binding<T>
    let options: [(value: T, label: String)]
    var body: some View {
        Menu {
            Picker("", selection: selection) {
                ForEach(options, id: \.value) { Text($0.label).tag($0.value) }
            }
        } label: {
            HStack {
                Text(options.first { $0.value == selection.wrappedValue }?.label ?? "")
                    .font(.inter(18, .medium))
                    .foregroundStyle(Color.warm900)
                    .lineLimit(1)
                Spacer()
                Bi("chevron-right", size: 18)
                    .foregroundStyle(Color.warm400)
                    .rotationEffect(.degrees(90))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.warm200, lineWidth: 1))
        }
    }
}

// MARK: - Duration buttons + custom minutes

struct DurationButtons: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                ForEach(DURATIONS) { d in
                    let active = model.targetDuration == d.value && model.customMinutes.isEmpty
                    Button {
                        model.targetDuration = d.value
                        model.customMinutes = ""
                    } label: {
                        Text(d.label)
                            .font(.inter(18, .bold))
                            .foregroundStyle(active ? .white : Color.warm500)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(RoundedRectangle(cornerRadius: 16)
                                .fill(active ? Color.black : Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .stroke(active ? Color.black : Color.warm200, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .modifier(active ? AnyViewModifierShadowOverlay() : AnyViewModifierShadowOverlay(off: true))
                }
            }
            HStack(spacing: 12) {
                TextField("Custom duration", text: Binding(
                    get: { model.customMinutes },
                    set: { v in
                        model.customMinutes = v
                        if let n = Int(v), n > 0 { model.targetDuration = n * 60 }
                    }))
                    .keyboardType(.numberPad)
                    .font(.inter(18, .bold))
                    .foregroundStyle(model.customMinutes.isEmpty ? Color.warm700 : .white)
                Text("MIN").font(.inter(14, .bold)).tracking(1.2)
                    .foregroundStyle(model.customMinutes.isEmpty ? Color.warm400 : Color.white.opacity(0.5))
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 16)
                .fill(model.customMinutes.isEmpty ? Color.white : Color.black))
            .overlay(RoundedRectangle(cornerRadius: 16)
                .stroke(model.customMinutes.isEmpty ? Color.warm200 : Color.black, lineWidth: 1))
        }
    }
}

/// Conditional shadow-overlay helper for selected cards.
struct AnyViewModifierShadowOverlay: ViewModifier {
    var off: Bool = false
    func body(content: Content) -> some View {
        off ? AnyView(content) : AnyView(content.shadowOverlay())
    }
}

// MARK: - Duration picker (random mode) + mood grid

struct DurationPicker: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FieldLabel(icon: "clock", text: "How long?")
            DurationButtons(model: model)

            InlineToggleRow(isOn: $model.moodEnabled, icon: "hearts", label: "Feeling a certain way?")
            if model.moodEnabled {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(MOODS) { m in
                        let active = model.selectedMood == m.id
                        Button { model.selectedMood = m.id } label: {
                            HStack(spacing: 8) {
                                Text(m.emoji).font(.system(size: 16))
                                Text(m.label).font(.inter(14, .bold)).lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(active ? .white : Color.warm500)
                            .padding(.vertical, 12).padding(.horizontal, 16)
                            .background(RoundedRectangle(cornerRadius: 16)
                                .fill(active ? Color.black : Color.white))
                            .overlay(RoundedRectangle(cornerRadius: 16)
                                .stroke(active ? Color.black : Color.warm200, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 16)
                .transition(.reveal)
            }
        }
        .animation(anim(.easeOut(duration: 0.25)), value: model.moodEnabled)
    }
}

// MARK: - Surah picker (surah mode) + timer + memorization

struct SurahPicker: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FieldLabel(icon: "chevron-right", text: "Which surah?")
            StyledDropdown(selection: $model.selectedSurah,
                           options: chapters.map { ($0.id, "\($0.id). \($0.nameSimple) (\($0.nameArabic))") })

            InlineToggleRow(isOn: $model.surahTimerEnabled, icon: "clock", label: "Add timer")
            if model.surahTimerEnabled {
                DurationButtons(model: model).padding(.top, 16).transition(.reveal)
            }

            InlineToggleRow(isOn: $model.memorizationEnabled, icon: "hearts", label: "Memorization mode")
            if model.memorizationEnabled {
                MemorizationBlock(model: model).padding(.top, 16).transition(.reveal)
            }
        }
        .animation(anim(.easeOut(duration: 0.25)), value: model.surahTimerEnabled)
        .animation(anim(.easeOut(duration: 0.25)), value: model.memorizationEnabled)
    }
}

struct MemorizationBlock: View {
    @Bindable var model: AppModel
    private var maxV: Int { model.versesCount(model.selectedSurah) }
    private func clamp(_ n: Int) -> Int { min(max(1, n), maxV) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                verseBox(title: "Start verse", value: Binding(
                    get: { model.memStartVerse },
                    set: { v in
                        let c = clamp(v); model.memStartVerse = c
                        if c > model.memEndVerse { model.memEndVerse = c }
                    }))
                verseBox(title: "End verse", value: Binding(
                    get: { model.memEndVerse },
                    set: { model.memEndVerse = clamp($0) }))
            }
            Text("Loops or stops at verse \(model.memEndVerse) based on the toggle below.")
                .font(.inter(11)).foregroundStyle(Color.warm400).lineSpacing(2)
            Button { model.memRepeat.toggle() } label: {
                HStack(spacing: 12) {
                    PillToggle(isOn: $model.memRepeat)
                    Text("Play on repeat").font(.mono(12)).tracking(1.2)
                }
                .foregroundStyle(Color.warm400)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
        }
    }

    private func verseBox(title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased()).font(.mono(10)).tracking(1.2).foregroundStyle(Color.warm400)
            TextField("", value: value, format: .number)
                .keyboardType(.numberPad)
                .font(.inter(18, .bold))
                .foregroundStyle(Color.warm700)
            Text("Max: \(maxV)").font(.inter(10)).foregroundStyle(Color.warm400)
        }
        .padding(.horizontal, 20).padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.warm200, lineWidth: 1))
    }
}

// MARK: - Reciter picker

struct ReciterPicker: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            FieldLabel(icon: "globe", text: "Who recites?")
            StyledDropdown(selection: $model.reciterId,
                           options: RECITERS.map { ($0.id, $0.name) })
        }
    }
}

// MARK: - Inline toggle row (small pill + mono label)

struct InlineToggleRow: View {
    @Binding var isOn: Bool
    let icon: String
    let label: String
    var body: some View {
        Button { isOn.toggle() } label: {
            HStack(spacing: 12) {
                PillToggle(isOn: $isOn)
                HStack(spacing: 8) {
                    Bi(icon, size: 12)
                    Text(label.uppercased()).font(.mono(12)).tracking(1.2)
                }
            }
            .foregroundStyle(Color.warm400)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
    }
}

// MARK: - Banners

struct ResumeBanner: View {
    let ls: LastSession
    let onResume: () -> Void
    let onDismiss: () -> Void
    var body: some View {
        HStack(spacing: 16) {
            HStack(spacing: 12) {
                Circle().fill(Color.gold).frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text("PICK UP WHERE YOU LEFT OFF")
                        .font(.mono(10)).tracking(1.2).foregroundStyle(Color.warm400)
                    Text("Surah \(ls.surahName) • Verse \(ls.verseKey)")
                        .font(.inter(14, .bold)).foregroundStyle(Color.warm900).lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Button(action: onDismiss) { Bi("x-lg", size: 12).foregroundStyle(Color.warm400) }
                .buttonStyle(.plain)
            Button(action: onResume) {
                Text("RESUME").font(.inter(12, .bold)).tracking(1.2).foregroundStyle(.white)
                    .padding(.horizontal, 16).padding(.vertical, 8)
                    .background(Capsule().fill(Color.black))
            }
            .pressable()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.warm200, lineWidth: 1))
        .shadowCard()
    }
}

struct ReminderBanner: View {
    let time: String
    let onDismiss: () -> Void
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("TIME FOR YOUR DAILY LISTEN")
                    .font(.mono(10)).tracking(1.2).foregroundStyle(Color.warm700)
                Text("Set for \(time)").font(.inter(14, .bold)).foregroundStyle(Color.warm900)
            }
            Spacer()
            Button(action: onDismiss) { Bi("x-lg", size: 12).foregroundStyle(Color.warm700) }
                .buttonStyle(.plain)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.goldSoft))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.gold, lineWidth: 1))
        .shadowCard()
    }
}
