import Foundation

/// Parsed command segment from a piped command
struct CommandSegment: Sendable, Equatable {
    let command: String
    let args: [String]
    let index: Int  // Position in pipeline

    var isDirectoryChange: Bool {
        command == "cd" || command == "pushd" || command == "popd"
    }

    var isVersionControl: Bool {
        command == "git" || command == "hg" || command == "svn"
    }

    var isBareCommand: Bool {
        // Bare 'cd' without args has different meaning
        command == "cd" && args.isEmpty
    }
}

/// Parser for bash commands with security analysis
struct BashCommandParser: Sendable {
    /// Segments a piped command into individual components
    static func segment(_ command: String) -> [CommandSegment] {
        let parts = command.components(separatedBy: "|").map { $0.trimmingCharacters(in: .whitespaces) }

        return parts.enumerated().compactMap { index, part in
            let tokens = tokenizeCommand(part)
            guard !tokens.isEmpty else { return nil }

            let cmd = tokens[0]
            let args = Array(tokens.dropFirst())

            return CommandSegment(command: cmd, args: args, index: index)
        }
    }

    /// Detects dangerous patterns across segments
    /// Returns security issues (e.g., cd followed by git in a pipe)
    static func detectSecurityIssues(segments: [CommandSegment]) -> [SecurityIssue] {
        var issues: [SecurityIssue] = []

        // Pattern: cd in one segment followed by git in another
        // This prevents the "bare repo fsmonitor" bypass where cd changes context
        // and git operates in a different directory than intended
        for i in 0..<segments.count {
            let segment = segments[i]

            if segment.isDirectoryChange {
                // Look for git operations in subsequent segments
                for j in (i+1)..<segments.count {
                    let nextSegment = segments[j]
                    if nextSegment.isVersionControl {
                        issues.append(
                            SecurityIssue(
                                severity: .warning,
                                message: "Directory change (\(segment.command)) followed by version control (\(nextSegment.command)) in pipe",
                                affectedSegments: [i, j]
                            )
                        )
                    }
                }
            }
        }

        return issues
    }

    /// Checks if command is safe to execute
    static func isSafe(
        _ command: String,
        allowedPaths: [String]? = nil
    ) -> (safe: Bool, issues: [SecurityIssue]) {
        let segments = segment(command)
        var issues = detectSecurityIssues(segments: segments)

        // Check directory changes against allowed paths
        if let allowedPaths = allowedPaths {
            for segment in segments {
                if segment.isDirectoryChange {
                    let targetPath = segment.args.first ?? "~"
                    if !isPathAllowed(targetPath, in: allowedPaths) {
                        issues.append(
                            SecurityIssue(
                                severity: .error,
                                message: "Directory change to \(targetPath) is outside allowed paths",
                                affectedSegments: [segment.index]
                            )
                        )
                    }
                }
            }
        }

        return (safe: issues.isEmpty, issues: issues)
    }

    // MARK: - Private Helpers

    private static func tokenizeCommand(_ commandString: String) -> [String] {
        var tokens: [String] = []
        var currentToken = ""
        var inSingleQuote = false
        var inDoubleQuote = false
        var i = commandString.startIndex

        while i < commandString.endIndex {
            let char = commandString[i]

            switch char {
            case "'" where !inDoubleQuote:
                inSingleQuote.toggle()
            case "\"" where !inSingleQuote:
                inDoubleQuote.toggle()
            case " ", "\t" where !inSingleQuote && !inDoubleQuote:
                if !currentToken.isEmpty {
                    tokens.append(currentToken)
                    currentToken = ""
                }
            default:
                currentToken.append(char)
            }

            i = commandString.index(after: i)
        }

        if !currentToken.isEmpty {
            tokens.append(currentToken)
        }

        return tokens
    }

    private static func isPathAllowed(_ path: String, in allowedPaths: [String]) -> Bool {
        let expandedPath: String
        if path.starts(with: "~") {
            expandedPath = NSHomeDirectory() + String(path.dropFirst())
        } else if path.starts(with: "/") {
            expandedPath = path
        } else {
            expandedPath = FileManager.default.currentDirectoryPath + "/" + path
        }

        let expandedURL = URL(fileURLWithPath: expandedPath)

        for allowedPath in allowedPaths {
            let allowedURL = URL(fileURLWithPath: allowedPath)
            if expandedURL.standardizedFileURL.path.hasPrefix(allowedURL.standardizedFileURL.path) {
                return true
            }
        }

        return false
    }
}

// MARK: - Security Issue Reporting

enum SecuritySeverity: String, Sendable {
    case info
    case warning
    case error
}

struct SecurityIssue: Sendable, Equatable {
    let severity: SecuritySeverity
    let message: String
    let affectedSegments: [Int]
}
