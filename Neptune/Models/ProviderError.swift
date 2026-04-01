import Foundation

/// Categorizes errors from provider execution as retryable or permanent
enum ProviderError: LocalizedError, Sendable {
    // Transient errors (retryable)
    case rateLimited(retryAfterSeconds: Int? = nil)
    case timeout(duration: TimeInterval)
    case networkUnreachable
    case temporaryFailure(reason: String)

    // Permanent errors (non-retryable)
    case invalidConfiguration(detail: String)
    case authenticationFailed(detail: String)
    case permissionDenied(detail: String)
    case invalidInput(detail: String)
    case resourceNotFound(detail: String)
    case unsupported(feature: String)
    case internalServerError(detail: String)
    case unknown(underlyingError: Error)

    var isRetryable: Bool {
        switch self {
        case .rateLimited, .timeout, .networkUnreachable, .temporaryFailure:
            return true
        case .invalidConfiguration, .authenticationFailed, .permissionDenied,
             .invalidInput, .resourceNotFound, .unsupported, .internalServerError, .unknown:
            return false
        }
    }

    var telemetryMessage: String {
        switch self {
        case .rateLimited(let retryAfter):
            return "rate_limited\(retryAfter.map { "_retry_after_\($0)s" } ?? "")"
        case .timeout(let duration):
            return "timeout_\(String(format: "%.1f", duration))s"
        case .networkUnreachable:
            return "network_unreachable"
        case .temporaryFailure(let reason):
            return "temporary_failure_\(reason.lowercased().replacingOccurrences(of: " ", with: "_"))"
        case .invalidConfiguration(let detail):
            return "invalid_configuration_\(detail.lowercased().replacingOccurrences(of: " ", with: "_"))"
        case .authenticationFailed(let detail):
            return "authentication_failed_\(detail.lowercased().replacingOccurrences(of: " ", with: "_"))"
        case .permissionDenied(let detail):
            return "permission_denied_\(detail.lowercased().replacingOccurrences(of: " ", with: "_"))"
        case .invalidInput(let detail):
            return "invalid_input_\(detail.lowercased().replacingOccurrences(of: " ", with: "_"))"
        case .resourceNotFound(let detail):
            return "resource_not_found_\(detail.lowercased().replacingOccurrences(of: " ", with: "_"))"
        case .unsupported(let feature):
            return "unsupported_\(feature.lowercased().replacingOccurrences(of: " ", with: "_"))"
        case .internalServerError(let detail):
            return "internal_server_error_\(detail.lowercased().replacingOccurrences(of: " ", with: "_"))"
        case .unknown(let error):
            return "unknown_\((error as NSError).code)"
        }
    }

    var errorDescription: String? {
        switch self {
        case .rateLimited(let retryAfter):
            let afterStr = retryAfter.map { "retry after \($0)s" } ?? "retry later"
            return "Rate limited: \(afterStr)"
        case .timeout(let duration):
            return "Request timed out after \(String(format: "%.1f", duration))s"
        case .networkUnreachable:
            return "Network is unreachable"
        case .temporaryFailure(let reason):
            return "Temporary failure: \(reason)"
        case .invalidConfiguration(let detail):
            return "Invalid configuration: \(detail)"
        case .authenticationFailed(let detail):
            return "Authentication failed: \(detail)"
        case .permissionDenied(let detail):
            return "Permission denied: \(detail)"
        case .invalidInput(let detail):
            return "Invalid input: \(detail)"
        case .resourceNotFound(let detail):
            return "Resource not found: \(detail)"
        case .unsupported(let feature):
            return "Unsupported feature: \(feature)"
        case .internalServerError(let detail):
            return "Internal server error: \(detail)"
        case .unknown(let error):
            return "Unknown error: \(error.localizedDescription)"
        }
    }
}

extension ProviderError {
    /// Classifies a generic error into a typed ProviderError
    static func classify(_ error: Error) -> ProviderError {
        // Check if already a ProviderError
        if let providerError = error as? ProviderError {
            return providerError
        }

        let nsError = error as NSError

        // Classify based on domain and code
        if nsError.domain == NSURLErrorDomain {
            switch nsError.code {
            case NSURLErrorTimedOut:
                return .timeout(duration: 30)
            case NSURLErrorNetworkConnectionLost, NSURLErrorNotConnectedToInternet:
                return .networkUnreachable
            case NSURLErrorServerCertificateUntrusted, NSURLErrorServerCertificateHasBadDate:
                return .authenticationFailed(detail: "Certificate validation failed")
            default:
                return .temporaryFailure(reason: nsError.localizedDescription)
            }
        }

        if nsError.domain == NSPOSIXErrorDomain {
            // ECONNREFUSED, ECONNRESET, EHOSTUNREACH are transient
            let errno = nsError.code
            if errno == ECONNREFUSED || errno == ECONNRESET || errno == EHOSTUNREACH {
                return .networkUnreachable
            }
            if errno == ETIMEDOUT {
                return .timeout(duration: 30)
            }
        }

        // Check error description for common patterns
        let description = nsError.localizedDescription.lowercased()

        if description.contains("timeout") || description.contains("timed out") {
            return .timeout(duration: 30)
        }

        if description.contains("rate limit") || description.contains("rate-limit") {
            return .rateLimited()
        }

        if description.contains("unauthorized") || description.contains("authentication") {
            return .authenticationFailed(detail: nsError.localizedDescription)
        }

        if description.contains("forbidden") || description.contains("permission") {
            return .permissionDenied(detail: nsError.localizedDescription)
        }

        if description.contains("not found") || description.contains("404") {
            return .resourceNotFound(detail: nsError.localizedDescription)
        }

        if description.contains("invalid") || description.contains("bad request") {
            return .invalidInput(detail: nsError.localizedDescription)
        }

        if description.contains("internal error") || description.contains("500") {
            return .internalServerError(detail: nsError.localizedDescription)
        }

        // Default: transient (safe to retry)
        return .temporaryFailure(reason: nsError.localizedDescription)
    }
}
