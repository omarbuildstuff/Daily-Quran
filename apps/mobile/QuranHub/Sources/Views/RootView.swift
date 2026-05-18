import SwiftUI

struct RootView: View {
    @State private var coord = Coordinator()
    @Environment(\.scenePhase) private var scenePhase

    private var model: AppModel { coord.model }

    var body: some View {
        let model = coord.model
        let engine = coord.engine
        let reminders = coord.reminders

        ZStack {
            Color.appBg.ignoresSafeArea()

            ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 0).id("top")
                    header(engine)
                        .padding(.bottom, 48)

                    Group {
                        switch model.view {
                        case .setup:
                            SetupView(model: model, engine: engine)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .offset(y: 8)),
                                    removal: .opacity.combined(with: .offset(y: -8))))
                        case .playing:
                            PlayingView(model: model, engine: engine)
                                .transition(.opacity)
                        case .finished:
                            FinishedView(model: model, engine: engine)
                                .transition(.asymmetric(
                                    insertion: .opacity.combined(with: .offset(y: 8)),
                                    removal: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: 768, alignment: .center)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, model.view == .playing ? 24 : 80)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                model.scrollTo = { id in
                    withAnimation(anim(.easeInOut(duration: 0.4))) { proxy.scrollTo(id, anchor: .center) }
                }
            }
            }

            // Playing dock + fade are fixed overlays (web: position fixed).
            if model.view == .playing, model.currentAyah != nil || !model.loading {
                PlaybackDock(model: model, engine: engine)
            }

            // Error toast (fixed top-24)
            if let err = model.errorMessage {
                VStack {
                    ErrorToast(message: err) { model.errorMessage = nil }
                        .padding(.top, 24)
                    Spacer()
                }
                .transition(.opacity)
            }

            // Settings + bookmarks modals (custom — exact backdrop/panel motion)
            if model.showSettings {
                SettingsSheet(model: model, reminders: reminders)
                    .zIndex(90)
            }
            if model.showBookmarks {
                BookmarksSheet(model: model)
                    .zIndex(90)
            }
        }
        .animation(anim(.easeOut(duration: 0.3)), value: model.view)
        .animation(anim(.easeOut(duration: 0.2)), value: model.errorMessage)
        .environment(model)
        .task {
            DebugScreens.apply(model)
            if ProcessInfo.processInfo.environment["QH_SCREEN"] == "autostart" {
                model.mode = "random"; model.moodEnabled = false
                engine.startPlayback()
            }
            // Resume prompt — recent (<24h) bookmark.
            if let ls = model.lastSession,
               Date().timeIntervalSince1970 * 1000 - ls.savedAt < 24 * 60 * 60 * 1000 {
                model.showResumePrompt = true
            }
            if model.reminderEnabled { await reminders.requestAuthorizationIfNeeded() }
            reminders.sync()
            reminders.startBannerCheck()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { reminders.sync(); reminders.startBannerCheck() }
            else if phase == .background { reminders.sync() }
        }
    }

    // MARK: Header

    @ViewBuilder
    private func header(_ engine: AudioEngine) -> some View {
        HStack {
            HStack(spacing: 12) {
                Image("QuranHubLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 48)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Quran Hub")
                        .font(.inter(18, .bold))
                        .tracking(-0.45)
                        .foregroundStyle(Color.warm900)
                    Text("DAILY LISTENING")
                        .font(.inter(10))
                        .tracking(2)
                        .foregroundStyle(Color.warm400)
                }
            }
            Spacer()
            if model.view != .setup {
                Button { engine.handleEndSession() } label: {
                    Text("END SESSION")
                        .font(.inter(12, .bold))
                        .tracking(1.2)
                        .foregroundStyle(Color.warm900)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color.white.opacity(0.8)))
                        .overlay(Capsule().stroke(Color.warm200, lineWidth: 1))
                }
                .pressable()
            } else {
                Button { model.showSettings = true } label: {
                    Bi("gear-wide", size: 16)
                        .foregroundStyle(Color.warm500)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white.opacity(0.8)))
                        .overlay(Circle().stroke(Color.warm200, lineWidth: 1))
                }
                .pressable()
                .accessibilityLabel("Settings")
            }
        }
    }
}

// MARK: - Error toast

struct ErrorToast: View {
    let message: String
    let onClose: () -> Void
    var body: some View {
        HStack(spacing: 12) {
            Circle().fill(Color.red600).frame(width: 8, height: 8)
                .modifier(StatusPulse())
            Text(message).font(.inter(14, .bold)).foregroundStyle(Color.red600)
            Button(action: onClose) { Text("x").foregroundStyle(Color.red600) }
        }
        .padding(.horizontal, 24).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.red50))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red100, lineWidth: 1))
        .shadowOverlay()
    }
}

/// status-pulse keyframes (opacity 1 → .5 → 1, 2s).
struct StatusPulse: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content.opacity(on ? 0.5 : 1)
            .onAppear {
                guard !UIAccessibility.isReduceMotionEnabled else { return }
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { on = true }
            }
    }
}
