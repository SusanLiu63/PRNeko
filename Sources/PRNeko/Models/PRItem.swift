import Foundation

enum PRStatus: String, Codable {
    case passing
    case failing
    case pending

    var iconName: String {
        switch self {
        case .passing: return "checkmark.circle.fill"
        case .failing: return "xmark.circle.fill"
        case .pending: return "clock.fill"
        }
    }

    var displayName: String {
        switch self {
        case .passing: return "passing"
        case .failing: return "failing"
        case .pending: return "pending"
        }
    }
}

struct PRItem: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let repo: String
    let status: PRStatus
    let createdAt: Date
    let url: String

    var age: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
}
