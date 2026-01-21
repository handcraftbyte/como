import Foundation

/// Shared error type for JavaScript-based language services
enum JSLanguageServiceError: Error, LocalizedError {
    case contextCreationFailed
    case scriptLoadFailed(String)
    case bridgeNotAvailable
    case notInitialized

    var errorDescription: String? {
        switch self {
        case .contextCreationFailed:
            return "Failed to create JavaScript context"
        case .scriptLoadFailed(let script):
            return "Failed to load script: \(script)"
        case .bridgeNotAvailable:
            return "Language service bridge not available"
        case .notInitialized:
            return "Language service not initialized"
        }
    }
}
