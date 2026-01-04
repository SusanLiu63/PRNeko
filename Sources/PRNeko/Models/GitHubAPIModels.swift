import Foundation

// MARK: - GraphQL Response Wrapper

struct GraphQLResponse<T: Decodable>: Decodable {
    let data: T?
    let errors: [GraphQLError]?
}

struct GraphQLError: Decodable {
    let message: String
    let locations: [GraphQLErrorLocation]?
    let path: [String]?
}

struct GraphQLErrorLocation: Decodable {
    let line: Int
    let column: Int
}

// MARK: - Authored PRs Response

struct AuthoredPRsResponse: Decodable {
    let search: SearchResult
}

struct SearchResult: Decodable {
    let nodes: [GitHubPR]?
}

// MARK: - Single PR Response

struct SinglePRResponse: Decodable {
    let repository: RepositoryResult?
}

struct RepositoryResult: Decodable {
    let pullRequest: GitHubPR?
}

// MARK: - GitHub PR Model

struct GitHubPR: Decodable {
    let id: String
    let number: Int
    let title: String
    let url: String
    let createdAt: String
    let isDraft: Bool
    let repository: Repository
    let commits: CommitConnection?
    let reviewDecision: ReviewDecision?
    let mergeable: MergeableState?

    struct Repository: Decodable {
        let nameWithOwner: String
    }

    struct CommitConnection: Decodable {
        let nodes: [CommitNode]?
    }

    struct CommitNode: Decodable {
        let commit: Commit
    }

    struct Commit: Decodable {
        let statusCheckRollup: StatusCheckRollup?
    }

    struct StatusCheckRollup: Decodable {
        let state: CheckStatusState
    }
}

// MARK: - Enums

enum MergeableState: String, Decodable {
    case mergeable = "MERGEABLE"
    case conflicting = "CONFLICTING"
    case unknown = "UNKNOWN"
}

enum ReviewDecision: String, Decodable {
    case approved = "APPROVED"
    case changesRequested = "CHANGES_REQUESTED"
    case reviewRequired = "REVIEW_REQUIRED"
}

enum CheckStatusState: String, Decodable {
    case success = "SUCCESS"
    case failure = "FAILURE"
    case error = "ERROR"
    case pending = "PENDING"
    case expected = "EXPECTED"
}

// MARK: - GraphQL Request

struct GraphQLRequest: Encodable {
    let query: String
    let variables: [String: String]?

    init(query: String, variables: [String: String]? = nil) {
        self.query = query
        self.variables = variables
    }
}
