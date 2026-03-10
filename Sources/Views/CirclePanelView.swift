import SwiftUI

struct CirclePanelView: View {
    let model: AppModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace

    private var activeFocus: SegmentFocus? { model.activeFocus }
    private var activeSlice: CircleSlice? { model.activeSlice }
    private var theme: PanelTheme { model.theme }

    var body: some View {
        GeometryReader { geometry in
            let metrics = PanelMetrics(size: geometry.size)

            ZStack {
                PanelBackground(theme: theme)

                HStack(alignment: .top, spacing: metrics.columnSpacing) {
                    leftColumn(metrics: metrics)
                    detailColumn(metrics: metrics)
                }
                .padding(metrics.outerPadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
    }

    @ViewBuilder
    private func leftColumn(metrics: PanelMetrics) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            topBar

            VStack(alignment: .leading, spacing: 22) {
                insightStrip

                CircleWheelView(
                    model: model,
                    metrics: metrics,
                    theme: theme,
                    reduceMotion: reduceMotion
                )
                .frame(width: metrics.wheelFrameSize, height: metrics.wheelFrameSize)
                .frame(maxWidth: .infinity)

                footerSummary
            }
            .padding(metrics.cardPadding)
            .panelCardStyle(cornerRadius: 34, tint: .white.opacity(0.035))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private func detailColumn(metrics: PanelMetrics) -> some View {
        DetailPanelView(
            model: model,
            activeSlice: activeSlice,
            activeFocus: activeFocus,
            theme: theme,
            width: metrics.detailWidth,
            reduceMotion: reduceMotion,
            selectionNamespace: selectionNamespace
        )
        .frame(width: metrics.detailWidth)
        .frame(maxHeight: .infinity)
    }

    private var topBar: some View {
        HStack(alignment: .top, spacing: 18) {
            HStack(alignment: .center, spacing: 16) {
                BrandMark(style: .logo)
                    .frame(width: 58, height: 58)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Tonica")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)

                    Text("A fast harmony compass for key choice, motion, and progressions.")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.66))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 16)

            ShortcutBadge(text: model.shortcutDescription)
        }
    }

    private var insightStrip: some View {
        HStack(spacing: 12) {
            RevealStateBadge(title: revealStateTitle, detail: revealStateDetail, theme: theme)

            Spacer(minLength: 12)

            StatusPill(
                title: activeFocus?.ring.shortLabel ?? "Focus",
                value: activeSlice?.label(for: activeFocus?.ring ?? .major) ?? "Ready",
                emphasis: activeSlice != nil ? theme.highlightColor : .white.opacity(0.16)
            )

            if model.selectedFocus != nil {
                Button("Clear Pin") {
                    withAnimation(panelAnimation) {
                        model.clearSelection()
                    }
                }
                .buttonStyle(PressableCapsuleButtonStyle())
            }
        }
    }

    @ViewBuilder
    private var footerSummary: some View {
        Group {
            if let activeFocus, let activeSlice {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(activeSlice.label(for: activeFocus.ring))
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(activeFocus.ring.title.uppercased())
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.48))
                            .tracking(1.4)
                    }

                    Text(focusSummary)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.64))

                    LinearMeter(theme: theme)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Start on the wheel")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("Hover for a quick read or click once to pin a key and compare nearby options.")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.62))
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(panelAnimation, value: model.activeFocus)
        .animation(panelAnimation, value: model.selectedFocus)
    }

    private var revealStateTitle: String {
        if model.hoveredFocus != nil { return "Preview" }
        if model.selectedFocus != nil { return "Pinned" }
        return "Ready"
    }

    private var revealStateDetail: String {
        if let hoveredFocus = model.hoveredFocus {
            return model.label(for: hoveredFocus)
        }
        if let selectedFocus = model.selectedFocus {
            return model.label(for: selectedFocus)
        }
        return "Hover or click a key"
    }

    private var focusSummary: String {
        guard let activeFocus else { return "" }

        if model.hoveredFocus == activeFocus {
            return "Quick preview. Click to lock it in and keep the theory panel stable."
        }

        return "Pinned for comparison. Walk clockwise for tension, counter-clockwise for release."
    }

    private var panelAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .snappy(duration: 0.26, extraBounce: 0.02)
    }
}

private struct CircleWheelView: View {
    let model: AppModel
    let metrics: PanelMetrics
    let theme: PanelTheme
    let reduceMotion: Bool

