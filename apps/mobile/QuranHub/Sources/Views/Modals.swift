import SwiftUI

// MARK: - Modal container (backdrop fade 0.2 + panel slide y20 0.2 easeOut)

struct ModalContainer<Content: View>: View {
    let onClose: () -> Void
    @ViewBuilder var content: Content
    @State private var shown = false

    var body: some View {
        ZStack {
            Color.black.opacity(shown ? 0.5 : 0)
                .ignoresSafeArea()
                .onTapGesture(perform: dismiss)
            content
                .frame(maxWidth: 448)
                .background(RoundedRectangle(cornerRadius: 24).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.warm200, lineWidth: 1))
                .shadowOverlay()
                .padding(24)
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 20)
        }
        .onAppear { withAnimation(anim(.easeOut(duration: 0.2))) { shown = true } }
    }

    private func dismiss() {
        withAnimation(anim(.easeOut(duration: 0.2))) { shown = false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { onClose() }
    }
}

struct ModalHeader: View {
    let title: String
    var subtitle: String? = nil
    let onClose: () -> Void
    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.resolide(24)).tracking(-0.6).foregroundStyle(Color.warm900)
                if let s = subtitle {
                    Text(s.uppercased()).font(.mono(12)).tracking(1.2).foregroundStyle(Color.warm400)
                }
            }
            Spacer()
            Button(action: onClose) {
                Bi("x-lg", size: 14).foregroundStyle(Color.warm500)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(Color.warm200, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Settings

struct SettingsSheet: View {
    @Bindable var model: AppModel
    let reminders: RemindersManager

    private var reminderDate: Binding<Date> {
        Binding(
            get: {
                let p = model.reminderTime.split(separator: ":").compactMap { Int($0) }
                return Calendar.current.date(bySettingHour: p.first ?? 7, minute: p.count > 1 ? p[1] : 0,
                                             second: 0, of: Date()) ?? Date()
            },
            set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                model.reminderTime = String(format: "%02d:%02d", c.hour ?? 7, c.minute ?? 0)
                reminders.sync()
            })
    }

    var body: some View {
        ModalContainer(onClose: { model.showSettings = false }) {
            VStack(spacing: 0) {
                ModalHeader(title: "Settings") { model.showSettings = false }
                    .padding(.horizontal, 32).padding(.top, 32).padding(.bottom, 16)

                ScrollView {
                    VStack(spacing: 20) {
                        Button {
                            model.showSettings = false
                            model.showBookmarks = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Saved verses").font(.inter(16, .bold)).foregroundStyle(Color.warm900)
                                    Text(model.savedVerses.isEmpty
                                         ? "Tap the heart on any verse to save it."
                                         : "\(model.savedVerses.count) saved")
                                        .font(.inter(14)).foregroundStyle(Color.warm400)
                                }
                                Spacer()
                                Bi("chevron-right", size: 14).foregroundStyle(Color.warm400)
                            }
                        }
                        .buttonStyle(.plain)

                        divider
                        // Daily reminder
                        VStack(spacing: 12) {
                            ToggleRowLarge(title: "Daily reminder",
                                           desc: "Get a notification at your chosen time if you haven't listened yet.",
                                           isOn: $model.reminderEnabled) { enabled in
                                if enabled { Task { await reminders.requestAuthorizationIfNeeded(); reminders.sync() } }
                                else { reminders.sync() }
                            }
                            if model.reminderEnabled {
                                HStack(spacing: 12) {
                                    Text("TIME").font(.mono(12)).tracking(1.2).foregroundStyle(Color.warm400)
                                    DatePicker("", selection: reminderDate, displayedComponents: .hourAndMinute)
                                        .labelsHidden()
                                    Spacer()
                                }
                            }
                        }
                        divider
                        ToggleRowLarge(title: "Highlight word being recited",
                                       desc: "Color the active Arabic word as the reciter says it.",
                                       isOn: $model.karaokeEnabled)
                        if model.karaokeEnabled {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("HIGHLIGHT COLOR").font(.mono(12)).tracking(1.2)
                                    .foregroundStyle(Color.warm400)
                                Segmented(items: [SegItem(id: "gold", label: "Gold", dot: .goldDeep),
                                                  SegItem(id: "green", label: "Green", dot: .karaokeGreen)],
                                          selection: $model.karaokeColor,
                                          corner: 8, outerCorner: 12, vPad: 8)
                            }
                        }
                        divider
                        ToggleRowLarge(title: "Tap word for translation",
                                       desc: "Show a tooltip with the word's meaning on hover or tap.",
                                       isOn: $model.wordTooltipsEnabled)
                        divider
                        ToggleRowLarge(title: "Auto-stop on timer end",
                                       desc: "Stop playback when the timer runs out. Off lets the surah finish.",
                                       isOn: $model.autoStopTimer)
                        divider
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Language display").font(.inter(16, .bold)).foregroundStyle(Color.warm900)
                                Text("What to show while you listen.")
                                    .font(.inter(14)).foregroundStyle(Color.warm400)
                            }
                            Segmented(items: [SegItem(id: "arabic", label: "Arabic"),
                                              SegItem(id: "english", label: "English"),
                                              SegItem(id: "both", label: "Both")],
                                      selection: $model.languageMode,
                                      corner: 8, outerCorner: 12, vPad: 8)
                        }
                        if model.languageMode == "both" {
                            VStack(alignment: .leading, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Focus on new verse").font(.inter(16, .bold))
                                        .foregroundStyle(Color.warm900)
                                    Text("Which language gets emphasized when a verse arrives.")
                                        .font(.inter(14)).foregroundStyle(Color.warm400)
                                }
                                Segmented(items: [SegItem(id: "arabic", label: "Arabic"),
                                                  SegItem(id: "english", label: "English")],
                                          selection: $model.autoFocus,
                                          corner: 8, outerCorner: 12, vPad: 8)
                            }
                        }
                    }
                    .padding(.horizontal, 32).padding(.bottom, 32)
                }
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.85)
        }
    }

    private var divider: some View { Rectangle().fill(Color.warm100).frame(height: 1) }
}

