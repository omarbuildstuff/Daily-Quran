import SwiftUI

struct PlayingView: View {
    @Bindable var model: AppModel
    let engine: AudioEngine

    var body: some View {
        VStack(spacing: 64) {
            if model.loading && model.currentAyah == nil {
                LoaderView(model: model)
            } else if let ayah = model.currentAyah {
                VStack(spacing: 64) {
                    VerseBlock(model: model, ayah: ayah)
                }
                .padding(.bottom, 160)
            }
        }
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture { model.hoveredWordPos = nil }      // dismiss tooltip
        .onChange(of: model.currentAyah?.key) { _, _ in
            // handleVerseEntered — scroll to focused language after enter (~0.3s)
            guard model.languageMode == "both" else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.32) {
                model.scrollTo?(model.autoFocus == "english" ? "english" : "arabic")
            }
        }
    }
}

// MARK: - Loader (3 staggered gold dots)

struct LoaderView: View {
    @Bindable var model: AppModel
    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { i in
                    LoaderDot(delay: Double(i) * 0.2)
                }
            }
            VStack(spacing: 8) {
                Text("LOADING RECITATION")
                    .font(.mono(10)).tracking(3).foregroundStyle(Color.warm400)
                Text(model.mode == "surah"
                     ? (chapter(model.selectedSurah)?.nameSimple ?? "Random surah")
                     : "Random surah")
                    .font(.resolide(24)).tracking(-0.6).foregroundStyle(Color.warm900)
                Text(RECITERS.first { $0.id == model.reciterId }?.name ?? "")
                    .font(.inter(14)).foregroundStyle(Color.warm500)
            }
        }
        .padding(.vertical, 48)
    }
}

struct LoaderDot: View {
    let delay: Double
    @State private var on = false
    var body: some View {
        Circle().fill(Color.gold).frame(width: 8, height: 8)
            .scaleEffect(on ? 1 : 0.6).opacity(on ? 1 : 0.4)
            .onAppear {
                guard !UIAccessibility.isReduceMotionEnabled else { return }
                withAnimation(.easeInOut(duration: 0.56).repeatForever(autoreverses: true).delay(delay)) {
                    on = true
                }
            }
    }
}

// MARK: - Verse block (header + Arabic + English), keyed transition

struct VerseBlock: View {
    @Bindable var model: AppModel
    let ayah: CurrentAyah

    var body: some View {
        VStack(spacing: 24) {
            HStack(spacing: 16) {
                Rectangle().fill(Color.goldSoft).frame(width: 32, height: 1)
                Text("SURAH \(ayah.surahName) • VERSE \(ayah.key)")
                    .font(.mono(10)).tracking(3).foregroundStyle(Color.warm400)
                    .multilineTextAlignment(.center)
                Rectangle().fill(Color.goldSoft).frame(width: 32, height: 1)
            }

            if model.languageMode != "english" {
                ArabicVerse(model: model, ayah: ayah)
                    .id("arabic")
            }
            if model.languageMode != "arabic" {
                Text(ayah.translation)
                    .font(.thmanyah(20))
                    .foregroundStyle(Color.warm500)
                    .lineSpacing(8)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 672)
                    .id("english")
            }
        }
        .id(ayah.key)
        .transition(.asymmetric(
            insertion: .opacity.combined(with: .offset(y: 16)),
            removal: .opacity.combined(with: .offset(y: -16))))
        .animation(anim(.easeOut(duration: 0.3)), value: ayah.key)
    }
}

// MARK: - Arabic verse with karaoke highlight + word tooltips

struct ArabicVerse: View {
    @Bindable var model: AppModel
    let ayah: CurrentAyah

    private var words: [Word] {
        if !ayah.words.isEmpty { return ayah.words }
        return ayah.text.split(separator: " ").enumerated().map {
            Word(position: $0.offset + 1, text: String($0.element), translation: "", transliteration: "")
        }
    }
    private var karaokeColor: Color { model.karaokeColor == "green" ? .karaokeGreen : .goldDeep }

    var body: some View {
        FlowLayout(spacing: 4, lineSpacing: 14, alignment: .center) {
            ForEach(words) { w in
                let active = model.karaokeEnabled && model.currentWordIdx == w.position
                let hovered = model.wordTooltipsEnabled && model.hoveredWordPos == w.position
                Text(w.text)
                    .font(.thmanyah(36))
                    .foregroundStyle(active ? .white : Color.warm900)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 6)
                        .fill(active ? karaokeColor : .clear))
                    .animation(anim(.easeInOut(duration: 0.15)), value: active)
                    .overlay(alignment: .top) {
                        if hovered, !w.translation.isEmpty {
                            WordTooltip(word: w).offset(y: -8).fixedSize()
                                .allowsHitTesting(false)
                        }
                    }
                    .onTapGesture {
                        guard model.wordTooltipsEnabled else { return }
                        model.hoveredWordPos = (model.hoveredWordPos == w.position) ? nil : w.position
                    }
            }
        }
        .environment(\.layoutDirection, .rightToLeft)
        .frame(maxWidth: .infinity)
    }
}

struct WordTooltip: View {
    let word: Word
    var body: some View {
        VStack(spacing: 2) {
            Text(word.translation).font(.thmanyah(14)).foregroundStyle(.white)
            if !word.transliteration.isEmpty {
                Text(word.transliteration).font(.inter(10)).italic()
                    .foregroundStyle(Color.warm300)
            }
        }
        .environment(\.layoutDirection, .leftToRight)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.warm900))
        .shadowOverlay()
        .offset(y: -28)
    }
}

