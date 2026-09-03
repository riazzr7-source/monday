import SwiftUI
import MondayCore

public struct ComposerView: View {
    @Binding public var text: String
    public let isStreaming: Bool
    public let onSend: (String) -> Void
    public let onStop: () -> Void
    public let onNewChat: () -> Void

    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        isStreaming: Bool,
        onSend: @escaping (String) -> Void,
        onStop: @escaping () -> Void,
        onNewChat: @escaping () -> Void
    ) {
        self._text = text
        self.isStreaming = isStreaming
        self.onSend = onSend
        self.onStop = onStop
        self.onNewChat = onNewChat
    }

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isStreaming
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 10) {
                // New Conversation Button [+]
                Button(action: onNewChat) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(
                            Circle()
                                .fill(Color.primary.opacity(0.05))
                        )
                }
                .buttonStyle(.plain)
                .help("New Conversation (Cmd+N)")

                // Multiline Input
                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text("Ask Monday...")
                            .font(.system(size: 14.5))
                            .foregroundColor(Theme.textTertiary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 5)
                            .allowsHitTesting(false)
                    }

                    TextField("", text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 14.5))
                        .lineLimit(1...6)
                        .focused($isFocused)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 5)
                        .onKeyPress(.return) {
                            if NSEvent.modifierFlags.contains(.shift) {
                                return .ignored
                            } else {
                                handleSend()
                                return .handled
                            }
                        }
                }

                // Send [↑] or Stop [■] button
                if isStreaming {
                    Button(action: onStop) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(Color.red.opacity(0.85))
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Stop generating")
                } else {
                    Button(action: handleSend) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(canSend ? .white : Theme.textTertiary)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(canSend ? Color.primary : Color.primary.opacity(0.06))
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSend)
                    .help("Send message (Return)")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cornerRadiusLarge, style: .continuous)
                    .stroke(Theme.subtleBorder, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .onAppear {
            isFocused = true
        }
    }

    private func handleSend() {
        guard canSend else { return }
        let toSend = text
        text = ""
        onSend(toSend)
    }
}
