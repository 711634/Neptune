import Foundation
import SwiftUI

enum AgentStatus: String, Codable, CaseIterable {
    case idle = "idle"
    case waking = "waking"
    case thinking = "thinking"
    case planning = "planning"
    case researching = "researching"
    case coding = "coding"
    case reviewing = "reviewing"
    case shipping = "shipping"
    case success = "success"
    case failed = "failed"
    case blocked = "blocked"
    case sleeping = "sleeping"

    var color: Color {
        switch self {
        case .idle: return Color(hex: "6B7280")
        case .waking: return Color(hex: "F59E0B")
        case .thinking: return Color(hex: "F59E0B")
        case .planning: return Color(hex: "8B5CF6")
        case .researching: return Color(hex: "3B82F6")
        case .coding: return Color(hex: "10B981")
        case .reviewing: return Color(hex: "F59E0B")
        case .shipping: return Color(hex: "EC4899")
        case .success: return Color(hex: "10B981")
        case .failed: return Color(hex: "EF4444")
        case .blocked: return Color(hex: "8B5CF6")
        case .sleeping: return Color(hex: "3B82F6")
        }
    }
}

enum AgentRole: String, Codable, CaseIterable {
    case planning = "planning"
    case research = "research"
    case coding = "coding"
    case review = "review"
    case shipping = "shipping"

    var displayName: String {
        switch self {
        case .planning: return "PLANNING"
        case .research: return "RESEARCH"
        case .coding: return "CODING"
        case .review: return "REVIEW"
        case .shipping: return "SHIPPING"
        }
    }

    var emoji: String {
        switch self {
        case .planning: return "🧠"
        case .research: return "🔍"
        case .coding: return "💻"
        case .review: return "👀"
        case .shipping: return "🚀"
        }
    }

    var badgeColor: String {
        switch self {
        case .planning: return "8B5CF6"
        case .research: return "3B82F6"
        case .coding: return "10B981"
        case .review: return "F59E0B"
        case .shipping: return "EC4899"
        }
    }
}

enum AnchorHint: String, Codable, CaseIterable {
    case terminal = "terminal"
    case browser = "browser"
    case figma = "figma"
    case notes = "notes"
    case generic = "generic"

    var slotIndex: Int {
        switch self {
        case .terminal: return 0
        case .browser: return 1
        case .figma: return 2
        case .notes: return 3
        case .generic: return 4
        }
    }
}

struct ColorVariant: Codable, Equatable {
    let primary: String
    let secondary: String
    let accent: String

    static let green = ColorVariant(primary: "10B981", secondary: "059669", accent: "34D399")
    static let blue = ColorVariant(primary: "3B82F6", secondary: "1D4ED8", accent: "60A5FA")
    static let purple = ColorVariant(primary: "8B5CF6", secondary: "6D28D9", accent: "A78BFA")
    static let orange = ColorVariant(primary: "F59E0B", secondary: "D97706", accent: "FBBF24")
    static let pink = ColorVariant(primary: "EC4899", secondary: "DB2777", accent: "F472B6")
    static let cyan = ColorVariant(primary: "06B6D4", secondary: "0891B2", accent: "22D3EE")
    static let red = ColorVariant(primary: "EF4444", secondary: "DC2626", accent: "F87171")

    static let all: [ColorVariant] = [.green, .blue, .purple, .orange, .pink, .cyan, .red]

    var primaryColor: Color { Color(hex: primary) }
    var secondaryColor: Color { Color(hex: secondary) }
    var accentColor: Color { Color(hex: accent) }

    init(primary: String, secondary: String, accent: String) {
        self.primary = primary
        self.secondary = secondary
        self.accent = accent
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self) {
            switch stringValue {
            case "green": self = .green
            case "blue": self = .blue
            case "purple": self = .purple
            case "orange": self = .orange
            case "pink": self = .pink
            case "cyan": self = .cyan
            case "red": self = .red
            default: self = .green
            }
        } else {
            let values = try container.decode([String: String].self)
            self.primary = values["primary"] ?? "10B981"
            self.secondary = values["secondary"] ?? "059669"
            self.accent = values["accent"] ?? "34D399"
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(["primary": primary, "secondary": secondary, "accent": accent])
    }

    static func fromString(_ name: String) -> ColorVariant {
        switch name.lowercased() {
        case "green": return .green
        case "blue": return .blue
        case "purple": return .purple
        case "orange": return .orange
        case "pink": return .pink
        case "cyan": return .cyan
        case "red": return .red
        default: return .green
        }
    }
}

struct Agent: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var role: AgentRole
    var task: String
    var status: AgentStatus
    var elapsedSeconds: Int
    var lastLog: String
    var updatedAt: Date
    var colorVariant: ColorVariant
    var anchorHint: AnchorHint
    var slotIndex: Int

    // Orchestration fields
    var goal: String?  // What this agent is trying to accomplish
    var currentTaskId: String?  // Task currently assigned to this agent
    var dependencyIds: [String] = []  // Agent IDs this depends on
    var sessionLogPath: String?  // Path to transcript log file
    var workingDirectory: String?  // Project workspace path
    var skillPacksLoaded: [String] = []  // Skill IDs loaded into this agent
    var processHandle: String?  // PTY session ID reference
    var lastOutput: String?  // Most recent agent output
    var retryCount: Int = 0
    var maxRetries: Int = 3
    var startedAt: Date?  // When this agent was activated
    var errorMessage: String?  // Last error encountered
    var checkpoint: [String: String]?  // Resumption data on retry

    var formattedElapsedTime: String {
        let hours = elapsedSeconds / 3600
        let minutes = (elapsedSeconds % 3600) / 60
        let seconds = elapsedSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }

    var isRunnableState: Bool {
        status == .idle || status == .waking || status == .thinking || status == .planning || status == .researching || status == .coding
    }

    var hasFailedRecently: Bool {
        retryCount >= maxRetries && status == .failed
    }
}

struct AgentState: Codable {
    let updatedAt: Date
    var agents: [Agent]

    static var empty: AgentState {
        AgentState(updatedAt: Date(), agents: [])
    }
}
