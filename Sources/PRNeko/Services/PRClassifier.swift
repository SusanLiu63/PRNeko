import Foundation

struct PRClassifier {

    // MARK: - Classify Authored PR

    /// Classifies an authored PR into merge-ready, waiting for review, or blocked queue.
    /// Returns nil if the PR should not be shown (e.g., draft PRs).
    static func classifyAuthored(_ ghPR: GitHubPR) -> (item: PRItem, queue: QueueType)? {
        // Skip draft PRs
        guard !ghPR.isDraft else { return nil }

        let item = toPRItem(ghPR)

        // Determine if blocked (failing checks, conflicts, changes requested)
        if isBlocked(ghPR) {
            return (item, .blocked)
        }

        // Determine if merge-ready (all checks passing, approved or no review required)
        if isMergeReady(ghPR) {
            return (item, .mergeReady)
        }

        // Determine if waiting for review (not blocked, not merge-ready, awaiting reviews)
        if isWaitingForReview(ghPR) {
            return (item, .waitingForReview)
        }

        // PR is in an indeterminate state (e.g., pending checks)
        // Default to waiting for review since it's not actively blocked
        return (item, .waitingForReview)
    }

    // MARK: - Convert to PRItem

    /// Converts a GitHub PR to the app's PRItem model.
    static func toPRItem(_ ghPR: GitHubPR) -> PRItem {
        PRItem(
            id: ghPR.id,
            title: ghPR.title,
            repo: ghPR.repository.nameWithOwner,
            status: mapCheckStatus(ghPR),
            createdAt: parseISO8601(ghPR.createdAt),
            url: ghPR.url
        )
    }

    // MARK: - Private Helpers

    private static func isBlocked(_ ghPR: GitHubPR) -> Bool {
        // Condition 1: Failing checks
        if let rollup = ghPR.commits?.nodes?.first?.commit.statusCheckRollup {
            if rollup.state == .failure || rollup.state == .error {
                return true
            }
        }

        // Condition 2: Merge conflicts
        if ghPR.mergeable == .conflicting {
            return true
        }

        // Condition 3: Changes requested (active blocker from reviewer)
        if ghPR.reviewDecision == .changesRequested {
            return true
        }

        return false
    }

    private static func isWaitingForReview(_ ghPR: GitHubPR) -> Bool {
        // Not blocked, not merge-ready, and waiting for reviews
        // reviewDecision is nil when no reviews exist yet, or REVIEW_REQUIRED when reviews are required
        let decision = ghPR.reviewDecision
        return decision == nil || decision == .reviewRequired
    }

    private static func isMergeReady(_ ghPR: GitHubPR) -> Bool {
        // Must not be a draft
        guard !ghPR.isDraft else { return false }

        // Checks must be passing (or no checks configured)
        if let rollup = ghPR.commits?.nodes?.first?.commit.statusCheckRollup {
            guard rollup.state == .success else { return false }
        }

        // No merge conflicts
        if ghPR.mergeable == .conflicting {
            return false
        }

        // Review decision should be approved (or no reviews required)
        // reviewDecision is nil if no branch protection rules require reviews
        if let decision = ghPR.reviewDecision {
            guard decision == .approved else { return false }
        }

        return true
    }

    private static func mapCheckStatus(_ ghPR: GitHubPR) -> PRStatus {
        guard let rollup = ghPR.commits?.nodes?.first?.commit.statusCheckRollup else {
            // No checks configured = nothing blocking, treat as passing
            return .passing
        }

        switch rollup.state {
        case .success:
            return .passing
        case .failure, .error:
            return .failing
        case .pending, .expected:
            return .pending
        }
    }

    private static func parseISO8601(_ dateString: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateString) {
            return date
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateString) ?? Date()
    }
}
