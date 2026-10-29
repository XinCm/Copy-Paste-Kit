import SwiftUI

struct ClipboardPanelView: View {
    @ObservedObject var state: PanelState
    let onChoose: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard")
                Text("CopyKit").fontWeight(.semibold)
                Spacer()
                Text("\(state.entries.count) / 6")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)

            if state.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clipboard").font(.system(size: 30)).foregroundStyle(.secondary)
                    Text("No clipboard history yet").fontWeight(.medium)
                    Text("Copy some text or an image to get started.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)
            } else {
                VStack(spacing: 4) {
                    ForEach(Array(state.entries.enumerated()), id: \.element.id) { index, entry in
                        Button {
                            onChoose(index)
                        } label: {
                            ClipboardRow(entry: entry, index: index, selected: state.selectedIndex == index)
                        }
                        .buttonStyle(.plain)
                        .onHover { hovering in if hovering { state.selectedIndex = index } }
                        .accessibilityLabel("\(index + 1). \(entry.accessibilitySummary)")
                        .accessibilityHint("Copy this item and close the panel")
                    }
                }
            }

            if let message = state.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 6)
            }

            HStack {
                Text(state.isDemo ? "Preview only · Clipboard unchanged" : "1–6 to copy · ↑↓ and Return")
                Spacer()
                Text("Esc to close")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
        }
        .padding(14)
        .frame(width: 370)
        .background(PanelMaterial())
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.primary.opacity(0.10), lineWidth: 0.5))
        .fixedSize(horizontal: true, vertical: true)
    }
}

private struct ClipboardRow: View {
    let entry: ClipboardEntry
    let index: Int
    let selected: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index + 1)")
                .font(.system(.body, design: .rounded).weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            switch entry.content {
            case .text(let text):
                Text(String(text.prefix(300)))
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .image(_, _, let thumbnail, let width, let height):
                if let image = NSImage(data: thumbnail) {
                    Image(nsImage: image)
                        .resizable().scaledToFit()
                        .frame(width: 64, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Image").font(.system(size: 13, weight: .medium))
                    Text("\(width) × \(height)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 60)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(selected ? Color.accentColor.opacity(0.14) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }
}

private struct PanelMaterial: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
