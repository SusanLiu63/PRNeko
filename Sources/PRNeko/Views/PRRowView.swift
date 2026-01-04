import SwiftUI

struct PRRowView: View {
    let item: PRItem
    var onRemove: (() -> Void)? = nil
    var onMarkReviewed: (() -> Void)? = nil
    @State private var isHovering: Bool = false
    @State private var isMarkingReviewed: Bool = false

    var body: some View {
        Button(action: openURL) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(2)
                        .strikethrough(isMarkingReviewed, color: .secondary)

                    HStack(spacing: 6) {
                        Text(item.repo)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        HStack(spacing: 2) {
                            Image(systemName: item.status.iconName)
                                .font(.system(size: 9))
                                .foregroundColor(statusColor)
                            Text(item.status.displayName)
                                .font(.system(size: 10))
                                .foregroundColor(statusColor)
                        }

                        Text(item.age)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Action buttons (shown on hover for pending reviews)
                if isHovering && !isMarkingReviewed {
                    HStack(spacing: 4) {
                        // Checkmark button for marking as reviewed
                        if onMarkReviewed != nil {
                            Button(action: markAsReviewed) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.green)
                            }
                            .buttonStyle(.plain)
                        }

                        // Remove button
                        if let onRemove = onRemove {
                            Button(action: {
                                onRemove()
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .opacity(isMarkingReviewed ? 0 : 1)
        }
        .buttonStyle(.plain)
        .background(Color.primary.opacity(0.03))
        .cornerRadius(6)
        .onHover { hovering in
            isHovering = hovering
        }
        .disabled(isMarkingReviewed)
    }

    private func markAsReviewed() {
        withAnimation(.easeOut(duration: 0.4)) {
            isMarkingReviewed = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            onMarkReviewed?()
        }
    }

    private var statusColor: Color {
        switch item.status {
        case .passing: return .green
        case .failing: return .red
        case .pending: return .orange
        }
    }

    private func openURL() {
        if let url = URL(string: item.url) {
            NSWorkspace.shared.open(url)
        }
    }
}
