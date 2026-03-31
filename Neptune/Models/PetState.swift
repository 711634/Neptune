import Foundation
import SwiftUI

enum PetState: String, CaseIterable {
    case idle
    case thinking
    case coding
    case success
    case failed
    case sleeping

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .thinking: return "Thinking"
        case .coding: return "Coding"
        case .success: return "Success!"
        case .failed: return "Failed"
        case .sleeping: return "Sleeping"
        }
    }

    var emoji: String {
        switch self {
        case .idle: return "😐"
        case .thinking: return "🤔"
        case .coding: return "👨‍💻"
        case .success: return "🎉"
        case .failed: return "😢"
        case .sleeping: return "😴"
        }
    }

    var color: Color {
        switch self {
        case .idle: return Color(hex: "6B7280")
        case .thinking: return Color(hex: "F59E0B")
        case .coding: return Color(hex: "10B981")
        case .success: return Color(hex: "10B981")
        case .failed: return Color(hex: "EF4444")
        case .sleeping: return Color(hex: "3B82F6")
        }
    }

    var animationDuration: Double {
        switch self {
        case .idle: return 3.0
        case .thinking: return 1.5
        case .coding: return 0.3
        case .success: return 0.5
        case .failed: return 2.0
        case .sleeping: return 3.0
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
