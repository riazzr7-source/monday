import Foundation

public protocol LocalStorageManagerProtocol: Sendable {
    func loadConversations() throws -> [Conversation]
    func saveConversations(_ conversations: [Conversation]) throws
    func loadActiveConversation() throws -> Conversation?
    func saveActiveConversation(_ conversation: Conversation) throws
    func clearAll() throws
}

public final class LocalStorageManager: LocalStorageManagerProtocol, @unchecked Sendable {
    public static let shared = LocalStorageManager()

    private let storageURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let lock = NSLock()

    public init(customDirectory: URL? = nil) {
        let baseDir: URL
        if let custom = customDirectory {
            baseDir = custom
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            baseDir = appSupport.appendingPathComponent("Monday", isDirectory: true)
        }

        try? FileManager.default.createDirectory(at: baseDir, withIntermediateDirectories: true)
        self.storageURL = baseDir.appendingPathComponent("conversations.json")

        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder.dateEncodingStrategy = .iso8601

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
    }

    public func loadConversations() throws -> [Conversation] {
        lock.lock()
        defer { lock.unlock() }

        guard FileManager.default.fileExists(atPath: storageURL.path) else {
            return []
        }

        do {
            let data = try Data(contentsOf: storageURL)
            if data.isEmpty {
                return []
            }
            let conversations = try decoder.decode([Conversation].self, from: data)
            return conversations
        } catch {
            return []
        }
    }

    public func saveConversations(_ conversations: [Conversation]) throws {
        lock.lock()
        defer { lock.unlock() }

        let data = try encoder.encode(conversations)
        try data.write(to: storageURL, options: [.atomic])
    }

    public func loadActiveConversation() throws -> Conversation? {
        let all = try loadConversations()
        return all.first
    }

    public func saveActiveConversation(_ conversation: Conversation) throws {
        var all = try loadConversations()
        if let index = all.firstIndex(where: { $0.id == conversation.id }) {
            all[index] = conversation
        } else {
            all.insert(conversation, at: 0)
        }
        try saveConversations(all)
    }

    public func clearAll() throws {
        lock.lock()
        defer { lock.unlock() }

        if FileManager.default.fileExists(atPath: storageURL.path) {
            try FileManager.default.removeItem(at: storageURL)
        }
    }
}
