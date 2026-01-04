import Foundation
import SwiftUI
import Combine
import os

private let logger = Logger(subsystem: "com.prneko", category: "app")

@MainActor
class AppViewModel: ObservableObject {
    // MARK: - Animation State
    @Published var animationState: AnimationState = .mood(.idle)

    // MARK: - Queues
    @Published var pendingReviews: [PRItem] = []
    @Published var waitingForReview: [PRItem] = []
    @Published var mergeReady: [PRItem] = []
    @Published var blocked: [PRItem] = []

    // MARK: - GitHub API
    private let apiClient = GitHubAPIClient()
    private let authService = GitHubAuthService()
    @Published var lastGitHubError: String?
    @Published var isFetching: Bool = false

    // MARK: - Authentication
    @Published var authState: AuthState = .loggedOut
    @Published var authError: String?
    @Published var isAuthenticating: Bool = false
    private var authTask: Task<Void, Never>?

    // MARK: - Polling
    private var pollingTask: Task<Void, Never>?
    private let pollingInterval: UInt64 = 180 // 3 minutes in seconds

    // MARK: - Settings
    @Published var mockMode: Bool
    @Published var quietHours: Bool {
        didSet { UserDefaults.standard.set(quietHours, forKey: "settings.quietHours") }
    }

    // MARK: - Pending Review Persistence
    private let pendingReviewURLsKey = "pendingReviews.urls"

    // MARK: - Computed Properties
    var mood: Mood {
        if !blocked.isEmpty {
            return .anxious
        }
        if !mergeReady.isEmpty {
            return .excited
        }
        if !pendingReviews.isEmpty {
            return .hungry  // Waiting for you to review
        }
        return .idle
    }

    var totalActionableItems: Int {
        pendingReviews.count + waitingForReview.count + mergeReady.count + blocked.count
    }

    // MARK: - Initialization
    init() {
        // Enable mock mode with: PRNEKO_MOCK=1 .build/arm64-apple-macosx/debug/PRNeko
        let mockModeFromEnv = ProcessInfo.processInfo.environment["PRNEKO_MOCK"] == "1"
        self.mockMode = mockModeFromEnv
        self.quietHours = UserDefaults.standard.bool(forKey: "settings.quietHours")

        // Check for stored credentials
        Task {
            await checkStoredCredentials()
        }

        if mockMode {
            loadMockData()
        }

        // Set initial animation state based on mood
        updateAnimationForMood()
    }

    private func checkStoredCredentials() async {
        if let credentials = await authService.getStoredCredentials() {
            authState = .loggedIn(username: credentials.username)
            // Start auto-polling and fetch PRs
            startPolling()
            await refreshPRs()
            // Load persisted pending reviews
            await loadPendingReviewsFromStorage()
        }
    }

    // MARK: - Animation Control
    func updateAnimationForMood() {
        animationState = .mood(mood)
    }

    // MARK: - Debug Actions
    func clearBlocked() {
        blocked = []
        updateAnimationForMood()
    }

    func clearAllQueues() {
        pendingReviews = []
        waitingForReview = []
        mergeReady = []
        blocked = []
        updateAnimationForMood()
    }

    func resetAll() {
        quietHours = false
        mockMode = false
        clearQueues()
    }

    func toggleMockMode() {
        mockMode.toggle()
        if mockMode {
            loadMockData()
        } else {
            clearQueues()
        }
    }

    // MARK: - Mock Data
    func loadMockData() {
        let now = Date()

        pendingReviews = [
            PRItem(
                id: "pr-1",
                title: "Fix authentication bug in login flow",
                repo: "acme/backend",
                status: .passing,
                createdAt: now.addingTimeInterval(-2 * 3600),
                url: "https://github.com/acme/backend/pull/123"
            ),
            PRItem(
                id: "pr-2",
                title: "Add unit tests for user service",
                repo: "acme/backend",
                status: .pending,
                createdAt: now.addingTimeInterval(-24 * 3600),
                url: "https://github.com/acme/backend/pull/124"
            )
        ]

        waitingForReview = [
            PRItem(
                id: "pr-5",
                title: "Add user profile page with avatar upload",
                repo: "acme/frontend",
                status: .passing,
                createdAt: now.addingTimeInterval(-6 * 3600),
                url: "https://github.com/acme/frontend/pull/789"
            )
        ]

        mergeReady = [
            PRItem(
                id: "pr-3",
                title: "Implement dark mode toggle",
                repo: "acme/frontend",
                status: .passing,
                createdAt: now.addingTimeInterval(-3 * 3600),
                url: "https://github.com/acme/frontend/pull/456"
            )
        ]

        blocked = [
            PRItem(
                id: "pr-4",
                title: "Refactor API error handling",
                repo: "acme/backend",
                status: .failing,
                createdAt: now.addingTimeInterval(-5 * 3600),
                url: "https://github.com/acme/backend/pull/125"
            )
        ]

        updateAnimationForMood()
    }

    func refreshMockData() {
        loadMockData()
    }

    private func clearQueues() {
        pendingReviews = []
        waitingForReview = []
        mergeReady = []
        blocked = []
        updateAnimationForMood()
    }

    // MARK: - Queue Helpers
    func items(for queueType: QueueType) -> [PRItem] {
        switch queueType {
        case .pendingReviews: return pendingReviews
        case .waitingForReview: return waitingForReview
        case .mergeReady: return mergeReady
        case .blocked: return blocked
        }
    }

    // MARK: - GitHub API Integration

