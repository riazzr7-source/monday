import Foundation
import Security

public enum AIProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case openAI = "OpenAI"
    case gemini = "Google Gemini"

    public var id: String { rawValue }

    public var keychainAccount: String {
        switch self {
        case .openAI: return "openai_api_key"
        case .gemini: return "gemini_api_key"
        }
    }
}

public protocol KeychainManagerProtocol: Sendable {
    func saveKey(_ key: String, for provider: AIProvider) throws
    func getKey(for provider: AIProvider) throws -> String?
    func deleteKey(for provider: AIProvider) throws
    func hasKey(for provider: AIProvider) -> Bool
    func getMaskedKey(for provider: AIProvider) -> String?

    // Legacy backwards compatibility
    func saveAPIKey(_ key: String) throws
    func getAPIKey() throws -> String?
    func deleteAPIKey() throws
    func hasAPIKey() -> Bool
    func getMaskedAPIKey() -> String?
}

public final class KeychainManager: KeychainManagerProtocol, @unchecked Sendable {
    public static let shared = KeychainManager()

    private let service: String

    public init(service: String = "com.monday.assistant") {
        self.service = service
    }

    public func saveKey(_ key: String, for provider: AIProvider) throws {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else {
            try deleteKey(for: provider)
            return
        }

        let data = Data(trimmedKey.utf8)
        let account = provider.keychainAccount

        let queryDelete: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(queryDelete as CFDictionary)

        let queryAdd: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(queryAdd as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw MondayError.unknown("Failed to save to Keychain (status: \(status))")
        }
    }

    public func getKey(for provider: AIProvider) throws -> String? {
        let account = provider.keychainAccount
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess, let data = item as? Data, let key = String(data: data, encoding: .utf8) else {
            throw MondayError.unknown("Failed to read from Keychain (status: \(status))")
        }

        return key
    }

    public func deleteKey(for provider: AIProvider) throws {
        let account = provider.keychainAccount
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw MondayError.unknown("Failed to delete from Keychain (status: \(status))")
        }
    }

    public func hasKey(for provider: AIProvider) -> Bool {
        guard let key = try? getKey(for: provider), !key.isEmpty else {
            return false
        }
        return true
    }

    public func getMaskedKey(for provider: AIProvider) -> String? {
        guard let key = try? getKey(for: provider), !key.isEmpty else {
            return nil
        }
        if key.count <= 8 {
            return "••••••••"
        }
        let prefix = key.prefix(4)
        let suffix = key.suffix(4)
        return "\(prefix)••••••••\(suffix)"
    }

    // OpenAI Backwards Compatibility shortcuts
    public func saveAPIKey(_ key: String) throws {
        try saveKey(key, for: .openAI)
    }

    public func getAPIKey() throws -> String? {
        return try getKey(for: .openAI)
    }

    public func deleteAPIKey() throws {
        try deleteKey(for: .openAI)
    }

    public func hasAPIKey() -> Bool {
        return hasKey(for: .openAI)
    }

    public func getMaskedAPIKey() -> String? {
        return getMaskedKey(for: .openAI)
    }
}
