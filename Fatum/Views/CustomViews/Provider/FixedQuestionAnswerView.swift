//
//  FixedQuestionAnswerView.swift
//  Fatum
//

import SwiftUI

/// How a client answers one `FixedQuestion` when hiring: a text field, Sí / No
/// pills, or pills for single or multiple choice. Answers are local preview
/// state for now; hiring is not wired to the backend yet.
struct FixedQuestionAnswerView: View {
    let question: FixedQuestion

    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var textAnswer: String = ""
    @State private var selectedOptions: Set<String> = []

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var options: [String] {
        question.type == .BOOLEAN ? ["Sí", "No"] : question.options
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.internalSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(question.question)
                    .fatumStyle(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(.text)

                Spacer()

                Text(question.type.displayName)
                    .fatumStyle(.footer)
                    .foregroundStyle(.text.opacity(0.6))
            }

            if question.type == .TEXT {
                FatumTextField(
                    placeholder: "Respuesta del cliente…",
                    text: $textAnswer,
                    style: .standard
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: layout.internalSpacing) {
                        ForEach(options, id: \.self) { option in
                            OptionPill(title: option, isSelected: selectedOptions.contains(option)) {
                                select(option)
                            }
                        }
                    }
                }
            }
        }
        .padding(layout.internalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(
            RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    /// Multiple choice toggles the option; every other type keeps a single selection.
    private func select(_ option: String) {
        if question.type == .MULTIPLE_CHOICE {
            if selectedOptions.contains(option) {
                selectedOptions.remove(option)
            } else {
                selectedOptions.insert(option)
            }
        } else {
            selectedOptions = [option]
        }
    }
}

/// A rounded pill that fills with `.brandPrimary` when selected.
private struct OptionPill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    private let cornerRadius: CGFloat = 16

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .fatumStyle(.footer)
                .fontWeight(.bold)
                .foregroundStyle(isSelected ? .brandSecondary : .text)
                .padding(.horizontal, layout.internalPadding)
                .padding(.vertical, layout.smallPadding)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(isSelected ? Color.brandPrimary : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(isSelected ? Color.brandPrimary : .border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    VStack(spacing: 15) {
        FixedQuestionAnswerView(question: FixedQuestion(question: "¿Tienes alguna alergia?", type: .TEXT))
        FixedQuestionAnswerView(question: FixedQuestion(question: "¿Primera vez?", type: .BOOLEAN))
        FixedQuestionAnswerView(question: FixedQuestion(question: "Largo del cabello", type: .SINGLE_CHOICE, options: ["Corto", "Medio", "Largo"]))
    }
    .padding(20)
    .background(.brandSecondary)
}