    /// Fetches the user's authored PRs and updates all queues.
    func fetchAuthoredPRs(token: String, username: String) async {
        guard !isFetching else { return }

        isFetching = true
        lastGitHubError = nil

        do {
            let (waiting, ready, blockedPRs) = try await apiClient.fetchAuthoredPRs(token: token, username: username)
            self.waitingForReview = waiting
            self.mergeReady = ready
            self.blocked = blockedPRs
            updateAnimationForMood()
        } catch {
            lastGitHubError = error.localizedDescription
            logger.error("GitHub fetch error: \(error.localizedDescription)")
        }

        isFetching = false
    }

    /// Manually adds a PR to the pending reviews queue by URL.
    func addPendingReview(token: String, url: String) async {
        lastGitHubError = nil

        do {
            let item = try await apiClient.fetchPR(token: token, url: url)
            // Avoid duplicates
            if !pendingReviews.contains(where: { $0.id == item.id }) {
                pendingReviews.append(item)
                updateAnimationForMood()
            }
        } catch {
            lastGitHubError = error.localizedDescription
            logger.error("Failed to add PR: \(error.localizedDescription)")
        }
    }

    /// Adds a pending review by URL with persistence.
    func addPendingReviewURL(_ url: String) async {
        guard case .loggedIn = authState,
              let credentials = await authService.getStoredCredentials() else {
            return
        }

        // Add URL to persisted list
        var urls = getPendingReviewURLs()
        let normalizedURL = url.trimmingCharacters(in: .whitespaces)
        if !urls.contains(normalizedURL) {
            urls.append(normalizedURL)
            savePendingReviewURLs(urls)
        }

        // Fetch and add the PR
        await addPendingReview(token: credentials.token, url: normalizedURL)
    }

    /// Removes a PR from the pending reviews queue.
    func removePendingReview(id: String) {
        // Find the URL for this PR before removing
        if let item = pendingReviews.first(where: { $0.id == id }) {
            var urls = getPendingReviewURLs()
            urls.removeAll { $0 == item.url }
            savePendingReviewURLs(urls)
        }

        pendingReviews.removeAll { $0.id == id }
        updateAnimationForMood()
    }

    /// Loads persisted pending review URLs and fetches their data.
    private func loadPendingReviewsFromStorage() async {
        guard case .loggedIn = authState,
              let credentials = await authService.getStoredCredentials() else {
            return
        }

        let urls = getPendingReviewURLs()
        for url in urls {
            await addPendingReview(token: credentials.token, url: url)
        }
    }

    private func getPendingReviewURLs() -> [String] {
        UserDefaults.standard.stringArray(forKey: pendingReviewURLsKey) ?? []
    }

    private func savePendingReviewURLs(_ urls: [String]) {
        UserDefaults.standard.set(urls, forKey: pendingReviewURLsKey)
    }

    /// Fetches authored PRs using stored credentials.
    func refreshPRs() async {
        guard case .loggedIn(let username) = authState,
              let credentials = await authService.getStoredCredentials() else {
            return
        }
        await fetchAuthoredPRs(token: credentials.token, username: username)
    }

    // MARK: - Polling

    /// Starts auto-polling for PR updates every 3 minutes.
    private func startPolling() {
        stopPolling()

        pollingTask = Task {
            while !Task.isCancelled {
                // Wait for the polling interval
                try? await Task.sleep(nanoseconds: pollingInterval * 1_000_000_000)

                if Task.isCancelled { break }

                // Skip if already fetching
                guard !isFetching else { continue }

                await refreshPRs()
            }
        }
    }

    /// Stops auto-polling.
    private func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    // MARK: - Authentication

    /// Starts the OAuth Device Flow login process.
    func startLogin() async {
        guard !isAuthenticating else { return }

        isAuthenticating = true
        authError = nil

        do {
            // Step 1: Get device code from GitHub
            let deviceCode = try await authService.requestDeviceCode()

            // Step 2: Show code to user and open browser
            authState = .awaitingUserAuth(
                userCode: deviceCode.userCode,
                verificationURL: deviceCode.verificationUri
            )
            authService.openVerificationURL(deviceCode.verificationUri)

            // Step 3: Poll for access token in background
            authTask = Task {
                var pollInterval = deviceCode.interval

                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: UInt64(pollInterval) * 1_000_000_000)

                    if Task.isCancelled { break }

                    do {
                        let result = try await authService.pollForAccessToken(deviceCode: deviceCode.deviceCode)

                        switch result {
                        case .success(let accessToken):
                            // Got the token! Fetch user info and complete login
                            let user = try await authService.fetchUser(token: accessToken)
                            await authService.storeCredentials(token: accessToken, username: user.login)

                            await MainActor.run {
                                self.authState = .loggedIn(username: user.login)
                                self.isAuthenticating = false
                                self.authError = nil
                                // Start auto-polling now that we're logged in
                                self.startPolling()
                            }

                            // Fetch PRs now that we're logged in
                            await self.refreshPRs()
                            // Load persisted pending reviews
                            await self.loadPendingReviewsFromStorage()
                            return

                        case .pending:
                            // User hasn't authorized yet, keep polling
                            continue

                        case .slowDown:
                            // Increase poll interval
                            pollInterval += 5
                            continue
                        }
                    } catch {
                        await MainActor.run {
                            self.authState = .loggedOut
                            self.authError = error.localizedDescription
                            self.isAuthenticating = false
                        }
                        return
                    }
                }
            }
        } catch {
            authState = .loggedOut
            authError = error.localizedDescription
            isAuthenticating = false
        }
    }

    /// Cancels an in-progress login.
    func cancelLogin() {
        authTask?.cancel()
        authTask = nil
        authState = .loggedOut
        authError = nil
        isAuthenticating = false
    }

    /// Logs out and clears stored credentials.
    func logout() async {
        stopPolling()
        await authService.clearCredentials()
        authState = .loggedOut
        clearQueues()
    }
}
