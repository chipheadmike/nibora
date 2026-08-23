//
//  AskNiboraView.swift
//  Nibora
//

import SwiftUI
import FoundationModels

/// A single-question, single-answer window onto JournalQueryService — not a
/// multi-turn chat, deliberately kept simple for a first pass.
struct AskNiboraView: View {
    let entries: [JournalEntryRecord]

    @Environment(\.dismiss) private var dismiss
    @Environment(AIProviderPreferences.self) private var aiProviderPreferences
    @State private var question = ""
    @State private var answer: String?
    @State private var isAsking = false
    @State private var errorMessage: String?

    /// Recomputed on every access rather than cached, so switching
    /// providers in Settings while this sheet is open (or just reopening
    /// it later) always reflects the currently-selected one.
    private var queryService: JournalQueryService {
        JournalQueryService(preferences: aiProviderPreferences)
    }

    private var unavailableReason: String? {
        queryService.checkAvailability()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Ask Your Journal")
                    .font(.title2.bold())
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding()

            Divider()

            if let unavailableReason {
                ContentUnavailableView(
                    "\(aiProviderPreferences.selectedProvider.label) Unavailable",
                    systemImage: "sparkles",
                    description: Text(unavailableReason)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let answer {
                            Text(answer)
                                .textSelection(.enabled)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color.secondary.opacity(0.1)))
                        }
                        if let errorMessage {
                            Text(errorMessage)
                                .foregroundStyle(.red)
                                .font(.caption)
                        }
                        if isAsking {
                            ProgressView("Thinking…")
                        }
                        if answer == nil && errorMessage == nil && !isAsking {
                            Text("Ask anything about your journal — e.g. \"What have I said about work stress this year?\" \(providerPrivacyNote)")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Divider()

                HStack {
                    TextField("Ask something about your journal…", text: $question)
                        .textFieldStyle(.plain)
                        .onSubmit { ask() }
                    Button("Ask") { ask() }
                        .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || isAsking)
                }
                .padding(12)
            }
        }
        .frame(width: 480, height: 480)
    }

    private var providerPrivacyNote: String {
        switch aiProviderPreferences.selectedProvider {
        case .onDevice: return "Everything runs on-device; nothing leaves this Mac."
        case .claude: return "Your question and relevant journal excerpts are sent to Anthropic's Claude API."
        case .chatGPT: return "Your question and relevant journal excerpts are sent to OpenAI's ChatGPT API."
        }
    }

    private func ask() {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isAsking = true
        errorMessage = nil
        answer = nil
        Task {
            do {
                answer = try await queryService.ask(trimmed, entries: entries)
            } catch let error as LanguageModelSession.GenerationError {
                if case .guardrailViolation = error {
                    errorMessage = "The on-device model declined to answer — its built-in safety filter triggered even though this looks like an ordinary question. This is a known limitation of the current Apple Intelligence beta, not a Nibora issue, and there's no way to disable it from here. It should loosen up in future macOS updates; try rephrasing, or try again later."
                } else {
                    errorMessage = "Something went wrong answering that: \(error.localizedDescription)"
                }
            } catch {
                errorMessage = "Something went wrong answering that: \(error.localizedDescription)"
            }
            isAsking = false
        }
    }
}
