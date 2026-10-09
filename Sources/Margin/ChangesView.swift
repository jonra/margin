import MarginCore
import SwiftUI

struct ChangesView: View {
    @EnvironmentObject private var review: ReviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if review.targets.isEmpty {
                Text("Not a git repository.").foregroundStyle(.secondary).padding()
                Spacer()
            } else {
                HStack {
                    Picker("Review", selection: $review.target) {
                        ForEach(review.targets) { Text($0.title).tag(Optional($0)) }
                    }
                    .labelsHidden()
                    if review.isLive {
                        Circle().fill(.green).frame(width: 8, height: 8)
                        Text("live").font(.caption).foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 6)
                List(selection: $review.selectedFileID) {
                    Section("Changes (\(review.changes.count))") {
                        ForEach(review.changes) { file in
                            ChangeRow(file: file).tag(file.id)
                        }
                    }
                    if !review.timeline.entries.isEmpty {
                        Section("Activity") {
                            ForEach(review.timeline.entries.prefix(30)) { entry in
                                HStack {
                                    Text(entry.path).lineLimit(1).truncationMode(.middle)
                                    Spacer()
                                    Text(entry.date, style: .time).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                if review.target?.allowsStaging == true {
                    CommitBox()
                }
            }
        }
    }
}

private struct ChangeRow: View {
    let file: ChangedFile

    var body: some View {
        HStack(spacing: 6) {
            Text(badge.letter)
                .font(.caption.monospaced().bold())
                .foregroundStyle(badge.color)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 0) {
                Text((file.path as NSString).lastPathComponent).lineLimit(1)
                Text((file.path as NSString).deletingLastPathComponent)
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.head)
            }
            Spacer()
            Text("+\(file.diff.additions)").font(.caption.monospaced()).foregroundStyle(.green)
            Text("−\(file.diff.deletions)").font(.caption.monospaced()).foregroundStyle(.red)
        }
    }

    private var badge: (letter: String, color: Color) {
        switch file.kind {
        case .added, .untracked: return ("A", .green)
        case .deleted: return ("D", .red)
        default: return ("M", .blue)
        }
    }
}

private struct CommitBox: View {
    @EnvironmentObject private var review: ReviewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            TextField("Commit message", text: $review.commitMessage, axis: .vertical)
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
            Button("Commit Staged") { review.commit() }
                .disabled(review.commitMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(8)
    }
}
