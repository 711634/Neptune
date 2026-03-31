import SwiftUI
import AppKit

// MARK: - Animation Profiles
struct PetAnimationProfile {
    let baseBouncePeriod: CGFloat      // Cycle duration in seconds
    let bounceAmplitude: CGFloat       // Max bounce height in pixels
    let breathingScale: CGFloat        // Subtle breathing amplitude
    let eyeBlinkRate: CGFloat          // Blinks per second
    let glowIntensity: CGFloat         // Base glow opacity
    let energyLevel: CGFloat           // 0 = calm, 1 = very active

    static let idle = PetAnimationProfile(
        baseBouncePeriod: 2.5,
        bounceAmplitude: 1.5,
        breathingScale: 0.03,
        eyeBlinkRate: 0.3,
        glowIntensity: 0.02,
        energyLevel: 0.2
    )

    static let thinking = PetAnimationProfile(
        baseBouncePeriod: 2.0,
        bounceAmplitude: 2.0,
        breathingScale: 0.02,
        eyeBlinkRate: 0.25,
        glowIntensity: 0.05,
        energyLevel: 0.4
    )

    static let coding = PetAnimationProfile(
        baseBouncePeriod: 1.2,
        bounceAmplitude: 3.0,
        breathingScale: 0.01,
        eyeBlinkRate: 0.2,
        glowIntensity: 0.12,
        energyLevel: 0.8
    )

    static let success = PetAnimationProfile(
        baseBouncePeriod: 0.8,
        bounceAmplitude: 4.0,
        breathingScale: 0.0,
        eyeBlinkRate: 0.5,
        glowIntensity: 0.15,
        energyLevel: 1.0
    )

    static let failed = PetAnimationProfile(
        baseBouncePeriod: 3.0,
        bounceAmplitude: 0.5,
        breathingScale: 0.02,
        eyeBlinkRate: 0.4,
        glowIntensity: 0.06,
        energyLevel: 0.1
    )

    static let sleeping = PetAnimationProfile(
        baseBouncePeriod: 4.0,
        bounceAmplitude: 0.3,
        breathingScale: 0.05,
        eyeBlinkRate: 0.0,
        glowIntensity: 0.01,
        energyLevel: 0.0
    )

    static func profileForStatus(_ status: AgentStatus) -> PetAnimationProfile {
        switch status {
        case .idle: return .idle
        case .thinking: return .thinking
        case .coding: return .coding
        case .success: return .success
        case .failed: return .failed
        case .sleeping: return .sleeping
        default: return .idle
        }
    }
}

// MARK: - Easing Functions
struct EasingFunctions {
    static func easeInOutCubic(_ t: CGFloat) -> CGFloat {
        let t = max(0, min(1, t))
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            let f = 2 * t - 2
            return 0.5 * f * f * f + 1
        }
    }

    static func easeInOutQuad(_ t: CGFloat) -> CGFloat {
        let t = max(0, min(1, t))
        if t < 0.5 {
            return 2 * t * t
        } else {
            return 1 - pow(-2 * t + 2, 2) / 2
        }
    }

    static func sineWave(_ t: CGFloat) -> CGFloat {
        return sin(t * .pi * 2)
    }

    static func smoothstep(_ t: CGFloat) -> CGFloat {
        let t = max(0, min(1, t))
        return t * t * (3 - 2 * t)
    }
}

class FloatingDockWindow: NSPanel {
    var hostingView: NSHostingView<FloatingDockContentView>?
    private var screenChangeObserver: NSObjectProtocol?
    private let settings = AppSettings.shared
    private var lastScreenWidth: CGFloat = 0
    private var activityMonitor: ActivityMonitor?
    private var currentAlpha: CGFloat = 0

    init(activityMonitor: ActivityMonitor? = nil) {
        let initialFrame = NSRect(x: 0, y: 0, width: 900, height: 100)
        super.init(
            contentRect: initialFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.isOpaque = false
        self.backgroundColor = .clear
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]

        // Start hidden and update based on activity
        self.alphaValue = 0
        self.activityMonitor = activityMonitor

        setupContent()
        positionWindow()
        setupScreenChangeObserver()
    }