struct ToggleRowLarge: View {
    let title: String
    let desc: String
    @Binding var isOn: Bool
    var onChange: ((Bool) -> Void)? = nil
    var body: some View {
        Button {
            isOn.toggle()
            onChange?(isOn)
        } label: {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.inter(16, .bold)).foregroundStyle(Color.warm900)
                    Text(desc).font(.inter(14)).foregroundStyle(Color.warm400)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                PillToggle(isOn: $isOn, large: true).padding(.top, 4)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bookmarks

struct BookmarksSheet: View {
    @Bindable var model: AppModel
    var body: some View {
        ModalContainer(onClose: { model.showBookmarks = false }) {
            VStack(spacing: 0) {
                ModalHeader(title: "Saved verses",
                            subtitle: "\(model.savedVerses.count) \(model.savedVerses.count == 1 ? "verse" : "verses")") {
                    model.showBookmarks = false
                }
                .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 16)

                ScrollView {
                    if model.savedVerses.isEmpty {
                        Text("Tap the heart on any verse during playback to save it.")
                            .font(.inter(14)).foregroundStyle(Color.warm400)
                            .multilineTextAlignment(.center).lineSpacing(4)
                            .padding(.vertical, 48).padding(.horizontal, 24)
                    } else {
                        VStack(spacing: 12) {
                            ForEach(model.savedVerses) { v in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack(alignment: .top) {
                                        Text("\(v.surahName) • \(v.verseKey)".uppercased())
                                            .font(.mono(10)).tracking(1.2).foregroundStyle(Color.warm400)
                                        Spacer()
                                        Button {
                                            model.savedVerses.removeAll { $0.verseKey == v.verseKey }
                                        } label: {
                                            Bi("x-lg", size: 10).foregroundStyle(Color.warm400)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Remove verse \(v.verseKey)")
                                    }
                                    Text(v.text)
                                        .font(.playfair(18))
                                        .foregroundStyle(Color.warm900)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                        .environment(\.layoutDirection, .rightToLeft)
                                    if !v.translation.isEmpty {
                                        Text(v.translation)
                                            .font(.inter(14)).italic()
                                            .foregroundStyle(Color.warm500).lineSpacing(4)
                                    }
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Color.warm50))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.warm200, lineWidth: 1))
                            }
                        }
                        .padding(.horizontal, 24).padding(.bottom, 24)
                    }
                }
            }
            .frame(maxHeight: UIScreen.main.bounds.height * 0.8)
        }
    }
}
