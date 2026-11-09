//
//  FixedQuestionBuilder.swift
//  Fatum
//

import SwiftUI

/// What the provider is typing in `FixedQuestionBuilder` before tapping
/// "+ Agregar pregunta". Kept by the parent so a half-written question survives
/// step changes and can be added automatically when moving on.
struct FixedQuestionDraft {
    var question: String = ""
    var type: QuestionType = .TEXT
    var options: [String] = []
    var optionInput: String = ""

    var isEmpty: Bool {
        question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var trimmedOptionInput: String {
        optionInput.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The typed option is not blank and not already in the list (case-insensitive).
    var canAddOption: Bool {
        let trimmed = trimmedOptionInput
        return !trimmed.isEmpty
            && !options.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
    }

    mutating func addOption() {
        guard canAddOption else { return }
        options.append(trimmedOptionInput)
        optionInput = ""
    }

    /// The question this draft describes, or `nil` while it is incomplete.
    /// An option still in the input (the user forgot "Añadir") is included.
    var fixedQuestion: FixedQuestion? {
        guard !isEmpty else { return nil }
        let pending = canAddOption ? [trimmedOptionInput] : []
        let question = FixedQuestion(question: question, type: type, options: options + pending)
        if type.requiresOptions && question.options.count < FixedQuestion.minOptions {
            return nil
        }
        return question
    }
}

/// Bordered card to compose a `FixedQuestion`: the question text, its answer
/// type and, for choice types, at least `FixedQuestion.minOptions` options.
/// "+ Agregar pregunta" stays disabled until the draft is complete and not a duplicate.
struct FixedQuestionBuilder: View {
    @Binding var draft: FixedQuestionDraft
    /// Questions already added, to reject duplicates.
    let existing: [FixedQuestion]
    let onAdd: (FixedQuestion) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var newQuestion: FixedQuestion? {
        guard let question = draft.fixedQuestion, !existing.contains(question) else { return nil }
        return question
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.spacingMedium) {
            Text("NUEVA PREGUNTA")
                .fatumStyle(.footer)
                .fontWeight(.bold)
                .foregroundStyle(.text)

            LabeledTextField(
                label: "Pregunta",
                placeholder: "Ej. ¿Tienes alguna alergia?",
                text: $draft.question,
                icon: "questionmark.circle",
                maxLength: FixedQuestion.maxLength,
                showsCounter: true,
                submitLabel: .done
            )

            LabeledPicker(
                label: "Tipo de respuesta",
                options: QuestionType.allCases,
                selection: $draft.type,
                icon: "list.bullet"
            ) { $0.displayName }
            .onChange(of: draft.type) { _, newType in
                if !newType.requiresOptions {
                    draft.options = []
                    draft.optionInput = ""
                }
            }

            if draft.type.requiresOptions {
                optionsSection
            }

            Button("+ Agregar pregunta") {
                guard let newQuestion else { return }
                onAdd(newQuestion)
                draft = FixedQuestionDraft()
            }
            .buttonStyle(.fatumButton(variant: .borderedExpanded))
            .disabled(newQuestion == nil)
        }
        .padding(layout.internalPadding)
        .overlay(
            RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    // MARK: - Options

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: layout.spacingSmall) {
            Text("OPCIONES (MÍNIMO \(FixedQuestion.minOptions))")
                .fatumStyle(.footer)
                .fontWeight(.bold)
                .foregroundStyle(.text)

            HStack(spacing: layout.internalSpacing) {
                FatumTextField(
                    placeholder: "Escribe una opción",
                    text: $draft.optionInput,
                    style: .standard
                )

                Button("Añadir") {
                    draft.addOption()
                }
                .buttonStyle(.fatumButton(variant: .bordered))
                .disabled(!draft.canAddOption)
            }

            ForEach(draft.options, id: \.self) { option in
                HStack {
                    Text("• \(option)")
                        .fatumStyle(.body)
                        .foregroundStyle(.text)

                    Spacer()

                    Button {
                        draft.options.removeAll { $0 == option }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.text.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, layout.smallPadding)
                .padding(.vertical, layout.tinyPadding)
            }
        }
    }
}

#Preview {
    @Previewable @State var draft = FixedQuestionDraft(type: .SINGLE_CHOICE, options: ["Corto", "Largo"])

    ScrollView {
        FixedQuestionBuilder(draft: $draft, existing: []) { _ in }
            .padding(20)
    }
    .background(.brandSecondary)
}
