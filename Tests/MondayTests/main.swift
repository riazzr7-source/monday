import Foundation
import MondayCore

final class MockKeychain: KeychainManagerProtocol, @unchecked Sendable {
    private var storage: [AIProvider: String] = [:]

    func saveKey(_ key: String, for provider: AIProvider) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        storage[provider] = trimmed.isEmpty ? nil : trimmed
    }

    func getKey(for provider: AIProvider) throws -> String? {
        return storage[provider]
    }

    func deleteKey(for provider: AIProvider) throws {
        storage[provider] = nil
    }

    func hasKey(for provider: AIProvider) -> Bool {
        return storage[provider] != nil && !storage[provider]!.isEmpty
    }

    func getMaskedKey(for provider: AIProvider) -> String? {
        guard let key = storage[provider], !key.isEmpty else { return nil }
        if key.count <= 8 { return "••••••••" }
        return "\(key.prefix(4))••••••••\(key.suffix(4))"
    }

    func saveAPIKey(_ key: String) throws { try saveKey(key, for: .openAI) }
    func getAPIKey() throws -> String? { try getKey(for: .openAI) }
    func deleteAPIKey() throws { try deleteKey(for: .openAI) }
    func hasAPIKey() -> Bool { hasKey(for: .openAI) }
    func getMaskedAPIKey() -> String? { getMaskedKey(for: .openAI) }
}

@main
struct MondayTestRunner {
    @MainActor
    static func main() async {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("  MONDAY Stage 1 — Automated Test Suite")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        var passed = 0
        var failed = 0

        func runTest(_ name: String, block: () async throws -> Void) async {
            do {
                try await block()
                print("  ✓ [PASS] \(name)")
                passed += 1
            } catch {
                print("  ✗ [FAIL] \(name): \(error.localizedDescription)")
                failed += 1
            }
        }

        // Test 1: LocalStorageManager
        await runTest("LocalStorage: Save, Reload, and Clear conversation") {
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDir) }

            let storage = LocalStorageManager(customDirectory: tempDir)

            let initial = try storage.loadConversations()
            assert(initial.isEmpty, "Initial state should be empty")

            var conversation = Conversation(title: "Test Chat")
            conversation.messages.append(Message(role: .user, content: "Hello Monday"))
            conversation.messages.append(Message(role: .assistant, content: "Hello! How can I help you today?"))

            try storage.saveActiveConversation(conversation)

            let reloaded = try storage.loadConversations()
            assert(reloaded.count == 1, "Expected 1 conversation")
            assert(reloaded.first?.title == "Test Chat", "Title mismatch")
            assert(reloaded.first?.messages.count == 2, "Message count mismatch")

            try storage.clearAll()
            let cleared = try storage.loadConversations()
            assert(cleared.isEmpty, "Storage should be empty after clear")
        }

        // Test 2: SettingsManager & Multi-Provider Keychain
        await runTest("SettingsManager: Multi-Provider Keychain (Gemini & OpenAI)") {
            let mockKeychain = MockKeychain()
            let settings = SettingsManager(keychain: mockKeychain)

            // Test Gemini
            assert(!settings.hasGeminiKey, "Gemini key should not exist initially")
            try settings.saveKey("AIzaSyB1234567890qwertyuiopasdfghjkl", for: .gemini)
            assert(settings.hasGeminiKey, "Gemini key should exist")
            assert(settings.maskedGeminiKey == "AIza••••••••hjkl", "Masked Gemini key incorrect: \(String(describing: settings.maskedGeminiKey))")

            // Test OpenAI
            assert(!settings.hasOpenAIKey, "OpenAI key should not exist initially")
            try settings.saveKey("sk-test1234567890abcdef", for: .openAI)
            assert(settings.hasOpenAIKey, "OpenAI key should exist")
            assert(settings.maskedOpenAIKey == "sk-t••••••••cdef", "Masked OpenAI key incorrect")

            // Test Deletion
            try settings.deleteKey(for: .gemini)
            assert(!settings.hasGeminiKey, "Gemini key should be removed")
            assert(settings.hasOpenAIKey, "OpenAI key should still exist")
        }

        // Test 3: Gemini & OpenAI JSON Serialization
        await runTest("AI Models: Gemini & OpenAI Request / Response JSON serialization") {
            // OpenAI Request
            let openAIPayload = ChatCompletionRequest(
                model: "gpt-4o-mini",
                messages: [ChatMessagePayload(role: "user", content: "Hi")],
                stream: true
            )
            let encodedOpenAI = try JSONEncoder().encode(openAIPayload)
            let decodedOpenAI = try JSONDecoder().decode(ChatCompletionRequest.self, from: encodedOpenAI)
            assert(decodedOpenAI.model == "gpt-4o-mini")

            // Gemini Request
            let geminiPayload = GeminiGenerateContentRequest(
                contents: [GeminiContent(role: "user", parts: [GeminiPart(text: "Hello Gemini")])],
                systemInstruction: GeminiContent(role: nil, parts: [GeminiPart(text: "You are Monday")])
            )
            let encodedGemini = try JSONEncoder().encode(geminiPayload)
            let decodedGemini = try JSONDecoder().decode(GeminiGenerateContentRequest.self, from: encodedGemini)
            assert(decodedGemini.contents.first?.parts.first?.text == "Hello Gemini")
            assert(decodedGemini.systemInstruction?.parts.first?.text == "You are Monday")

            // Gemini SSE Chunk
            let sseChunkJson = """
            {
                "candidates": [
                    {
                        "content": {
                            "parts": [
                                { "text": "Hello from Gemini!" }
                            ],
                            "role": "model"
                        },
                        "finishReason": "STOP"
                    }
                ]
            }
            """
            let chunkData = Data(sseChunkJson.utf8)
            let chunk = try JSONDecoder().decode(GeminiResponseChunk.self, from: chunkData)
            assert(chunk.candidates?.first?.content?.parts?.first?.text == "Hello from Gemini!")
        }

        // Test 4: Live macOS Keychain with multiple accounts
        await runTest("Real macOS Keychain: Multi-account isolation") {
            let testService = "com.monday.test.\(UUID().uuidString)"
            let realKeychain = KeychainManager(service: testService)

            try? realKeychain.deleteKey(for: .gemini)
            try? realKeychain.deleteKey(for: .openAI)

            try realKeychain.saveKey("AIzaSyGeminiKey12345678", for: .gemini)
            try realKeychain.saveKey("sk-proj-OpenAIKey123456", for: .openAI)

            assert(realKeychain.hasKey(for: .gemini))
            assert(realKeychain.hasKey(for: .openAI))

            let geminiKey = try realKeychain.getKey(for: .gemini)
            let openAIKey = try realKeychain.getKey(for: .openAI)

            assert(geminiKey == "AIzaSyGeminiKey12345678")
            assert(openAIKey == "sk-proj-OpenAIKey123456")

            try realKeychain.deleteKey(for: .gemini)
            assert(!realKeychain.hasKey(for: .gemini))
            assert(realKeychain.hasKey(for: .openAI))

            try realKeychain.deleteKey(for: .openAI)
            assert(!realKeychain.hasKey(for: .openAI))
        }

        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("  Summary: \(passed) passed, \(failed) failed")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")

        if failed > 0 {
            exit(1)
        }
    }
}
