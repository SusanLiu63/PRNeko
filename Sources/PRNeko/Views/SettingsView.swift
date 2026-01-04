import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Account section
                accountSection

                Divider()

                // Preferences section
                preferencesSection

                #if DEBUG
                Divider()

                // Debug section
                debugSection
                #endif
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "person.circle")
                    .font(.system(size: 10))
                Text("Account")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.secondary)

            if case .loggedIn(let username) = viewModel.authState {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(username)
                            .font(.system(size: 12, weight: .medium))
                        Text("Connected to GitHub")
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                    }

                    Spacer()

                    Button("Logout") {
                        Task {
                            await viewModel.logout()
                        }
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.red)
                }
                .padding(8)
                .background(Color.primary.opacity(0.03))
                .cornerRadius(6)
            } else {
                Text("Not logged in")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Preferences Section

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "gearshape")
                    .font(.system(size: 10))
                Text("Preferences")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                Toggle("Quiet Hours", isOn: $viewModel.quietHours)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(.system(size: 11))

                Text("Pause notifications during quiet hours")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .padding(8)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(6)
        }
    }

    #if DEBUG
    // MARK: - Debug Section

    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: "ladybug")
                    .font(.system(size: 10))
                Text("Debug")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Mock Mode", isOn: Binding(
                        get: { viewModel.mockMode },
                        set: { _ in viewModel.toggleMockMode() }
                    ))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(.system(size: 11))

                    Text("Use mock data instead of GitHub API")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 8) {
                    Button("Clear Blocked") {
                        viewModel.clearBlocked()
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Clear All") {
                        viewModel.clearAllQueues()
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Reset") {
                        viewModel.resetAll()
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(8)
            .background(Color.primary.opacity(0.03))
            .cornerRadius(6)
        }
    }
    #endif
}
