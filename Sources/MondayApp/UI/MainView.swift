import SwiftUI
import MondayCore

public struct MainView: View {
    @StateObject private var appState = AppState()
    @State private var inputText: String = ""

    public init() {}

    public var body: some View {
        ZStack(alignment: .top) {
            Theme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header Bar
                headerBar

                Divider()
                    .opacity(0.4)

                // Conversation Area
                ConversationView(appState: appState)

                // Composer Area
                ComposerView(
                    text: $inputText,
                    isStreaming: appState.isStreaming,
                    onSend: { text in
                        appState.sendMessage(text)
                    },
                    onStop: {
                        appState.stopStreaming()
                    },
                    onNewChat: {
                        appState.newConversation()
                    }
                )
            }
        }
        .frame(minWidth: 460, idealWidth: 540, minHeight: 520, idealHeight: 680)
        .sheet(isPresented: $appState.isSettingsOpen) {
            SettingsView(settings: appState.settings)
        }
        .onReceive(NotificationCenter.default.publisher(for: .mondayNewChat)) { _ in
            appState.newConversation()
        }
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            // Monday Branding
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.primary)
                    .frame(width: 7, height: 7)

                Text("MONDAY")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .tracking(2.0)
                    .foregroundColor(Theme.textPrimary)
            }

            Spacer()

            // Interactive Model Selector Menu
            Menu {
                Section("Google Gemini") {
                    ForEach(ModelOption.defaults.filter { $0.provider == .gemini }) { opt in
                        Button(action: {
                            appState.settings.selectedModel = opt.id
                        }) {
                            HStack {
                                Text(opt.displayName)
                                if appState.settings.selectedModel == opt.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
                Section("OpenAI") {
                    ForEach(ModelOption.defaults.filter { $0.provider == .openAI }) { opt in
                        Button(action: {
                            appState.settings.selectedModel = opt.id
                        }) {
                            HStack {
                                Text(opt.displayName)
                                if appState.settings.selectedModel == opt.id {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(appState.settings.selectedModel)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 9))
                }
                .foregroundColor(Theme.textTertiary)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.05))
                )
            }
            .menuStyle(.borderlessButton)
            .help("Select AI Model")

            // Settings Button
            Button(action: {
                appState.isSettingsOpen = true
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 26, height: 26)
                    .background(
                        Circle()
                            .fill(Color.primary.opacity(0.04))
                    )
            }
            .buttonStyle(.plain)
            .help("Settings (Cmd+,)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}
