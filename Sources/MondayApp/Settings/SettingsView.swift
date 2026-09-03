import SwiftUI
import MondayCore

public struct SettingsView: View {
    @ObservedObject public var settings: SettingsManager
    @Environment(\.dismiss) private var dismiss

    @State private var inputOpenAIKey: String = ""
    @State private var isOpenAIRevealed: Bool = false

    @State private var inputGeminiKey: String = ""
    @State private var isGeminiRevealed: Bool = false

    @State private var statusMessage: String? = nil
    @State private var isError: Bool = false
    @State private var providerToDelete: AIProvider? = nil

    public init(settings: SettingsManager) {
        self.settings = settings
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Settings")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Google Gemini Section
                    providerSection(
                        title: "Google Gemini API Key",
                        subtitle: "Used for Gemini 2.5 Flash, 2.5 Pro, and 1.5 models.",
                        placeholder: "AIza...",
                        provider: .gemini,
                        inputKey: $inputGeminiKey,
                        isRevealed: $isGeminiRevealed,
                        hasKey: settings.hasGeminiKey,
                        maskedKey: settings.maskedGeminiKey
                    )

                    Divider()

                    // OpenAI Section
                    providerSection(
                        title: "OpenAI API Key",
                        subtitle: "Used for GPT-4o Mini, GPT-4o, and GPT-3.5 models.",
                        placeholder: "sk-...",
                        provider: .openAI,
                        inputKey: $inputOpenAIKey,
                        isRevealed: $isOpenAIRevealed,
                        hasKey: settings.hasOpenAIKey,
                        maskedKey: settings.maskedOpenAIKey
                    )

                    Divider()

                    // Model Selection Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Default Active Model")
                            .font(.system(size: 13, weight: .semibold))

                        Picker("", selection: $settings.selectedModel) {
                            Section("Google Gemini") {
                                ForEach(ModelOption.defaults.filter { $0.provider == .gemini }) { option in
                                    Text("\(option.displayName) — \(option.description)").tag(option.id)
                                }
                            }
                            Section("OpenAI") {
                                ForEach(ModelOption.defaults.filter { $0.provider == .openAI }) { option in
                                    Text("\(option.displayName) — \(option.description)").tag(option.id)
                                }
                            }
                        }
                        .pickerStyle(.radioGroup)
                    }

                    if let status = statusMessage {
                        Text(status)
                            .font(.system(size: 12))
                            .foregroundColor(isError ? .red : .green)
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 520, height: 560)
        .confirmationDialog(
            "Remove API Key?",
            isPresented: Binding(
                get: { providerToDelete != nil },
                set: { if !$0 { providerToDelete = nil } }
            )
        ) {
            if let provider = providerToDelete {
                Button("Remove \(provider.rawValue) Key", role: .destructive) {
                    deleteKey(for: provider)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let provider = providerToDelete {
                Text("Are you sure you want to remove your \(provider.rawValue) API key from the Keychain?")
            }
        }
    }

    @ViewBuilder
    private func providerSection(
        title: String,
        subtitle: String,
        placeholder: String,
        provider: AIProvider,
        inputKey: Binding<String>,
        isRevealed: Binding<Bool>,
        hasKey: Bool,
        maskedKey: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))

            Text(subtitle)
                .font(.system(size: 11.5))
                .foregroundColor(Theme.textSecondary)

            if hasKey && inputKey.wrappedValue.isEmpty {
                HStack {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 13))

                    Text("Configured: ")
                        .font(.system(size: 12.5))
                        .foregroundColor(Theme.textSecondary)

                    Text(maskedKey ?? "••••••••")
                        .font(.system(size: 12.5, design: .monospaced))
                        .foregroundColor(Theme.textPrimary)

                    Spacer()

                    Button("Remove") {
                        providerToDelete = provider
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                        .fill(Color.primary.opacity(0.04))
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(hasKey ? "Update Key" : "Enter Key")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(Theme.textSecondary)

                HStack {
                    if isRevealed.wrappedValue {
                        TextField(placeholder, text: inputKey)
                            .textFieldStyle(.plain)
                    } else {
                        SecureField(placeholder, text: inputKey)
                            .textFieldStyle(.plain)
                    }

                    Button(action: { isRevealed.wrappedValue.toggle() }) {
                        Image(systemName: isRevealed.wrappedValue ? "eye.slash" : "eye")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.cornerRadiusSmall)
                        .stroke(Theme.subtleBorder, lineWidth: 1)
                )
            }

            HStack(spacing: 10) {
                Button("Save Key") {
                    saveKey(for: provider, key: inputKey.wrappedValue)
                    inputKey.wrappedValue = ""
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(inputKey.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button(action: {
                    testConnection(for: provider, inputKey: inputKey.wrappedValue)
                }) {
                    if settings.isTestingConnection {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text("Test Connection")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(settings.isTestingConnection || (!hasKey && inputKey.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))

                Spacer()
            }

            if let testResult = settings.testResult[provider] {
                switch testResult {
                case .success(let msg):
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(msg)
                            .foregroundColor(.green)
                    }
                    .font(.system(size: 12))
                case .failure(let msg):
                    HStack(spacing: 6) {
                        Image(systemName: "xmark.octagon.fill")
                            .foregroundColor(.red)
                        Text(msg)
                            .foregroundColor(.red)
                    }
                    .font(.system(size: 12))
                }
            }
        }
    }

    private func saveKey(for provider: AIProvider, key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try settings.saveKey(trimmed, for: provider)
            statusMessage = "\(provider.rawValue) key saved securely."
            isError = false
        } catch {
            statusMessage = "Failed to save \(provider.rawValue) key: \(error.localizedDescription)"
            isError = true
        }
    }

    private func deleteKey(for provider: AIProvider) {
        do {
            try settings.deleteKey(for: provider)
            statusMessage = "\(provider.rawValue) key removed."
            isError = false
        } catch {
            statusMessage = "Failed to delete key: \(error.localizedDescription)"
            isError = true
        }
    }

    private func testConnection(for provider: AIProvider, inputKey: String) {
        let trimmed = inputKey.trimmingCharacters(in: .whitespacesAndNewlines)
        Task {
            await settings.testConnection(for: provider, customKey: trimmed.isEmpty ? nil : trimmed)
        }
    }
}
