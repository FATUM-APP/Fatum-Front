//
//  FixedQuestionAnswerView.swift
//  Fatum
//

import SwiftUI

/// How a client answers one `FixedQuestion` when hiring: a text field, Sí / No
/// pills, or pills for single or multiple choice. Shown one at a time by
/// `FixedQuestionsCarousel`. `answer` holds the chosen options, or a single
/// element with the typed text for `.TEXT` questions.
struct FixedQuestionAnswerView: View {
    let question: FixedQuestion
    @Binding var answer: Set<String>

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    /// The typed text stored as the only element of `answer`; empty text clears it.
    private var textAnswer: Binding<String> {
        Binding(
            get: { answer.first ?? "" },
            set: { answer = $0.isEmpty ? [] : [$0] }
        )
    }

    private var options: [String] {
        question.type == .BOOLEAN ? ["Sí", "No"] : question.options
    }

    private var hint: String {
        switch question.type {
        case .TEXT: return "Escribe tu respuesta"
        case .BOOLEAN, .SINGLE_CHOICE: return "Elige una opción"
        case .MULTIPLE_CHOICE: return "Puedes elegir varias opciones"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.spacingMedium) {
            VStack(alignment: .leading, spacing: layout.tiny) {
                Text(question.question)
                    .fatumStyle(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(.text)

                Text(hint)
                    .fatumStyle(.footer)
                    .foregroundStyle(.text)
            }

            if question.type == .TEXT {
                FatumTextField(
                    placeholder: "Respuesta del cliente…",
                    text: textAnswer,
                    style: .standard
                )
            } else {
                // Wraps onto new lines instead of scrolling, so it doesn't fight the carousel swipe.
                FlowLayout(spacing: layout.internalSpacing) {
                    ForEach(options, id: \.self) { option in
                        OptionPill(title: option, isSelected: answer.contains(option)) {
                            select(option)
                        }
                    }
                }
            }
        }
        .padding(layout.internalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .overlay(
            RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    /// Multiple choice toggles the option; every other type keeps a single selection.
    private func select(_ option: String) {
        if question.type == .MULTIPLE_CHOICE {
            if answer.contains(option) {
                answer.remove(option)
            } else {
                answer.insert(option)
            }
        } else {
            answer = [option]
        }
    }
}

/// A rounded pill styled like `CategoryChipView`: transparent with a `.text`
/// border and text, or filled `.secondaryContainer` with `.brandPrimary` text when selected.
private struct OptionPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    private let cornerRadius: CGFloat = 20

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .fatumStyle(.footer)
                .fontWeight(.bold)
                .foregroundStyle(isSelected ? .brandPrimary : .text)
                .padding(.horizontal, layout.internalPadding)
                .padding(.vertical, layout.smallPadding)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(isSelected ? Color.secondaryContainer : .clear)
                )
                // The border stays when selected (same color as the fill) so the pill doesn't change size.
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(isSelected ? Color.secondaryContainer : .text, lineWidth: 2)
                )
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    @Previewable @State var text: Set<String> = []
    @Previewable @State var boolean: Set<String> = []
    @Previewable @State var multiple: Set<String> = []

    VStack(spacing: 15) {
        FixedQuestionAnswerView(question: FixedQuestion(question: "¿Tienes alguna alergia?", type: .TEXT), answer: $text)
        FixedQuestionAnswerView(question: FixedQuestion(question: "¿Primera vez?", type: .BOOLEAN), answer: $boolean)
        FixedQuestionAnswerView(question: FixedQuestion(question: "Largo del cabello", type: .MULTIPLE_CHOICE, options: ["Corto", "Medio", "Largo", "Muy largo", "Con extensiones"]), answer: $multiple)
    }
    .padding(20)
    
}