    private let majorBand = BandLayout(inner: 0.56, outer: 0.84, font: 19, widthFactor: 0.15, labelPosition: 0.53)
    private let minorBand = BandLayout(inner: 0.39, outer: 0.56, font: 14, widthFactor: 0.13, labelPosition: 0.52)
    private let diminishedBand = BandLayout(inner: 0.25, outer: 0.39, font: 11, widthFactor: 0.11, labelPosition: 0.52)

    var body: some View {
        GeometryReader { geometry in
            let canvasSize = min(geometry.size.width, geometry.size.height)

            ZStack {
                wheelAura(size: canvasSize)

                ForEach(Array(model.slices.enumerated()), id: \.offset) { index, slice in
                    bandSegment(slice: slice, index: index, ring: .major, band: majorBand, size: canvasSize)
                    bandSegment(slice: slice, index: index, ring: .minor, band: minorBand, size: canvasSize)
                    bandSegment(slice: slice, index: index, ring: .diminished, band: diminishedBand, size: canvasSize)
                }

                centerHub(size: canvasSize)
            }
            .contentShape(Circle())
            .onContinuousHover(coordinateSpace: .local) { phase in
                switch phase {
                case .active(let location):
                    model.hoveredFocus = focus(at: location, size: canvasSize)
                case .ended:
                    model.hoveredFocus = nil
                }
            }
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        if let focus = focus(at: value.location, size: canvasSize) {
                            withAnimation(selectionAnimation) {
                                model.select(focus)
                            }
                        }
                    }
            )
        }
    }

    private func wheelAura(size: CGFloat) -> some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        theme.highlightColor.opacity(0.28),
                        theme.accentGlowColor.opacity(0.14),
                        .clear
                    ],
                    center: .center,
                    startRadius: size * 0.04,
                    endRadius: size * 0.54
                )
            )
            .blur(radius: 26)
            .padding(size * 0.02)
    }

    private func bandSegment(
        slice: CircleSlice,
        index: Int,
        ring: RingKind,
        band: BandLayout,
        size: CGFloat
    ) -> some View {
        let focus = SegmentFocus(index: index, ring: ring)
        let isActive = model.activeFocus == focus
        let isSelected = model.selectedFocus == focus

        return ZStack {
            RingSegmentShape(
                centerAngle: centerAngle(for: index),
                sweep: .degrees(28.0),
                innerRadiusRatio: band.inner,
                outerRadiusRatio: band.outer
            )
            .fill(fillColor(for: slice, ring: ring, isActive: isActive, isSelected: isSelected))
            .overlay {
                RingSegmentShape(
                    centerAngle: centerAngle(for: index),
                    sweep: .degrees(28.0),
                    innerRadiusRatio: band.inner,
                    outerRadiusRatio: band.outer
                )
                .strokeBorder(
                    isActive ? .white.opacity(0.92) : .white.opacity(isSelected ? 0.34 : 0.08),
                    lineWidth: isActive ? 2.2 : (isSelected ? 1.3 : 0.9)
                )
            }
            .scaleEffect(isActive ? 1.015 : 1)
            .shadow(color: shadowColor(isActive: isActive, slice: slice), radius: isActive ? 28 : 0, y: isActive ? 10 : 0)
            .animation(selectionAnimation, value: isActive)
            .animation(selectionAnimation, value: isSelected)

            ringLabel(
                text: slice.label(for: ring),
                angle: centerAngle(for: index),
                radius: (size / 2) * band.labelRadius,
                fontSize: band.font,
                width: size * band.widthFactor,
                canvasSize: size,
                brighten: isActive || isSelected
            )
        }
    }

    @ViewBuilder
    private func centerHub(size: CGFloat) -> some View {
        if let activeFocus = model.activeFocus, let activeSlice = model.activeSlice {
            VStack(spacing: 8) {
                Text(activeSlice.label(for: activeFocus.ring))
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())

                Text(activeFocus.ring.title.uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.48))
                    .tracking(1.8)

                Text(activeSlice.chordNotes(for: activeFocus.ring).joined(separator: "  "))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.76))
                    .multilineTextAlignment(.center)
            }
            .frame(width: size * 0.25, height: size * 0.25)
            .panelCardStyle(cornerRadius: size * 0.125, tint: .white.opacity(0.05))
            .overlay {
                Circle()
                    .strokeBorder(theme.highlightColor.opacity(0.32), lineWidth: 1.4)
                    .padding(size * 0.02)
            }
            .shadow(color: .black.opacity(0.30), radius: 30, y: 18)
            .transition(.scale(scale: 0.96).combined(with: .opacity))
        } else {
            VStack(spacing: 6) {
                Text("Choose")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("a key")
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.48))
                    .tracking(1.6)
                    .textCase(.uppercase)
            }
            .frame(width: size * 0.23, height: size * 0.23)
            .panelCardStyle(cornerRadius: size * 0.115, tint: .white.opacity(0.04))
            .overlay {
                Circle()
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                    .padding(size * 0.02)
            }
        }
    }

    private func ringLabel(
        text: String,
        angle: Angle,
        radius: CGFloat,
        fontSize: CGFloat,
        width: CGFloat,
        canvasSize: CGFloat,
        brighten: Bool
    ) -> some View {
        Text(text)
            .font(.system(size: fontSize, weight: .bold, design: .rounded))
            .foregroundStyle(brighten ? .white : .white.opacity(0.84))
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(width: width)
            .position(point(for: angle, radius: radius, canvasSize: canvasSize))
            .shadow(color: .black.opacity(0.34), radius: 4, y: 1)
            .allowsHitTesting(false)
            .animation(selectionAnimation, value: brighten)
    }

    private func focus(at location: CGPoint, size: CGFloat) -> SegmentFocus? {
        let radius = size / 2
        let center = CGPoint(x: radius, y: radius)
        let dx = location.x - center.x
        let dy = location.y - center.y
        let normalizedRadius = hypot(dx, dy) / radius

        let ring: RingKind
        switch normalizedRadius {
        case majorBand.inner ... majorBand.outer:
            ring = .major
        case minorBand.inner ... minorBand.outer:
            ring = .minor
        case diminishedBand.inner ... diminishedBand.outer:
            ring = .diminished
        default:
            return nil
        }

        let rawDegrees = atan2(dy, dx) * 180 / .pi
        let shifted = (rawDegrees + 90 + 360).truncatingRemainder(dividingBy: 360)
        let index = Int((shifted + 15) / 30) % model.slices.count

        return SegmentFocus(index: index, ring: ring)
    }

    private func centerAngle(for index: Int) -> Angle {
        .degrees(Double(index) * 30 - 90)
    }

    private func point(for angle: Angle, radius: CGFloat, canvasSize: CGFloat) -> CGPoint {
        let center = CGPoint(x: canvasSize / 2, y: canvasSize / 2)
        return CGPoint(
            x: center.x + CGFloat(cos(angle.radians)) * radius,
            y: center.y + CGFloat(sin(angle.radians)) * radius
        )
    }

    private func fillColor(for slice: CircleSlice, ring: RingKind, isActive: Bool, isSelected: Bool) -> Color {
        let opacity: Double

        switch ring {
        case .major:
            opacity = isActive ? 1.0 : (isSelected ? 0.88 : 0.76)
        case .minor:
            opacity = isActive ? 0.72 : (isSelected ? 0.56 : 0.30)
        case .diminished:
            opacity = isActive ? 0.40 : (isSelected ? 0.28 : 0.12)
        }

        return slice.palette.opacity(opacity)
    }

    private func shadowColor(isActive: Bool, slice: CircleSlice) -> Color {
        isActive ? slice.palette.opacity(0.42) : .clear
    }

    private var selectionAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .smooth(duration: 0.20)
    }
}

