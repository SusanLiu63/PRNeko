import Foundation

enum QueueType: String, CaseIterable, Identifiable {
    case pendingReviews
    case waitingForReview
    case mergeReady
    case blocked

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pendingReviews: return "Pending Reviews"
        case .waitingForReview: return "Waiting for Review"
        case .mergeReady: return "Merge-ready"
        case .blocked: return "Blocked"
        }
    }

    var subtitle: String? {
        switch self {
        case .mergeReady: return "Likely"
        default: return nil
        }
    }

    var iconName: String {
        switch self {
        case .pendingReviews: return "eye.fill"
        case .waitingForReview: return "clock.badge.questionmark"
        case .mergeReady: return "checkmark.diamond.fill"
        case .blocked: return "hand.raised.fill"
        }
    }
}