    deinit {
        if let observer = screenChangeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func setupScreenChangeObserver() {
        screenChangeObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.positionWindow()
        }
    }

    private func setupContent() {
        let contentView = FloatingDockContentView(agents: [], settings: settings)
        hostingView = NSHostingView(rootView: contentView)
        hostingView?.frame = NSRect(x: 0, y: 0, width: 900, height: 100)
        self.contentView = hostingView
    }

    func updateAgents(_ agents: [Agent]) {
        let sortedAgents = agents.sorted { $0.slotIndex < $1.slotIndex }
        let contentView = FloatingDockContentView(agents: sortedAgents, settings: settings)
        hostingView?.rootView = contentView

        // Update visibility based on activity
        activityMonitor?.updateActivity(with: agents)
    }

    /// Set the overlay's visibility based on activity level.
    func setVisibility(to activityLevel: ActivityMonitor.ActivityLevel) {
        let targetAlpha: CGFloat = switch activityLevel {
        case .inactive:
            0.0
        case .dormant:
            0.2 // Very subtle
        case .active:
            1.0
        }

        if currentAlpha != targetAlpha {
            currentAlpha = targetAlpha
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.6
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.animator().alphaValue = targetAlpha
            })
        }
    }

    private func positionWindow() {
        guard let screen = NSScreen.main else { return }

        let screenFrame = screen.visibleFrame
        let isUltraWide = screenFrame.width > 2560
        let baseWidth: CGFloat = isUltraWide ? 1000 : 900
        let windowWidth: CGFloat = min(baseWidth, screenFrame.width * 0.85)
        let windowHeight: CGFloat = 100

        let xPos = screenFrame.origin.x + (screenFrame.width - windowWidth) / 2
        // In AppKit coords y=0 is at screen bottom. screenFrame.minY is the top of the Dock.
        // Placing yPos here puts the overlay bottom flush with the Dock top edge.
        let yPos = screenFrame.minY

        lastScreenWidth = screenFrame.width
        self.setFrame(NSRect(x: xPos, y: yPos, width: windowWidth, height: windowHeight), display: true)
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

struct FloatingDockContentView: View {
    let agents: [Agent]
    let settings: AppSettings

    var body: some View {
        ZStack(alignment: .center) {
            if agents.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
            } else {
                floatingPetsLayout
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
    }

    private var floatingPetsLayout: some View {
        let petWidth: CGFloat = 90

        return ZStack {
            ForEach(Array(agents.enumerated()), id: \.element.id) { index, agent in
                let xOffset = (CGFloat(index) - CGFloat(agents.count - 1) / 2) * (petWidth + 12)

                DockPetView(agent: agent, syncAnimations: settings.syncPetAnimations)
                    .offset(x: xOffset)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 100)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "ghost")
                .font(.system(size: 20))
                .foregroundColor(.gray.opacity(0.5))

            Text("Waiting...")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.gray.opacity(0.5))
        }
        .frame(width: 72, height: 72)
    }
}

struct DockPetView: View {
    let agent: Agent
    let syncAnimations: Bool

