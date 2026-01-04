import SwiftUI

struct QueueSectionView: View {
    let queueType: QueueType
    let items: [PRItem]
    var onAddPR: ((String) -> Void)? = nil
    var onRemovePR: ((String) -> Void)? = nil
    var onMarkPRReviewed: ((String) -> Void)? = nil
    @State private var isExpanded: Bool = true
    @State private var prURLInput: String = ""
    @State private var isAddingPR: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: 12)

                    Image(systemName: queueType.iconName)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    Text(queueType.displayName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("(\(items.count))")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    if let subtitle = queueType.subtitle {
                        Text("[\(subtitle)]")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.orange)
                    }

                    Spacer()

                    // Add button for pending reviews
                    if queueType == .pendingReviews && onAddPR != nil {
                        Button(action: { isAddingPR.toggle() }) {
                            Image(systemName: isAddingPR ? "xmark" : "plus")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 4) {
                    // URL input field for pending reviews
                    if queueType == .pendingReviews && isAddingPR {
                        HStack(spacing: 6) {
                            TextField("Paste PR URL...", text: $prURLInput)
                                .textFieldStyle(.plain)
                                .font(.system(size: 11))
                                .padding(6)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(4)
                                .onSubmit {
                                    addPR()
                                }

                            Button(action: addPR) {
                                Text("Add")
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .disabled(prURLInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                        .padding(.leading, 16)
                        .padding(.trailing, 4)
                        .padding(.bottom, 4)
                    }

                    ForEach(items) { item in
                        if queueType == .pendingReviews {
                            PRRowView(
                                item: item,
                                onRemove: onRemovePR != nil ? { onRemovePR?(item.id) } : nil,
                                onMarkReviewed: onMarkPRReviewed != nil ? { onMarkPRReviewed?(item.id) } : nil
                            )
                        } else {
                            PRRowView(item: item)
                        }
                    }
                }
                .padding(.leading, 16)
                .padding(.bottom, 8)
            }
        }
    }

    private func addPR() {
        let url = prURLInput.trimmingCharacters(in: .whitespaces)
        guard !url.isEmpty else { return }
        onAddPR?(url)
        prURLInput = ""
        isAddingPR = false
    }
}
