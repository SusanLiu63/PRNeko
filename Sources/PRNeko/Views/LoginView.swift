import SwiftUI

struct LoginView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack(spacing: 20) {
            // Pet image
            Image(systemName: "pawprint.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)
                .padding(.top, 40)

            Text("GitHub Pet")
                .font(.title)
                .fontWeight(.bold)

            Text("Connect your GitHub account to track your PRs")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)

            Spacer()

            // Content based on auth state
            switch viewModel.authState {
            case .loggedOut:
                loginButton

            case .awaitingUserAuth(let userCode, _):
                awaitingAuthView(userCode: userCode)

            case .loggedIn:
                EmptyView()
            }

            Spacer()

            // Error message
            if let error = viewModel.authError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }

            // Footer
            Text("Your data stays local. We only read your PR status.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.bottom, 20)
        }
        .frame(width: 300, height: 420)
    }

    private var loginButton: some View {
        Button(action: {
            Task {
                await viewModel.startLogin()
            }
        }) {
            HStack {
                Image(systemName: "person.badge.key.fill")
                Text("Login with GitHub")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.accentColor)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 40)
        .disabled(viewModel.isAuthenticating)
    }

    private func awaitingAuthView(userCode: String) -> some View {
        VStack(spacing: 16) {
            Text("Enter this code on GitHub:")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // User code display
            HStack(spacing: 4) {
                ForEach(Array(userCode.enumerated()), id: \.offset) { index, char in
                    if char == "-" {
                        Text("-")
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                    } else {
                        Text(String(char))
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .frame(width: 28, height: 40)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                    }
                }
            }

            Button("Copy Code") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(userCode, forType: .string)
            }
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
            .font(.caption)

            HStack(spacing: 8) {
                ProgressView()
                    .scaleEffect(0.7)
                Text("Waiting for authorization...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button("Cancel") {
                viewModel.cancelLogin()
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .font(.caption)
            .padding(.top, 4)
        }
        .padding(.horizontal, 20)
    }
}
