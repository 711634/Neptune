import SwiftUI

struct PixelPetView: View {
    let petState: PetState
    let settings: AppSettings

    @State private var animationFrame: Int = 0

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(hex: "1F2937"))
                .frame(width: 120, height: 120)

            pixelCharacter
                .frame(width: 80, height: 80)
        }
        .onAppear {
            startAnimation()
        }
    }

    @ViewBuilder
    private var pixelCharacter: some View {
        switch petState {
        case .idle:
            idlePet
        case .thinking:
            thinkingPet
        case .coding:
            codingPet
        case .success:
            successPet
        case .failed:
            failedPet
        case .sleeping:
            sleepingPet
        }
    }

    private var idlePet: some View {
        Canvas { context, size in
            drawPet(in: context, size: size, type: .idle, frame: animationFrame % 2)
        }
    }

    private var thinkingPet: some View {
        Canvas { context, size in
            drawPet(in: context, size: size, type: .thinking, frame: animationFrame % 4)
        }
    }

    private var codingPet: some View {
        Canvas { context, size in
            drawPet(in: context, size: size, type: .coding, frame: animationFrame % 4)
        }
    }

    private var successPet: some View {
        Canvas { context, size in
            drawPet(in: context, size: size, type: .success, frame: animationFrame % 4)
        }
    }

    private var failedPet: some View {
        Canvas { context, size in
            drawPet(in: context, size: size, type: .failed, frame: animationFrame % 2)
        }
    }

    private var sleepingPet: some View {
        Canvas { context, size in
            drawPet(in: context, size: size, type: .sleeping, frame: animationFrame % 2)
        }
    }

    private func drawPet(in context: GraphicsContext, size: CGSize, type: PetState, frame: Int) {
        let pixelSize: CGFloat = size.width / 12
        let centerX = size.width / 2
        let centerY = size.height / 2

        let baseColor = Color(hex: "10B981")
        let darkColor = Color(hex: "059669")
        let lightColor = Color(hex: "34D399")
        let eyeColor = Color(hex: "1F2937")

        switch type {
        case .idle:
            drawBasePet(context: context, pixelSize: pixelSize, centerX: centerX, centerY: centerY, baseColor: baseColor, eyeColor: eyeColor, blink: frame == 1)

        case .thinking:
            let bounce = CGFloat(frame) * 2 - 3
            drawBasePet(context: context, pixelSize: pixelSize, centerX: centerX, centerY: centerY + bounce, baseColor: Color(hex: "F59E0B"), eyeColor: eyeColor, blink: false)

        case .coding:
            let typing = frame % 2 == 0
            let eyeY: CGFloat = typing ? -1.5 * pixelSize : -1 * pixelSize
            drawBasePet(context: context, pixelSize: pixelSize, centerX: centerX, centerY: centerY, baseColor: baseColor, eyeColor: eyeColor, blink: false, eyeOffset: eyeY)

        case .success:
            let bounce = abs(CGFloat(frame) - 1.5) * -4
            drawBasePet(context: context, pixelSize: pixelSize, centerX: centerX, centerY: centerY + bounce, baseColor: lightColor, eyeColor: eyeColor, blink: false, smile: true)

        case .failed:
            let flicker = frame == 1 ? 0.6 : 1.0
            let adjustedBase = Color(red: 0.063 * flicker, green: 0.725 * flicker, blue: 0.506 * flicker)
            drawBasePet(context: context, pixelSize: pixelSize, centerX: centerX, centerY: centerY, baseColor: adjustedBase, eyeColor: eyeColor, blink: false, frown: true)

        case .sleeping:
            let breathe = CGFloat(frame % 2) * 1
            drawBasePet(context: context, pixelSize: pixelSize, centerX: centerX, centerY: centerY + breathe, baseColor: Color(hex: "3B82F6"), eyeColor: eyeColor, blink: true)
        }
    }

    private func drawBasePet(context: GraphicsContext, pixelSize: CGFloat, centerX: CGFloat, centerY: CGFloat, baseColor: Color, eyeColor: Color, blink: Bool, eyeOffset: CGFloat = 0, smile: Bool = false, frown: Bool = false) {
        for y in -3...3 {
            for x in -4...4 {
                let rect = CGRect(x: centerX + CGFloat(x) * pixelSize, y: centerY + CGFloat(y) * pixelSize, width: pixelSize, height: pixelSize)

                if abs(x) <= 2 && y == -3 {
                    context.fill(Path(ellipseIn: rect), with: .color(baseColor))
                }
                else if abs(x) <= 3 && y == -2 {
                    context.fill(Path(ellipseIn: rect), with: .color(baseColor))
                }
                else if abs(x) <= 4 && y == -1 {
                    context.fill(Path(ellipseIn: rect), with: .color(baseColor))
                }
                else if abs(x) <= 4 && y == 0 {
                    context.fill(Path(ellipseIn: rect), with: .color(baseColor))
                }
                else if abs(x) <= 4 && y == 1 {
                    context.fill(Path(ellipseIn: rect), with: .color(baseColor))
                }
                else if abs(x) <= 3 && y == 2 {
                    context.fill(Path(ellipseIn: rect), with: .color(baseColor))
                }
                else if abs(x) <= 2 && y == 3 {
                    context.fill(Path(ellipseIn: rect), with: .color(baseColor))
                }
            }
        }

        let eyeY = -1 * pixelSize + eyeOffset
        if blink {
            let leftEye = CGRect(x: centerX - 2 * pixelSize, y: centerY + eyeY, width: pixelSize, height: pixelSize * 0.3)
            let rightEye = CGRect(x: centerX + 2 * pixelSize, y: centerY + eyeY, width: pixelSize, height: pixelSize * 0.3)
            context.fill(Path(roundedRect: leftEye, cornerRadius: 1), with: .color(eyeColor))
            context.fill(Path(roundedRect: rightEye, cornerRadius: 1), with: .color(eyeColor))
        } else {
            let leftEye = CGRect(x: centerX - 2 * pixelSize, y: centerY + eyeY, width: pixelSize, height: pixelSize)
            let rightEye = CGRect(x: centerX + 2 * pixelSize, y: centerY + eyeY, width: pixelSize, height: pixelSize)
            context.fill(Path(ellipseIn: leftEye), with: .color(eyeColor))
            context.fill(Path(ellipseIn: rightEye), with: .color(eyeColor))
        }

        if smile {
            let smilePath = Path { path in
                path.move(to: CGPoint(x: centerX - pixelSize, y: centerY + pixelSize))
                path.addQuadCurve(
                    to: CGPoint(x: centerX + pixelSize, y: centerY + pixelSize),
                    control: CGPoint(x: centerX, y: centerY + pixelSize * 2)
                )
            }
            context.stroke(smilePath, with: .color(Color(hex: "059669")), lineWidth: 2)
        }

        if frown {
            let frownPath = Path { path in
                path.move(to: CGPoint(x: centerX - pixelSize, y: centerY + pixelSize * 1.5))
                path.addQuadCurve(
                    to: CGPoint(x: centerX + pixelSize, y: centerY + pixelSize * 1.5),
                    control: CGPoint(x: centerX, y: centerY + pixelSize)
                )
            }
            context.stroke(frownPath, with: .color(Color(hex: "059669")), lineWidth: 2)
        }
    }

    private func startAnimation() {
        let duration = settings.reducedMotion ? 1.0 : petState.animationDuration

        Timer.scheduledTimer(withTimeInterval: duration, repeats: true) { _ in
            self.animationFrame = (self.animationFrame + 1) % 4
        }
    }
}
