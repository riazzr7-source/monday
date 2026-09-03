import SwiftUI
import MondayCore

@main
struct MondayApp: App {
    var body: some Scene {
        WindowGroup {
            MainView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Conversation") {
                    NotificationCenter.default.post(name: .mondayNewChat, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}

public extension Notification.Name {
    static let mondayNewChat = Notification.Name("mondayNewChat")
}
