import Foundation

enum GitHubError: Error, LocalizedError {
    case unauthorized
    case forbidden
    case rateLimited(resetDate: Date)
    case networkError(Error)
    case graphQLErrors([GraphQLError])
    case invalidResponse
    case invalidPRURL
    case noData

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Invalid or expired token (401)"
        case .forbidden:
            return "Access denied - check token scopes (403)"
        case .rateLimited(let resetDate):
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .abbreviated
            return "Rate limited - retry \(formatter.localizedString(for: resetDate, relativeTo: Date()))"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .graphQLErrors(let errors):
            return errors.first?.message ?? "GraphQL error"
        case .invalidResponse:
            return "Invalid server response"
        case .invalidPRURL:
            return "Invalid PR URL format. Expected: https://github.com/owner/repo/pull/123"
        case .noData:
            return "No data returned from GitHub"
        }
    }

    var isRetryable: Bool {
        switch self {
        case .networkError, .rateLimited:
            return true
        case .unauthorized, .forbidden, .invalidPRURL:
            return false
        default:
            return true
        }
    }
}
