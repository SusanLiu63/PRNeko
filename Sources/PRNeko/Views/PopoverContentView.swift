import SwiftUI

struct PopoverContentView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showSettings = false

    var body: some View {
        Group {
            switch viewModel.authState {
            case .loggedOut, .awaitingUserAuth:
                LoginView(viewModel: viewModel)

            case .loggedIn:
                mainContentView
            }
        }
    }

    private var mainContentView: some View {
        VStack(spacing: 0) {
            // Header
            HeaderView(viewModel: viewModel)
                .padding(.horizontal, 12)
                .padding(.top, 12)

            Divider()
                .padding(.vertical, 8)

            // Show Settings or Queue Sections
            if showSettings {
                SettingsView(viewModel: viewModel)
                    .frame(maxHeight: 300)
            } else {
                // Queue Sections
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(QueueType.allCases) { queueType in
                            if queueType == .pendingReviews {
                                QueueSectionView(
                                    queueType: queueType,
                                    items: viewModel.items(for: queueType),
                                    onAddPR: { url in
                                        Task {
                                            await viewModel.addPendingReviewURL(url)
                                        }
                                    },
                                    onRemovePR: { id in
                                        viewModel.removePendingReview(id: id)
                                    },
                                    onMarkPRReviewed: { id in
                                        viewModel.removePendingReview(id: id)
                                    }
                                )
                            } else {
                                QueueSectionView(
                                    queueType: queueType,
                                    items: viewModel.items(for: queueType)
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .frame(maxHeight: 300)
            }

            Divider()
                .padding(.top, 8)

            // Footer
            footerView
        }
        .frame(width: 340)
    }

    private var footerView: some View {
        HStack {
            // Refresh button
            Button(action: {
                Task {
                    await viewModel.refreshPRs()
                }
            }) {
                HStack(spacing: 4) {
                    if viewModel.isFetching {
                        ProgressView()
                            .scaleEffect(0.6)
                            .frame(width: 12, height: 12)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10))
                    }
                    Text("Refresh")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isFetching)

            Spacer()

            // Mock indicator (when PRNEKO_MOCK=1)
            if viewModel.mockMode {
                HStack(spacing: 4) {
                    Image(systemName: "testtube.2")
                        .font(.system(size: 10))
                    Text("Mock")
                        .font(.system(size: 11))
                }
                .foregroundColor(.orange)
            }

            // Error indicator
            if let error = viewModel.lastGitHubError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 10))
                    .help(error)
            }

            // Settings gear icon (toggle)
            Button(action: { showSettings.toggle() }) {
                Image(systemName: showSettings ? "xmark.circle.fill" : "gearshape.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
    }
}