private struct DetailPanelView: View {
    let model: AppModel
    let activeSlice: CircleSlice?
    let activeFocus: SegmentFocus?
    let theme: PanelTheme
    let width: CGFloat
    let reduceMotion: Bool
    let selectionNamespace: Namespace.ID

    var body: some View {
        Group {
            if let activeSlice, let activeFocus {
                ScrollView(.vertical) {
                    VStack(alignment: .leading, spacing: 18) {
                        heroSection(activeSlice: activeSlice, activeFocus: activeFocus)
                        revealSection(activeSlice: activeSlice, activeFocus: activeFocus)
                        harmonySection(activeSlice: activeSlice, activeFocus: activeFocus)
                        progressionsSection(activeSlice: activeSlice, activeFocus: activeFocus)
                        movementSection(activeSlice: activeSlice, activeFocus: activeFocus)
                    }
                    .padding(24)
                }
                .scrollIndicators(.hidden)
                .scrollBounceBehavior(.basedOnSize)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            } else {
                emptyState
                    .padding(24)
                    .transition(.opacity)
            }
        }
        .panelCardStyle(cornerRadius: 34, tint: .white.opacity(0.03))
        .shadow(color: .black.opacity(0.30), radius: 24, y: 14)
        .animation(panelAnimation, value: activeFocus)
        .animation(panelAnimation, value: model.selectedFocus)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("A cleaner way to think in keys")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text("Select a slice to surface the harmony map, useful progressions, and the strongest next moves around the circle.")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.62))
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 12) {
                UseCaseRow(title: "Lock a home key", detail: "Pin a slice to keep the panel stable while you compare functions.")
                UseCaseRow(title: "Move with intention", detail: "Clockwise adds pull. Counter-clockwise opens things up.")
                UseCaseRow(title: "Stay musical", detail: "The app surfaces the practical theory first, not everything at once.")
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func heroSection(activeSlice: CircleSlice, activeFocus: SegmentFocus) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(activeSlice.label(for: activeFocus.ring))
                        .font(.system(size: 38, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .matchedGeometryEffect(id: "hero-title", in: selectionNamespace)

                    Text(activeFocus.ring.title.uppercased())
                        .font(.system(size: 11, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                        .tracking(1.8)
                }

                Spacer(minLength: 16)

                StatusPill(
                    title: "Signature",
                    value: activeSlice.signature,
                    emphasis: theme.highlightColor
                )
            }

            Text(activeFocus.ring.subtitle)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.66))

            HStack(spacing: 10) {
                ForEach(RingKind.allCases) { ring in
                    FocusModeButton(
                        title: ring.shortLabel,
                        value: activeSlice.label(for: ring),
                        isSelected: activeFocus.ring == ring,
                        highlight: theme.highlightColor
                    ) {
                        withAnimation(panelAnimation) {
                            model.selectCurrentRing(ring, from: activeFocus)
                        }
                    }
                }
            }
        }
        .sectionCardStyle()
    }

    private func revealSection(activeSlice: CircleSlice, activeFocus: SegmentFocus) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "At a glance", accent: theme.highlightColor)

            HStack(spacing: 10) {
                MetaChip(title: "Major", value: activeSlice.majorLabel)
                MetaChip(title: "Minor", value: activeSlice.minorLabel)
                MetaChip(title: "Dim", value: activeSlice.diminishedLabel)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(scaleSectionTitle(for: activeFocus.ring))
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.46))
                    .tracking(1.2)
                    .textCase(.uppercase)

                ChipGrid(items: scaleNotes(for: activeSlice, ring: activeFocus.ring), highlight: theme.highlightColor)
            }

            ChordBlock(
                title: activeSlice.label(for: activeFocus.ring),
                notes: activeSlice.chordNotes(for: activeFocus.ring),
                accent: theme.highlightColor
            )
        }
        .sectionCardStyle()
    }

    private func harmonySection(activeSlice: CircleSlice, activeFocus: SegmentFocus) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Harmony map", accent: theme.highlightColor)

            RomanChordGrid(
                numerals: romanNumerals(for: activeSlice, ring: activeFocus.ring),
                chords: diatonicChords(for: activeSlice, ring: activeFocus.ring),
                accent: theme.highlightColor
            )
        }
        .sectionCardStyle()
    }

    private func progressionsSection(activeSlice: CircleSlice, activeFocus: SegmentFocus) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Useful progressions", accent: theme.highlightColor)

            ForEach(progressions(for: activeSlice, activeFocus: activeFocus)) { progression in
                ProgressionRecipeCard(recipe: progression, accent: theme.accentGlowColor)
            }
        }
        .sectionCardStyle()
    }

    private func movementSection(activeSlice: CircleSlice, activeFocus: SegmentFocus) -> some View {
        let previousIndex = (activeFocus.index - 1 + model.slices.count) % model.slices.count
        let nextIndex = (activeFocus.index + 1) % model.slices.count
        let previous = model.slices[previousIndex]
        let next = model.slices[nextIndex]

        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Best next moves", accent: theme.highlightColor)

            NeighborNavigationCard(
                direction: "Counter-clockwise",
                label: previous.label(for: activeFocus.ring),
                subtitle: "More release, broader color",
                sharedNotes: sharedNotes(with: previous, activeSlice: activeSlice, ring: activeFocus.ring),
                sharedChords: sharedChords(with: previous, activeSlice: activeSlice, ring: activeFocus.ring),
                accent: theme.highlightColor
            ) {
                withAnimation(panelAnimation) {
                    model.select(SegmentFocus(index: previousIndex, ring: activeFocus.ring))
                }
            }

            NeighborNavigationCard(
                direction: "Clockwise",
                label: next.label(for: activeFocus.ring),
                subtitle: "More pull, stronger forward motion",
                sharedNotes: sharedNotes(with: next, activeSlice: activeSlice, ring: activeFocus.ring),
                sharedChords: sharedChords(with: next, activeSlice: activeSlice, ring: activeFocus.ring),
                accent: theme.accentGlowColor
            ) {
                withAnimation(panelAnimation) {
                    model.select(SegmentFocus(index: nextIndex, ring: activeFocus.ring))
                }
            }
        }
        .sectionCardStyle()
    }

    private func scaleSectionTitle(for ring: RingKind) -> String {
        switch ring {
        case .major:
            return "Scale notes"
        case .minor:
            return "Relative minor scale"
        case .diminished:
            return "Chord tones"
        }
    }

    private func scaleNotes(for slice: CircleSlice, ring: RingKind) -> [String] {
        switch ring {
        case .major:
            return slice.scaleNotes
        case .minor:
            return slice.minorScaleNotes
        case .diminished:
            return slice.diminishedTriadNotes
        }
    }

    private func diatonicChords(for slice: CircleSlice, ring: RingKind) -> [String] {
        switch ring {
        case .major, .diminished:
            return slice.diatonicTriads
        case .minor:
            return slice.minorDiatonicTriads
        }
    }

    private func romanNumerals(for slice: CircleSlice, ring: RingKind) -> [String] {
        switch ring {
        case .major, .diminished:
            return slice.diatonicRomanNumerals
        case .minor:
            return slice.minorRomanNumerals
        }
    }

    private func progressions(for slice: CircleSlice, activeFocus: SegmentFocus) -> [ProgressionRecipe] {
        switch activeFocus.ring {
        case .major:
            return slice.majorProgressions
        case .minor:
            return slice.minorProgressions
        case .diminished:
            let next = model.nextSlice(for: activeFocus.index)
            return [
                ProgressionRecipe(
                    id: "resolve-home",
                    title: "Resolve home",
                    numerals: "vii° – I",
                    chords: [slice.diminishedLabel, slice.majorLabel]
                ),
                ProgressionRecipe(
                    id: "resolve-forward",
                    title: "Push forward",
                    numerals: "vii° – V/V",
                    chords: [slice.diminishedLabel, next.majorLabel]
                )
            ]
        }
    }

    private func sharedNotes(with other: CircleSlice, activeSlice: CircleSlice, ring: RingKind) -> [String] {
        sharedItems(
            source: scaleNotes(for: activeSlice, ring: ring),
            other: scaleNotes(for: other, ring: ring),
            normalize: canonicalPitchClass(for:)
        )
    }

    private func sharedChords(with other: CircleSlice, activeSlice: CircleSlice, ring: RingKind) -> [String] {
        sharedItems(
            source: diatonicChords(for: activeSlice, ring: ring),
            other: diatonicChords(for: other, ring: ring),
            normalize: canonicalChordIdentity(for:)
        )
    }

    private var panelAnimation: Animation {
        reduceMotion ? .easeOut(duration: 0.12) : .snappy(duration: 0.24, extraBounce: 0.01)
    }
}

