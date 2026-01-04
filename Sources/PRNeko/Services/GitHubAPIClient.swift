import Foundation

actor GitHubAPIClient {
    private let session: URLSession
    private let baseURL = URL(string: "https://api.github.com/graphql")!

    // Rate limit tracking
    private var rateLimitRemaining: Int = 5000
    private var rateLimitReset: Date = .distantFuture

    init(session: URLSession = .shared) {
        self.session = session
    }

    // MARK: - Fetch Authored PRs

    /// Fetches the authenticated user's authored PRs and classifies them into queues.
    func fetchAuthoredPRs(token: String, username: String) async throws -> (waitingForReview: [PRItem], ready: [PRItem], blocked: [PRItem]) {
        let query = authoredPRsQuery(username: username)
        let response: AuthoredPRsResponse = try await executeQuery(query: query, token: token)

        var waitingForReview: [PRItem] = []
        var ready: [PRItem] = []
        var blocked: [PRItem] = []

        for pr in response.search.nodes ?? [] {
            if let (item, queue) = PRClassifier.classifyAuthored(pr) {
                switch queue {
                case .waitingForReview:
                    waitingForReview.append(item)
                case .mergeReady:
                    ready.append(item)
                case .blocked:
                    blocked.append(item)
                case .pendingReviews:
                    break // Authored PRs don't go to pending reviews
                }
            }
        }

        return (waitingForReview, ready, blocked)
    }

    // MARK: - Fetch Single PR

    /// Fetches a single PR by URL for manual addition to pending reviews.
    func fetchPR(token: String, url: String) async throws -> PRItem {
        let (owner, repo, number) = try parsePRURL(url)
        let query = singlePRQuery(owner: owner, repo: repo, number: number)
        let response: SinglePRResponse = try await executeQuery(query: query, token: token)

        guard let pr = response.repository?.pullRequest else {
            throw GitHubError.noData
        }

        return PRClassifier.toPRItem(pr)
    }

    // MARK: - Private: Execute GraphQL Query

    private func executeQuery<T: Decodable>(query: String, token: String) async throws -> T {
        // Check rate limit before making request
        if rateLimitRemaining <= 10 && Date() < rateLimitReset {
            throw GitHubError.rateLimited(resetDate: rateLimitReset)
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = GraphQLRequest(query: query)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubError.invalidResponse
        }

        // Update rate limit info from headers
        updateRateLimits(from: httpResponse)

        // Handle HTTP errors
        switch httpResponse.statusCode {
        case 200:
            break
        case 401:
            throw GitHubError.unauthorized
        case 403:
            if rateLimitRemaining == 0 {
                throw GitHubError.rateLimited(resetDate: rateLimitReset)
            }
            throw GitHubError.forbidden
        default:
            throw GitHubError.invalidResponse
        }

        // Parse GraphQL response
        let decoder = JSONDecoder()
        let graphQLResponse = try decoder.decode(GraphQLResponse<T>.self, from: data)

        if let errors = graphQLResponse.errors, !errors.isEmpty {
            throw GitHubError.graphQLErrors(errors)
        }

        guard let responseData = graphQLResponse.data else {
            throw GitHubError.noData
        }

        return responseData
    }

    // MARK: - Private: Rate Limit Tracking

    private func updateRateLimits(from response: HTTPURLResponse) {
        if let remaining = response.value(forHTTPHeaderField: "X-RateLimit-Remaining"),
           let remainingInt = Int(remaining) {
            rateLimitRemaining = remainingInt
        }

        if let reset = response.value(forHTTPHeaderField: "X-RateLimit-Reset"),
           let resetTimestamp = TimeInterval(reset) {
            rateLimitReset = Date(timeIntervalSince1970: resetTimestamp)
        }
    }

    // MARK: - Private: URL Parsing

    private func parsePRURL(_ urlString: String) throws -> (owner: String, repo: String, number: Int) {
        // Expected format: https://github.com/owner/repo/pull/123
        guard let url = URL(string: urlString),
              url.host == "github.com" || url.host == "www.github.com" else {
            throw GitHubError.invalidPRURL
        }

        let components = url.pathComponents.filter { $0 != "/" }
        // Should be: ["owner", "repo", "pull", "123"]
        guard components.count >= 4,
              components[2] == "pull",
              let number = Int(components[3]) else {
            throw GitHubError.invalidPRURL
        }

        return (components[0], components[1], number)
    }

    // MARK: - GraphQL Queries

    private func authoredPRsQuery(username: String) -> String {
        """
        query AuthoredPRsQuery {
          search(query: "is:pr is:open author:\(username)", type: ISSUE, first: 50) {
            nodes {
              ... on PullRequest {
                id
                number
                title
                url
                createdAt
                isDraft
                repository {
                  nameWithOwner
                }
                reviewDecision
                mergeable
                commits(last: 1) {
                  nodes {
                    commit {
                      statusCheckRollup {
                        state
                      }
                    }
                  }
                }
              }
            }
          }
        }
        """
    }

    private func singlePRQuery(owner: String, repo: String, number: Int) -> String {
        """
        query SinglePRQuery {
          repository(owner: "\(owner)", name: "\(repo)") {
            pullRequest(number: \(number)) {
              id
              number
              title
              url
              createdAt
              isDraft
              repository {
                nameWithOwner
              }
              commits(last: 1) {
                nodes {
                  commit {
                    statusCheckRollup {
                      state
                    }
                  }
                }
              }
            }
          }
        }
        """
    }
}
