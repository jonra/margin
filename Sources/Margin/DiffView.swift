import MarginCore
import SwiftUI

struct DiffView: View {
    let file: ChangedFile
    @EnvironmentObject private var review: ReviewModel
    @State private var oldLines: [AttributedString] = []
    @State private var newLines: [AttributedString] = []
    @State private var confirmRevert = false
    @State private var hunkToRevert: Hunk?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if file.diff.isBinary {
                Text("Binary file — no preview.").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(review.inlineMode ? [.vertical, .horizontal] : .vertical) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(file.diff.hunks) { hunk in
                            hunkHeader(hunk)
                            if review.inlineMode {
                                ForEach(Array(hunk.lines.enumerated()), id: \.offset) { offset, line in
                                    inlineRow(line).id("\(file.id)|\(hunk.id)|i\(offset)")
                                }
                            } else {
                                ForEach(Array(SideBySide.rows(for: hunk).enumerated()), id: \.offset) { offset, row in
                                    sideBySideRow(row).id("\(file.id)|\(hunk.id)|s\(offset)")
                                }
                            }
                        }
                    }
                    .font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled)
                }
            }
        }
        .task(id: file.diff) {
            // DiffView has per-file identity (.id(file.id)), so keep current lines until the new ones are ready.
            let contents = await review.contents(of: file)
            guard !Task.isCancelled else { return }
            oldLines = Theme.highlightedLines(contents.old, path: file.path)
            newLines = Theme.highlightedLines(contents.new, path: file.path)
        }
        .confirmationDialog("Revert all changes to \(file.path)?", isPresented: $confirmRevert) {
            Button("Revert File", role: .destructive) { review.revert(file) }
        } message: {
            Text("This discards the changes on disk and cannot be undone.")
        }
        .confirmationDialog(
            "Revert the only changes to new file \(file.path)?",
            isPresented: Binding(get: { hunkToRevert != nil }, set: { if !$0 { hunkToRevert = nil } }),
            presenting: hunkToRevert
        ) { hunk in
            Button("Revert Hunk and Delete File", role: .destructive) { review.revert(hunk, in: file) }
        } message: { _ in
            Text("Reverting a hunk of a new file deletes it from disk and cannot be undone.")
        }
    }

    private var header: some View {
        HStack {
            Text(file.path).font(.headline).lineLimit(1).truncationMode(.head)
            Text("+\(file.diff.additions)").foregroundStyle(.green)
            Text("−\(file.diff.deletions)").foregroundStyle(.red)
            Spacer()
            Picker("Mode", selection: $review.inlineMode) {
                Text("Side by Side").tag(false)
                Text("Inline").tag(true)
            }
            .pickerStyle(.segmented)
            .fixedSize()
            if review.target?.allowsStaging == true {
                Button("Stage File") { review.stage(file) }
            }
            Button("Revert File…", role: .destructive) { confirmRevert = true }
        }
        .padding(8)
    }

    private func hunkHeader(_ hunk: Hunk) -> some View {
        HStack {
            Text(hunk.header).foregroundStyle(.secondary).lineLimit(1)
            Spacer()
            if review.target?.allowsStaging == true, !file.diff.isBinary {
                Button("Stage Hunk") { review.stage(hunk, in: file) }.controlSize(.small)
            }
            Button("Revert Hunk") {
                if file.diff.isNewFile { hunkToRevert = hunk } else { review.revert(hunk, in: file) }
            }.controlSize(.small)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.12))
    }

    private func sideBySideRow(_ row: SideBySideRow) -> some View {
        HStack(spacing: 0) {
            cell(row.left, number: row.left?.oldLine, lines: oldLines)
            Divider()
            cell(row.right, number: row.right?.newLine, lines: newLines)
        }
    }

    private func cell(_ line: DiffLine?, number: Int?, lines: [AttributedString]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            Text(number.map(String.init) ?? "")
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
                .padding(.trailing, 6)
            Text(line.map { content($0, number: number, lines: lines) } ?? AttributedString(""))
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(background(line?.kind))
    }

    private func inlineRow(_ line: DiffLine) -> some View {
        let number = line.kind == .removed ? line.oldLine : line.newLine
        let lines = line.kind == .removed ? oldLines : newLines
        return HStack(spacing: 0) {
            Text(line.oldLine.map(String.init) ?? "").foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
            Text(line.newLine.map(String.init) ?? "").foregroundStyle(.secondary).frame(width: 44, alignment: .trailing)
            Text(prefix(line.kind)).foregroundStyle(.secondary).frame(width: 18)
            Text(content(line, number: number, lines: lines)).fixedSize()
            Spacer(minLength: 0)
        }
        .background(background(line.kind))
    }

    private func content(_ line: DiffLine, number: Int?, lines: [AttributedString]) -> AttributedString {
        if line.kind == .noNewline { return AttributedString(line.raw) }
        // Use highlighted full-file lines only when they match the hunk's text (the file may have changed since).
        if let number, lines.indices.contains(number - 1),
           String(lines[number - 1].characters) == (line.text.hasSuffix("\r") ? String(line.text.dropLast()) : line.text) { return lines[number - 1] }
        return AttributedString(line.text)
    }

    private func prefix(_ kind: DiffLine.Kind) -> String {
        switch kind {
        case .added: return "+"
        case .removed: return "−"
        default: return ""
        }
    }

    private func background(_ kind: DiffLine.Kind?) -> Color {
        switch kind {
        case .added: return .green.opacity(0.15)
        case .removed: return .red.opacity(0.15)
        default: return .clear
        }
    }
}