private struct PanelBackground: View {
    let theme: PanelTheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: theme.backgroundColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            NoiseOverlay()
                .blendMode(.softLight)
                .opacity(0.18)

            VStack {
                HStack {
                    Circle()
                        .fill(theme.highlightColor.opacity(0.16))
                        .frame(width: 420, height: 420)
                        .blur(radius: 90)
                        .offset(x: -100, y: -150)

                    Spacer()
                }

                Spacer()

                HStack {
                    Spacer()

                    Circle()
                        .fill(theme.accentGlowColor.opacity(0.18))
                        .frame(width: 360, height: 360)
                        .blur(radius: 80)
                        .offset(x: 120, y: 120)
                }
            }

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            .black.opacity(0.12),
                            .clear,
                            .black.opacity(0.18)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .ignoresSafeArea()
    }
}

private struct NoiseOverlay: View {
    var body: some View {
        TimelineView(.animation) { _ in
            Canvas { context, size in
                let rect = CGRect(origin: .zero, size: size)
                context.fill(Path(rect), with: .color(.white.opacity(0.02)))

                for _ in 0..<160 {
                    let x = CGFloat.random(in: 0...size.width)
                    let y = CGFloat.random(in: 0...size.height)
                    let width = CGFloat.random(in: 1...3)
                    let height = CGFloat.random(in: 1...3)
                    let alpha = Double.random(in: 0.015...0.05)
                    context.fill(
                        Path(CGRect(x: x, y: y, width: width, height: height)),
                        with: .color(.white.opacity(alpha))
                    )
                }
            }
        }
        .allowsHitTesting(false)
    }
}

