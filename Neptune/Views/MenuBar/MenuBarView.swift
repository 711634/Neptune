import SwiftUI
import AppKit

struct MenuBarView: View {
    @ObservedObject var agentWatcher: AgentStateWatcher
    @ObservedObject var petMapper: PetStateMapper
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            menuHeader

            Divider()

            statusSection

            Divider()

            actionsSection
        }
        .frame(width: 260)
        .background(Color(hex: "1F2937"))
    }

    private var menuHeader: some View {
        let activeAgents = agentWatcher.agentState.agents.filter { $0.status != .idle }
        let dominantColor = computeDominantColor(for: activeAgents)

        return HStack(spacing: 10) {
            MenuBarPetIcon(
                petState: petMapper.currentPetState,
                activeAgentColors: activeAgents.map { $0.colorVariant },
                size: 24
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(settings.petName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)

                Text(petMapper.currentPetState.displayName)
                    .font(.system(size: 10))
                    .foregroundColor(dominantColor)
            }

            Spacer()
        }
        .padding(12)
    }

    private func computeDominantColor(for agents: [Agent]) -> Color {
        guard !agents.isEmpty else { return petMapper.currentPetState.color }
        if agents.count == 1 {
            return agents[0].colorVariant.primaryColor
        }
        if agents.count > 1 {
            return agents[0].colorVariant.primaryColor.opacity(0.7)
        }
        return petMapper.currentPetState.color
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "ant.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "6B7280"))

                Text(agentWatcher.getSummaryText())
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "9CA3AF"))

                Spacer()

                if agentWatcher.isWatching {
                    Circle()
                        .fill(Color(hex: "10B981"))
                        .frame(width: 6, height: 6)
                }
            }

            if let error = agentWatcher.lastError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "F59E0B"))

                    Text(error)
                        .font(.system(size: 10))
                        .foregroundColor(Color(hex: "F59E0B"))
                        .lineLimit(2)
                }
            }
        }
        .padding(12)
    }

    private var actionsSection: some View {
        VStack(spacing: 2) {
            menuButton(icon: "square.grid.2x2", title: "Open Dashboard") {
                NSApp.activate(ignoringOtherApps: true)
                if let window = NSApp.windows.first {
                    window.makeKeyAndOrderFront(nil)
                }
            }

            menuButton(icon: "gearshape", title: "Settings...") {
                NotificationCenter.default.post(name: .openSettings, object: nil)
            }

            Divider()
                .padding(.vertical, 4)

            menuButton(icon: "power", title: "Quit Clonk") {
                NSApp.terminate(nil)
            }
        }
        .padding(8)
    }

    private func menuButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(Color(hex: "9CA3AF"))
                    .frame(width: 20)

                Text(title)
                    .font(.system(size: 12))
                    .foregroundColor(.white)

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}

struct MenuBarPetIcon: View {
    let petState: PetState
    let activeAgentColors: [ColorVariant]
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            let pixelSize = canvasSize.width / 10
            let displayColor = selectDisplayColor()

            switch petState {
            case .idle:
                drawSimplePet(context: context, pixelSize: pixelSize, color: Color(hex: "10B981"), eyes: true)
            case .thinking:
                drawSimplePet(context: context, pixelSize: pixelSize, color: displayColor, eyes: true)
            case .coding:
                drawSimplePet(context: context, pixelSize: pixelSize, color: displayColor, eyes: true)
            case .success:
                drawSimplePet(context: context, pixelSize: pixelSize, color: displayColor, eyes: true)
            case .failed:
                drawSimplePet(context: context, pixelSize: pixelSize, color: Color(hex: "EF4444"), eyes: true)
            case .sleeping:
                drawSleepingPet(context: context, pixelSize: pixelSize)
            }
        }
        .frame(width: size, height: size)
    }

    private func selectDisplayColor() -> Color {
        guard !activeAgentColors.isEmpty else { return petState.color }
        if activeAgentColors.count == 1 {
            return activeAgentColors[0].primaryColor
        }
        if activeAgentColors.count > 1 {
            return activeAgentColors[0].primaryColor.opacity(0.7)
        }
        return petState.color
    }

    private func drawSimplePet(context: GraphicsContext, pixelSize: CGFloat, color: Color, eyes: Bool) {
        let centerX = pixelSize * 5
        let centerY = pixelSize * 5

        for y in 2...7 {
            for x in 3...7 {
                let rect = CGRect(x: CGFloat(x) * pixelSize, y: CGFloat(y) * pixelSize, width: pixelSize, height: pixelSize)
                context.fill(Path(ellipseIn: rect), with: .color(color))
            }
        }

        if eyes {
            let eyeY = pixelSize * 4
            let leftEye = CGRect(x: 4 * pixelSize, y: eyeY, width: pixelSize, height: pixelSize)
            let rightEye = CGRect(x: 6 * pixelSize, y: eyeY, width: pixelSize, height: pixelSize)
            context.fill(Path(ellipseIn: leftEye), with: .color(Color(hex: "1F2937")))
            context.fill(Path(ellipseIn: rightEye), with: .color(Color(hex: "1F2937")))
        }
    }

    private func drawSleepingPet(context: GraphicsContext, pixelSize: CGFloat) {
        let centerX = pixelSize * 5
        let centerY = pixelSize * 5

        for y in 2...7 {
            for x in 3...7 {
                let rect = CGRect(x: CGFloat(x) * pixelSize, y: CGFloat(y) * pixelSize, width: pixelSize, height: pixelSize)
                context.fill(Path(ellipseIn: rect), with: .color(Color(hex: "3B82F6")))
            }
        }

        let eyeY = pixelSize * 5
        let leftEye = CGRect(x: 4 * pixelSize, y: eyeY, width: pixelSize * 1.5, height: pixelSize * 0.3)
        let rightEye = CGRect(x: 6 * pixelSize, y: eyeY, width: pixelSize * 1.5, height: pixelSize * 0.3)
        context.fill(Path(roundedRect: leftEye, cornerRadius: 1), with: .color(Color(hex: "1F2937")))
        context.fill(Path(roundedRect: rightEye, cornerRadius: 1), with: .color(Color(hex: "1F2937")))
    }
}

extension Notification.Name {
    static let openSettings = Notification.Name("openSettings")
}
