import Foundation
import Combine

public enum TestStatus: Equatable, Sendable {
    case success(String)
    case failure(String)
}

@MainActor
public final class SettingsManager: ObservableObject {
    @Published public var hasOpenAIKey: Bool = false
    @Published public var maskedOpenAIKey: String? = nil

    @Published public var hasGeminiKey: Bool = false
    @Published public var maskedGeminiKey: String? = nil

    @Published public var selectedModel: String {
        didSet {
            UserDefaults.standard.set(selectedModel, forKey: "monday_selected_model")
        }
    }

    @Published public var isTestingConnection: Bool = false
    @Published public var testResult: [AIProvider: TestStatus] = [:]

    private let keychain: KeychainManagerProtocol
    private let openAIClient: OpenAIClientProtocol
    private let geminiClient: GeminiClientProtocol

    public init(
        keychain: KeychainManagerProtocol = KeychainManager.shared,
        openAIClient: OpenAIClientProtocol = OpenAIClient.shared,
        geminiClient: GeminiClientProtocol = GeminiClient.shared
    ) {
        self.keychain = keychain
        self.openAIClient = openAIClient
        self.geminiClient = geminiClient

        let saved = UserDefaults.standard.string(forKey: "monday_selected_model")
        if let savedModel = saved, !savedModel.isEmpty, savedModel != "gemini-2.5-flash" {
            self.selectedModel = savedModel
        } else {
            self.selectedModel = "gemini-2.0-flash"
        }

        refreshKeyState()
        autoSelectAvailableModel()
    }

    public var currentProvider: AIProvider {
        if selectedModel.hasPrefix("gemini") {
            return .gemini
        }
        return .openAI
    }

    public var hasAnyConfiguredKey: Bool {
        hasGeminiKey || hasOpenAIKey
    }

    public var hasConfiguredKey: Bool {
        hasKey(for: currentProvider)
    }

    public var maskedKey: String? {
        getMaskedKey(for: currentProvider)
    }

    public func hasKey(for provider: AIProvider) -> Bool {
        keychain.hasKey(for: provider)
    }

    public func getMaskedKey(for provider: AIProvider) -> String? {
        keychain.getMaskedKey(for: provider)
    }

    public func refreshKeyState() {
        self.hasOpenAIKey = keychain.hasKey(for: .openAI)
        self.maskedOpenAIKey = keychain.getMaskedKey(for: .openAI)

        self.hasGeminiKey = keychain.hasKey(for: .gemini)
        self.maskedGeminiKey = keychain.getMaskedKey(for: .gemini)
    }

    public func autoSelectAvailableModel() {
        if !hasKey(for: currentProvider) {
            if hasGeminiKey {
                selectedModel = "gemini-2.0-flash"
            } else if hasOpenAIKey {
                selectedModel = "gpt-4o-mini"
            }
        }
    }

    public func saveKey(_ key: String, for provider: AIProvider) throws {
        try keychain.saveKey(key, for: provider)
        refreshKeyState()
        testResult[provider] = nil
        autoSelectAvailableModel()
    }

    public func deleteKey(for provider: AIProvider) throws {
        try keychain.deleteKey(for: provider)
        refreshKeyState()
        testResult[provider] = nil
        autoSelectAvailableModel()
    }

    public func getKey(for provider: AIProvider) throws -> String? {
        return try keychain.getKey(for: provider)
    }

    public func getKeyForCurrentModel() throws -> String? {
        return try getKey(for: currentProvider)
    }

    public func testConnection(for provider: AIProvider, customKey: String? = nil) async {
        isTestingConnection = true
        testResult[provider] = nil

        let keyToTest: String
        if let custom = customKey, !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            keyToTest = custom
        } else if let saved = try? keychain.getKey(for: provider), !saved.isEmpty {
            keyToTest = saved
        } else {
            isTestingConnection = false
            testResult[provider] = .failure("No API key provided to test.")
            return
        }

        do {
            let success: Bool
            switch provider {
            case .openAI:
                success = try await openAIClient.testConnection(apiKey: keyToTest)
            case .gemini:
                success = try await geminiClient.testConnection(apiKey: keyToTest)
            }

            if success {
                testResult[provider] = .success("\(provider.rawValue) connected successfully!")
            } else {
                testResult[provider] = .failure("Connection failed.")
            }
        } catch {
            testResult[provider] = .failure(error.localizedDescription)
        }

        isTestingConnection = false
    }

    // OpenAI Backwards Compatibility
    public func saveKey(_ key: String) throws {
        try saveKey(key, for: .openAI)
    }

    public func deleteKey() throws {
        try deleteKey(for: .openAI)
    }

    public func getRawKey() throws -> String? {
        return try getKey(for: currentProvider)
    }
}