private struct PanelMetrics {
    let size: CGSize

    var outerPadding: CGFloat {
        min(34, max(22, size.width * 0.026))
    }

    var columnSpacing: CGFloat {
        min(28, max(18, size.width * 0.022))
    }

    var cardPadding: CGFloat {
        min(28, max(20, size.width * 0.02))
    }

    var detailWidth: CGFloat {
        min(430, max(360, size.width * 0.31))
    }

    var wheelFrameSize: CGFloat {
        let availableWidth = size.width - (outerPadding * 2) - detailWidth - columnSpacing - (cardPadding * 2)
        let availableHeight = size.height - (outerPadding * 2) - 220
        return max(360, min(availableWidth, availableHeight, 660))
    }
}

private struct BandLayout {
    let inner: CGFloat
    let outer: CGFloat
    let font: CGFloat
    let widthFactor: CGFloat
    let labelPosition: CGFloat

    var labelRadius: CGFloat {
        inner + ((outer - inner) * labelPosition)
    }
}

private struct RingSegmentShape: InsettableShape {
    let centerAngle: Angle
    let sweep: Angle
    let innerRadiusRatio: CGFloat
    let outerRadiusRatio: CGFloat
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2
        let outerRadius = radius * outerRadiusRatio - insetAmount
        let innerRadius = radius * innerRadiusRatio + insetAmount
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let start = centerAngle - sweep / 2
        let end = centerAngle + sweep / 2

