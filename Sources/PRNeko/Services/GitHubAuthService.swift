import Foundation
import AppKit
import Security

// MARK: - Keychain Helper

struct KeychainHelper {
    private static let service = "com.prneko.oauth"
    private static let account = "github_access_token"

    static func saveToken(_ token: String) -> Bool {
        guard let data = token.data(using: .utf8) else { return false }

        // Delete any existing item first
        deleteToken()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    static func getToken() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }

        return token
    }

    @discardableResult
    static func deleteToken() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    /// Migrates token from UserDefaults to Keychain (one-time migration)
    static func migrateFromUserDefaults() {
        let legacyKey = "github.accessToken"
        if let legacyToken = UserDefaults.standard.string(forKey: legacyKey), !legacyToken.isEmpty {
            // Token exists in UserDefaults, migrate to Keychain
            if saveToken(legacyToken) {
                // Successfully migrated, remove from UserDefaults
                UserDefaults.standard.removeObject(forKey: legacyKey)
            }
        }
    }
}

// MARK: - Auth State

enum AuthState: Equatable {
    case loggedOut
    case awaitingUserAuth(userCode: String, verificationURL: String)
    case loggedIn(username: String)
}

// MARK: - Device Flow Response Models

struct DeviceCodeResponse: Decodable {
    let deviceCode: String
    let userCode: String
    let verificationUri: String
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

struct AccessTokenResponse: Decodable {
    let accessToken: String?
    let tokenType: String?
    let scope: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case scope
        case error
    }
}

struct GitHubUser: Decodable {
    let login: String
    let id: Int
    let avatarUrl: String?

    enum CodingKeys: String, CodingKey {
        case login
        case id
        case avatarUrl = "avatar_url"
    }
}

// MARK: - Auth Service

actor GitHubAuthService {
    // ============================================================
    /// GitHub OAuth App Client ID
    /// In release builds, set via GITHUB_CLIENT_ID environment variable
    private let clientId: String = {
        if let envClientId = ProcessInfo.processInfo.environment["GITHUB_CLIENT_ID"],
           !envClientId.isEmpty {
            return envClientId
        }
        #if DEBUG
        // Development Client ID - safe to use during development
        return "Ov23lidFJvN4oykuFMaW"
        #else
        fatalError("GITHUB_CLIENT_ID environment variable must be set for release builds")
        #endif
    }()

    private let deviceCodeURL = URL(string: "https://github.com/login/device/code")!
    private let accessTokenURL = URL(string: "https://github.com/login/oauth/access_token")!
    private let userURL = URL(string: "https://api.github.com/user")!

    private let session: URLSession

    // Storage keys
    private let usernameKey = "github.username"

    init(session: URLSession = .shared) {
        self.session = session
        // Run migration from UserDefaults to Keychain (one-time)
        KeychainHelper.migrateFromUserDefaults()
    }

    // MARK: - Public API

    /// Checks if user is already logged in
    func getStoredCredentials() -> (token: String, username: String)? {
        guard let token = KeychainHelper.getToken(),
              let username = UserDefaults.standard.string(forKey: usernameKey),
              !token.isEmpty else {
            return nil
        }
        return (token, username)
    }

    /// Step 1: Request a device code from GitHub
    func requestDeviceCode() async throws -> DeviceCodeResponse {
        var request = URLRequest(url: deviceCodeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(clientId)&scope=repo read:user"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.deviceFlowFailed
        }

        return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
    }

    /// Step 2: Open the verification URL in the browser
    nonisolated func openVerificationURL(_ urlString: String) {
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Step 3: Poll for access token (called repeatedly until success or error)
    func pollForAccessToken(deviceCode: String) async throws -> PollResult {
        var request = URLRequest(url: accessTokenURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body = "client_id=\(clientId)&device_code=\(deviceCode)&grant_type=urn:ietf:params:oauth:grant-type:device_code"
        request.httpBody = body.data(using: .utf8)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.tokenRequestFailed
        }

        let tokenResponse = try JSONDecoder().decode(AccessTokenResponse.self, from: data)

        if let accessToken = tokenResponse.accessToken {
            return .success(accessToken)
        }

        if let error = tokenResponse.error {
            switch error {
            case "authorization_pending":
                return .pending
            case "slow_down":
                return .slowDown
            case "expired_token":
                throw AuthError.codeExpired
            case "access_denied":
                throw AuthError.accessDenied
            default:
                throw AuthError.unknown(error)
            }
        }

        return .pending
    }

    /// Fetches the authenticated user's info
    func fetchUser(token: String) async throws -> GitHubUser {
        var request = URLRequest(url: userURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw AuthError.userFetchFailed
        }

        return try JSONDecoder().decode(GitHubUser.self, from: data)
    }

    /// Stores credentials after successful login
    func storeCredentials(token: String, username: String) {
        _ = KeychainHelper.saveToken(token)
        UserDefaults.standard.set(username, forKey: usernameKey)
    }

    /// Clears stored credentials (logout)
    func clearCredentials() {
        KeychainHelper.deleteToken()
        UserDefaults.standard.removeObject(forKey: usernameKey)
    }
}

// MARK: - Poll Result

enum PollResult {
    case success(String)  // Access token
    case pending          // User hasn't authorized yet
    case slowDown         // Need to slow down polling
}

// MARK: - Auth Errors

enum AuthError: Error, LocalizedError {
    case deviceFlowFailed
    case tokenRequestFailed
    case codeExpired
    case accessDenied
    case userFetchFailed
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .deviceFlowFailed:
            return "Failed to start GitHub login. Please try again."
        case .tokenRequestFailed:
            return "Failed to complete login. Please try again."
        case .codeExpired:
            return "Login code expired. Please try again."
        case .accessDenied:
            return "Access denied. Please try again and click 'Authorize'."
        case .userFetchFailed:
            return "Failed to get user info. Please try again."
        case .unknown(let msg):
            return "Login error: \(msg)"
        }
    }
}