// MARK: - Flow layout (wrapping; RTL via environment)

struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 14
    var alignment: HorizontalAlignment = .center

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxW = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 { x = 0; y += rowH + lineSpacing; rowH = 0 }
            x += s.width + spacing
            rowH = max(rowH, s.height)
        }
        return CGSize(width: maxW == .infinity ? x : maxW, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let maxW = bounds.width
        var rows: [[(LayoutSubview, CGSize)]] = [[]]
        var x: CGFloat = 0
        for v in subviews {
            let s = v.sizeThatFits(.unspecified)
            if x + s.width > maxW, x > 0 { rows.append([]); x = 0 }
            rows[rows.count - 1].append((v, s)); x += s.width + spacing
        }
        var y = bounds.minY
        for row in rows {
            let rowW = row.reduce(0) { $0 + $1.1.width } + spacing * CGFloat(max(0, row.count - 1))
            let rowH = row.map(\.1.height).max() ?? 0
            var cx: CGFloat
            switch alignment {
            case .leading: cx = bounds.minX
            case .trailing: cx = bounds.maxX - rowW
            default: cx = bounds.minX + (maxW - rowW) / 2
            }
            for (v, s) in row {
                v.place(at: CGPoint(x: cx, y: y + (rowH - s.height) / 2),
                        proposal: ProposedViewSize(s))
                cx += s.width + spacing
            }
            y += rowH + lineSpacing
        }
    }
}

// MARK: - Playback dock (fixed bottom) + gradient fade

struct PlaybackDock: View {
    @Bindable var model: AppModel
    let engine: AudioEngine

    private var surahMode: Bool {
        model.mode == "surah" && !model.surahTimerEnabled && model.currentAyah != nil
    }
    private var versesCount: Int { model.versesCount(model.selectedSurah) }
    private var ratio: Double {
        if surahMode, let a = model.currentAyah {
            let n = Double(a.key.split(separator: ":").last.map(String.init).flatMap(Int.init) ?? 1)
            return min(1, n / Double(max(1, versesCount)))
        }
        return min(1, Double(model.elapsedTime) / Double(max(1, model.targetDuration)))
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            ZStack(alignment: .bottom) {
                LinearGradient(
                    stops: [
                        .init(color: Color.appBg.opacity(0), location: 0),
                        .init(color: Color.appBg.opacity(0.7), location: 0.4),
                        .init(color: Color.appBg, location: 0.7),
                        .init(color: Color.appBg, location: 1)],
                    startPoint: .top, endPoint: .bottom)
                    .frame(height: 192)
                    .allowsHitTesting(false)

                VStack(spacing: 16) {
                    HStack(spacing: 16) {
                        Button { engine.setPlaying(!model.isPlaying) } label: {
                            Bi(model.isPlaying ? "pause-fill" : "play-fill", size: 24)
                                .foregroundStyle(.white)
                                .frame(width: 56, height: 56)
                                .background(RoundedRectangle(cornerRadius: 16).fill(Color.black))
                        }
                        .pressable()
                        .accessibilityLabel(model.isPlaying ? "Pause" : "Play")

                        if model.currentAyah != nil {
                            Button { engine.toggleSaveCurrentVerse() } label: {
                                Bi("heart-fill", size: 22)
                                    .foregroundStyle(model.isCurrentVerseSaved ? Color.heartRed : Color.heartIdle)
                                    .frame(width: 40, height: 40)
                            }
                            .pressable(0.9)
                            .accessibilityLabel(model.isCurrentVerseSaved ? "Unsave verse" : "Save verse")
                        }

                        Spacer()

                        Group {
                            if surahMode, let a = model.currentAyah {
                                VStack(alignment: .trailing, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(a.key.split(separator: ":").last.map(String.init) ?? "")
                                        Text("/").foregroundStyle(Color.warm400)
                                        Text("\(versesCount)")
                                    }
                                    Text("VERSE").font(.mono(10)).tracking(1.2)
                                        .foregroundStyle(Color.warm400)
                                }
                            } else {
                                HStack(spacing: 4) {
                                    Text(formatTime(model.elapsedTime))
                                    Text("/").foregroundStyle(Color.warm400)
                                    Text(formatTime(model.targetDuration))
                                }
                            }
                        }
                        .font(.mono(18, .bold))
                        .foregroundStyle(Color.warm900)
                    }
                    .padding(.horizontal, 24).padding(.vertical, 20)
                    .background(RoundedRectangle(cornerRadius: 24).fill(Color.white.opacity(0.95)))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.warm200, lineWidth: 1))
                    .shadowOverlay()

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.warm100).frame(height: 4)
                            Capsule()
                                .fill(LinearGradient(colors: [.gold, .goldDeep],
                                                     startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(0, geo.size.width * ratio), height: 4)
                                .animation(.linear(duration: 1), value: ratio)
                        }
                        .frame(height: 12)
                        .contentShape(Rectangle())
                        .onTapGesture { loc in
                            guard surahMode else { return }
                            engine.scrubToRatio(min(1, max(0, loc.x / geo.size.width)))
                        }
                    }
                    .frame(height: 12)
                    .padding(.horizontal, 32)
                }
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.bottom, 48)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}