        var path = Path()
        path.addArc(center: center, radius: outerRadius, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> some InsettableShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}

private struct ShortcutBadge: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .black, design: .rounded))
            .foregroundStyle(.white.opacity(0.78))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(.black.opacity(0.18), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
    }
}

private struct RevealStateBadge: View {
    let title: String
    let detail: String
    let theme: PanelTheme

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(theme.highlightColor.opacity(0.9))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(0.46))
                    .tracking(1.2)

                Text(detail)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(.black.opacity(0.18), in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct StatusPill: View {
    let title: String
    let value: String
    let emphasis: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
                .tracking(1.2)

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(emphasis.opacity(0.14), in: Capsule())
        .overlay {
            Capsule()
                .stroke(emphasis.opacity(0.24), lineWidth: 1)
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(accent)
                .frame(width: 16, height: 4)

            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.64))
                .tracking(1.1)
                .textCase(.uppercase)
        }
    }
}

private struct FocusModeButton: View {
    let title: String
    let value: String
    let isSelected: Bool
    let highlight: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundStyle(.white.opacity(isSelected ? 0.56 : 0.38))
                    .tracking(1.2)
                    .textCase(.uppercase)

                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isSelected ? highlight.opacity(0.16) : .black.opacity(0.16), in: .rect(cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(isSelected ? highlight.opacity(0.34) : .white.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(PressableCardButtonStyle())
    }
}

private struct MetaChip: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
                .tracking(1.2)

            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(.black.opacity(0.16), in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct ChipGrid: View {
    let items: [String]
    let highlight: Color

    private let columns = [
        GridItem(.adaptive(minimum: 68, maximum: 120), spacing: 8, alignment: .leading)
    ]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(highlight.opacity(0.10), in: Capsule())
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.05), lineWidth: 1)
                    }
            }
        }
    }
}