    @State private var elapsedTime: TimeInterval = 0
    @State private var reactionStartTime: TimeInterval?
    @State private var reactionType: String = "none"
    @State private var animationTimer: Timer?
    @State private var lastStatus: AgentStatus?
    @State private var statusChangeTime: TimeInterval = 0
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    private let settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 6) {
            roleBadge

            petBody
        }
        .onAppear {
            lastStatus = agent.status
            startAnimationLoop()
        }
        .onDisappear {
            stopAnimationLoop()
        }
        .onChange(of: agent.status) { newStatus in
            lastStatus = agent.status
            statusChangeTime = elapsedTime
            triggerReactionIfNeeded(newStatus)
        }
    }

    private func startAnimationLoop() {
        stopAnimationLoop()

        let updateInterval = 1.0 / 60.0  // 60 FPS smooth animation
        animationTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { _ in
            if reduceMotion || settings.reducedMotion {
                elapsedTime += updateInterval * 2  // Slow down reduced motion
            } else {
                elapsedTime += updateInterval
            }
        }
    }

    private func stopAnimationLoop() {
        animationTimer?.invalidate()
        animationTimer = nil
    }

    private func triggerReactionIfNeeded(_ newStatus: AgentStatus) {
        if newStatus == .success {
            reactionType = "shipped"
            reactionStartTime = elapsedTime
        } else if newStatus == .failed {
            reactionType = "failed"
            reactionStartTime = elapsedTime
        }
    }

    private func isInTemporaryReaction() -> Bool {
        guard let startTime = reactionStartTime else { return false }
        let reactionAge = elapsedTime - startTime
        return reactionAge < 2.5  // Reaction lasts 2.5 seconds
    }

    private func getEffectiveStatus() -> AgentStatus {
        // Temporary reactions show calm state after the reaction animation
        if isInTemporaryReaction() && (reactionType == "shipped" || reactionType == "failed") {
            return .idle
        }
        return agent.status
    }


    private var roleBadge: some View {
        Text(agent.role.displayName)
            .font(.system(size: 7, weight: .bold, design: .monospaced))
            .foregroundColor(Color(hex: agent.role.badgeColor))
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(
                ZStack {
                    Capsule()
                        .fill(Color(hex: "0F0F1E").opacity(0.95))

                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.clear,
                                    Color.white.opacity(0.06)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .border(Color(hex: agent.role.badgeColor).opacity(0.3), width: 0.5)
    }

    private var petBody: some View {
        let effectiveStatus = getEffectiveStatus()
        let profile = PetAnimationProfile.profileForStatus(effectiveStatus)

        // Smooth bounce animation
        let bounceCycleTime = fmod(elapsedTime, profile.baseBouncePeriod) / profile.baseBouncePeriod
        let bounceOffset = EasingFunctions.sineWave(bounceCycleTime) * profile.bounceAmplitude

        // Breathing animation (subtle scale)
        let breathingCycleTime = fmod(elapsedTime, 3.0) / 3.0
        let breathingScale = 1.0 + EasingFunctions.sineWave(breathingCycleTime) * profile.breathingScale

        // Glow pulse for active pets
        let glowCycleTime = fmod(elapsedTime, 2.0) / 2.0
        let glowPulse = EasingFunctions.easeInOutQuad(abs(sin(glowCycleTime * .pi)))

        let isActive = effectiveStatus == .coding || effectiveStatus == .thinking || effectiveStatus == .success
        let glowColor = isActive ? agent.colorVariant.primaryColor : Color.clear
        let baseGlow = PetAnimationProfile.profileForStatus(effectiveStatus).glowIntensity
        let glowOpacity = isActive ? (baseGlow + glowPulse * 0.1) : 0.0

        let effectiveReduceMotion = reduceMotion || settings.reducedMotion
        let transitionDuration = effectiveReduceMotion ? 0.3 : 0.2

        return ZStack {
            if isActive {
                Circle()
                    .fill(glowColor.opacity(glowOpacity))
                    .frame(width: 60, height: 60)
                    .blur(radius: 8)
            }

            Canvas { context, size in
                drawTamagotchiPet(
                    in: context,
                    size: size,
                    status: effectiveStatus,
                    time: elapsedTime,
                    profile: profile,
                    blinkPhase: fmod(elapsedTime * profile.eyeBlinkRate, 1.0)
                )
            }
            .frame(width: 54, height: 54)
            .offset(y: bounceOffset)
            .scaleEffect(breathingScale)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: transitionDuration), value: effectiveStatus)
    }

    private func drawTamagotchiPet(
        in context: GraphicsContext,
        size: CGSize,
        status: AgentStatus,
        time: TimeInterval,
        profile: PetAnimationProfile,
        blinkPhase: CGFloat
    ) {
        let pixelSize: CGFloat = size.width / 12
        let centerX = size.width / 2
        let centerY = size.height / 2

        let baseColor = agent.colorVariant.primaryColor
        let darkColor = agent.colorVariant.secondaryColor
        let accentColor = agent.colorVariant.accentColor

        // Smooth idle bounce for body
        let bounceCycleTime = fmod(time, 2.5) / 2.5
        let idleBounce = EasingFunctions.sineWave(bounceCycleTime) * 0.6

        for y in 0..<10 {
            for x in 0..<12 {
                let px = CGFloat(x) * pixelSize
                let py = CGFloat(y) * pixelSize + idleBounce

                let isEar = (x == 1 && y == 1) || (x == 10 && y == 1)
                let xOffset = Double(x) - 5.5
                let isTopHead = y == 2 && abs(xOffset) <= 3.5
                let isMidBody = (y == 3 || y == 4 || y == 5) && abs(xOffset) <= 4.5
                let isBottom = y == 6 && abs(xOffset) <= 3.5
                let isFeet = y == 7 && (x == 2 || x == 3 || x == 8 || x == 9)

                if isEar || isTopHead || isMidBody || isBottom || isFeet {
                    var pixelColor = baseColor
                    if isEar {
                        pixelColor = darkColor
                    } else if y == 7 && (x == 2 || x == 9) {
                        pixelColor = darkColor
                    }

                    let rect = CGRect(x: px, y: py, width: pixelSize - 0.5, height: pixelSize - 0.5)
                    context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(pixelColor))
                }
            }
        }

        let eyeY = centerY - pixelSize + idleBounce
        let eyeSize = pixelSize * 0.9

        // Smooth blinking animation
        let isBlink = blinkPhase > 0.85  // Quick blink near end of phase
        let blinkHeight = isBlink ? eyeSize * 0.1 : eyeSize

        switch status {
        case .idle:
            // Calm, peaceful eyes with gentle blinking
            let leftEye = CGRect(x: centerX - 2.5 * pixelSize, y: eyeY, width: eyeSize, height: blinkHeight)
            let rightEye = CGRect(x: centerX + 1.5 * pixelSize, y: eyeY, width: eyeSize, height: blinkHeight)
            context.fill(Path(ellipseIn: leftEye), with: .color(Color(hex: "1F2937")))
            context.fill(Path(ellipseIn: rightEye), with: .color(Color(hex: "1F2937")))

            let leftHighlight = CGRect(x: centerX - 2.2 * pixelSize + 2, y: eyeY + 2, width: eyeSize * 0.3, height: eyeSize * 0.3)
            let rightHighlight = CGRect(x: centerX + 1.8 * pixelSize + 2, y: eyeY + 2, width: eyeSize * 0.3, height: eyeSize * 0.3)
            context.fill(Path(ellipseIn: leftHighlight), with: .color(Color.white.opacity(0.7)))
            context.fill(Path(ellipseIn: rightHighlight), with: .color(Color.white.opacity(0.7)))

        case .thinking:
            // Curious, attentive eyes with slight look-around
            let thinkCycleTime = fmod(time, 3.0) / 3.0
            let eyeShift = EasingFunctions.sineWave(thinkCycleTime) * pixelSize * 0.3

            let leftEye = CGRect(x: centerX - 2.5 * pixelSize + eyeShift, y: eyeY, width: eyeSize, height: blinkHeight)
            let rightEye = CGRect(x: centerX + 1.5 * pixelSize + eyeShift, y: eyeY, width: eyeSize, height: blinkHeight)
            context.fill(Path(ellipseIn: leftEye), with: .color(Color(hex: "1F2937")))
            context.fill(Path(ellipseIn: rightEye), with: .color(Color(hex: "1F2937")))

            let leftHighlight = CGRect(x: centerX - 2.2 * pixelSize + eyeShift + 2, y: eyeY + 2, width: eyeSize * 0.3, height: eyeSize * 0.3)
            let rightHighlight = CGRect(x: centerX + 1.8 * pixelSize + eyeShift + 2, y: eyeY + 2, width: eyeSize * 0.3, height: eyeSize * 0.3)
            context.fill(Path(ellipseIn: leftHighlight), with: .color(Color.white.opacity(0.7)))
            context.fill(Path(ellipseIn: rightHighlight), with: .color(Color.white.opacity(0.7)))

        case .coding:
            // Focused, energetic eyes with quick blinking
            let codingCycleTime = fmod(time, 0.6) / 0.6
            let codingOffset = EasingFunctions.easeInOutQuad(codingCycleTime) * pixelSize * 0.3

            let leftEye = CGRect(x: centerX - 2.5 * pixelSize, y: eyeY + codingOffset, width: eyeSize * 0.8, height: eyeSize * 0.4)
            let rightEye = CGRect(x: centerX + 1.5 * pixelSize, y: eyeY + codingOffset, width: eyeSize * 0.8, height: eyeSize * 0.4)
            context.fill(Path(roundedRect: leftEye, cornerRadius: 1), with: .color(Color(hex: "1F2937")))
            context.fill(Path(roundedRect: rightEye, cornerRadius: 1), with: .color(Color(hex: "1F2937")))

            // Animated hands (quick movement when coding)
            let handMotionTime = fmod(time, 0.8) / 0.8
            let handBob = EasingFunctions.sineWave(handMotionTime) * pixelSize * 0.4
            let handY = centerY + pixelSize * 0.8 + idleBounce + handBob
            let leftHand = CGRect(x: centerX - 3 * pixelSize, y: handY, width: pixelSize * 0.6, height: pixelSize * 0.6)
            let rightHand = CGRect(x: centerX + 2.4 * pixelSize, y: handY, width: pixelSize * 0.6, height: pixelSize * 0.6)
            context.fill(Path(ellipseIn: leftHand), with: .color(darkColor))
            context.fill(Path(ellipseIn: rightHand), with: .color(darkColor))

        case .success:
            // Happy, celebratory eyes with proud expression
            let successBounce = EasingFunctions.easeInOutCubic(fmod(time, 0.8) / 0.8)
            let celebrateOffset = successBounce * pixelSize * 0.5

            let leftEye = CGRect(x: centerX - 2.5 * pixelSize, y: eyeY - celebrateOffset, width: eyeSize, height: blinkHeight)
            let rightEye = CGRect(x: centerX + 1.5 * pixelSize, y: eyeY - celebrateOffset, width: eyeSize, height: blinkHeight)
            context.fill(Path(ellipseIn: leftEye), with: .color(Color(hex: "1F2937")))
            context.fill(Path(ellipseIn: rightEye), with: .color(Color(hex: "1F2937")))

            // Happy smile
            let smileY = centerY + pixelSize * 1.5 + idleBounce
            let smilePath = Path { path in
                path.move(to: CGPoint(x: centerX - pixelSize, y: smileY))
                path.addQuadCurve(
                    to: CGPoint(x: centerX + pixelSize, y: smileY),
                    control: CGPoint(x: centerX, y: smileY + pixelSize)
                )
            }
            context.stroke(smilePath, with: .color(darkColor), lineWidth: 2)

            // Sparkling celebration
            let sparklePhase = fmod(time, 0.6)
            if sparklePhase < 0.3 {  // First half of cycle, show sparkles
                for i in 0..<3 {
                    let sparkleX = centerX + CGFloat(i - 1) * pixelSize * 2
                    let sparkleY = centerY - pixelSize * 2.5 + idleBounce - celebrateOffset
                    let sparkle = Path { path in
                        path.move(to: CGPoint(x: sparkleX, y: sparkleY - 4))
                        path.addLine(to: CGPoint(x: sparkleX, y: sparkleY + 4))
                        path.move(to: CGPoint(x: sparkleX - 3, y: sparkleY))
                        path.addLine(to: CGPoint(x: sparkleX + 3, y: sparkleY))
                    }
                    context.stroke(sparkle, with: .color(.yellow), lineWidth: 1.5)
                }
            }

        case .failed:
            // Disappointed expression with subtle sadness
            let leftEye = CGRect(x: centerX - 2.5 * pixelSize, y: eyeY, width: eyeSize, height: blinkHeight)
            let rightEye = CGRect(x: centerX + 1.5 * pixelSize, y: eyeY, width: eyeSize, height: blinkHeight)
            context.fill(Path(ellipseIn: leftEye), with: .color(Color(hex: "1F2937")))
            context.fill(Path(ellipseIn: rightEye), with: .color(Color(hex: "1F2937")))

            // Sad frown
            let frownY = centerY + pixelSize * 1.5 + idleBounce
            let frownPath = Path { path in
                path.move(to: CGPoint(x: centerX - pixelSize, y: frownY + pixelSize * 0.5))
                path.addQuadCurve(
                    to: CGPoint(x: centerX + pixelSize, y: frownY + pixelSize * 0.5),
                    control: CGPoint(x: centerX, y: frownY)
                )
            }
            context.stroke(frownPath, with: .color(Color(hex: "7F1D1D")), lineWidth: 2)

            // Recovery sweat (animates down)
            let sweatPhase = fmod(time, 1.5) / 1.5
            let sweatOffset = EasingFunctions.easeInOutQuad(sweatPhase) * pixelSize * 0.5
            let sweatX = centerX + pixelSize * 2.5
            let sweatY = centerY - pixelSize + idleBounce + sweatOffset
            let sweatPath = Path { path in
                path.move(to: CGPoint(x: sweatX, y: sweatY))
                path.addQuadCurve(
                    to: CGPoint(x: sweatX + 3, y: sweatY + 4),
                    control: CGPoint(x: sweatX + 4, y: sweatY + 1)
                )
            }
            context.stroke(sweatPath, with: .color(Color(hex: "60A5FA")), lineWidth: 1.5)

        case .sleeping:
            // Closed eyes with blinking z's
            let sleepBlinkHeight = eyeSize * 0.1
            let leftEye = CGRect(x: centerX - 2.5 * pixelSize, y: eyeY, width: eyeSize, height: sleepBlinkHeight)
            let rightEye = CGRect(x: centerX + 1.5 * pixelSize, y: eyeY, width: eyeSize, height: sleepBlinkHeight)
            context.fill(Path(roundedRect: leftEye, cornerRadius: 1), with: .color(Color(hex: "1F2937")))
            context.fill(Path(roundedRect: rightEye, cornerRadius: 1), with: .color(Color(hex: "1F2937")))

            // Floating z's (sleep breathing)
            let zPhase = fmod(time, 2.0) / 2.0
            let zFloat = EasingFunctions.sineWave(zPhase) * pixelSize * 0.3
            let zX = centerX + pixelSize * 2
            let zY = centerY - pixelSize * 2 + idleBounce + zFloat
            let zPath = Path { path in
                path.move(to: CGPoint(x: zX, y: zY))
                path.addLine(to: CGPoint(x: zX + 5, y: zY))
                path.move(to: CGPoint(x: zX + 2.5, y: zY - 2))
                path.addLine(to: CGPoint(x: zX + 2.5, y: zY + 3))
            }
            context.stroke(zPath, with: .color(accentColor), lineWidth: 1.5)

        default:
            let leftEye = CGRect(x: centerX - 2.5 * pixelSize, y: eyeY, width: eyeSize, height: blinkHeight)
            let rightEye = CGRect(x: centerX + 1.5 * pixelSize, y: eyeY, width: eyeSize, height: blinkHeight)
            context.fill(Path(ellipseIn: leftEye), with: .color(Color(hex: "1F2937")))
            context.fill(Path(ellipseIn: rightEye), with: .color(Color(hex: "1F2937")))
        }
    }
}