private struct ChordBlock: View {
    let title: String
    let notes: [String]
    let accent: Color

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text(notes.joined(separator: "  "))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.68))
            }

            Spacer(minLength: 12)

            Circle()
                .fill(accent.opacity(0.85))
                .frame(width: 10, height: 10)
        }
        .padding(16)
        .background(.black.opacity(0.18), in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct RomanChordGrid: View {
    let numerals: [String]
    let chords: [String]
    let accent: Color

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(zip(numerals, chords)), id: \.0) { numeral, chord in
                HStack(spacing: 12) {
                    Text(numeral)
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundStyle(.white.opacity(0.46))
                        .frame(width: 28, alignment: .leading)

                    Capsule()
                        .fill(accent.opacity(0.24))
                        .frame(width: 6, height: 6)

                    Text(chord)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer(minLength: 10)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(.black.opacity(0.16), in: .rect(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(.white.opacity(0.05), lineWidth: 1)
                }
            }
        }
    }
}

private struct ProgressionRecipeCard: View {
    let recipe: ProgressionRecipe
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(recipe.title)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer(minLength: 12)

                Text(recipe.numerals)
                    .font(.system(size: 11, weight: .black, design: .rounded))
                    .foregroundStyle(accent.opacity(0.96))
                    .tracking(0.8)
            }

            ChipGrid(items: recipe.chords, highlight: accent)
        }
        .padding(16)
        .background(.black.opacity(0.16), in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct NeighborNavigationCard: View {
    let direction: String
    let label: String
    let subtitle: String
    let sharedNotes: [String]
    let sharedChords: [String]
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(direction.uppercased())
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundStyle(.white.opacity(0.42))
                            .tracking(1.2)

                        Text(label)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    Spacer(minLength: 8)

                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.60))
                        .multilineTextAlignment(.trailing)
                }

                if !sharedNotes.isEmpty {
                    SharedMaterialRow(title: "Shared notes", items: sharedNotes, accent: accent)
                }

                if !sharedChords.isEmpty {
                    SharedMaterialRow(title: "Shared chords", items: sharedChords.prefix(4).map(\.self), accent: accent)
                }
            }
            .padding(16)
            .background(accent.opacity(0.09), in: .rect(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .stroke(accent.opacity(0.18), lineWidth: 1)
            }
        }
        .buttonStyle(PressableCardButtonStyle())
    }
}

private struct SharedMaterialRow: View {
    let title: String
    let items: [String]
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundStyle(.white.opacity(0.40))
                .tracking(1.2)

            ChipGrid(items: items, highlight: accent)
        }
    }
}

private struct UseCaseRow: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(detail)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.64))
        }
        .padding(16)
        .background(.black.opacity(0.18), in: .rect(cornerRadius: 22))
        .overlay {
            RoundedRectangle(cornerRadius: 22)
                .stroke(.white.opacity(0.06), lineWidth: 1)
        }
    }
}

private struct LinearMeter: View {
    let theme: PanelTheme

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<12, id: \.self) { index in
                RoundedRectangle(cornerRadius: 3)
                    .fill(index < 8 ? theme.highlightColor.opacity(0.9 - Double(index) * 0.08) : .white.opacity(0.08))
                    .frame(height: index % 3 == 0 ? 10 : 6)
            }
        }
        .frame(maxWidth: 220)
    }
}

private struct GlassCard: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color

    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            content
                .background(tint, in: .rect(cornerRadius: cornerRadius))
                .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius))
        } else {
            legacyBody(for: content)
        }
        #else
        legacyBody(for: content)
        #endif
    }

    private func legacyBody(for content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
    }
}

private struct PressableCapsuleButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.84))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.black.opacity(0.18), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(reduceMotion ? .easeOut(duration: 0.08) : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

private struct PressableCardButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .brightness(configuration.isPressed ? -0.02 : 0)
            .animation(reduceMotion ? .easeOut(duration: 0.08) : .easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

private extension View {
    func sectionCardStyle() -> some View {
        padding(18)
            .background(.white.opacity(0.035), in: .rect(cornerRadius: 26))
            .overlay {
                RoundedRectangle(cornerRadius: 26)
                    .stroke(.white.opacity(0.05), lineWidth: 1)
            }
    }

    func panelCardStyle(cornerRadius: CGFloat, tint: Color) -> some View {
        modifier(GlassCard(cornerRadius: cornerRadius, tint: tint))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(.white.opacity(0.05), lineWidth: 1)
            }
    }
}

private extension RingKind {
    var shortLabel: String {
        switch self {
        case .major:
            return "Major"
        case .minor:
            return "Minor"
        case .diminished:
            return "Dim"
        }
    }
}
