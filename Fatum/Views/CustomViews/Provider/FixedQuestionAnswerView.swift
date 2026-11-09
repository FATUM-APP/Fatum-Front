//
//  FixedQuestionAnswerView.swift
//  Fatum
//

import SwiftUI

/// How a client answers one `FixedQuestion` when hiring: a text field, Sí / No
/// pills, or pills for single or multiple choice. Shown one at a time by
/// `FixedQuestionsCarousel`. Answers are local preview state for now; hiring
/// is not wired to the backend yet.
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
                    text: $textAnswer,
                    style: .standard
                )
            } else {
                // Wraps onto new lines instead of scrolling, so it doesn't fight the carousel swipe.
                OptionsFlowLayout(spacing: layout.internalSpacing) {
                    ForEach(options, id: \.self) { option in
                        OptionPill(title: option, isSelected: selectedOptions.contains(option)) {
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

/// Places its subviews left to right and wraps to a new line when the row is full.
private struct OptionsFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = rows(for: subviews, maxWidth: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in rows(for: subviews, maxWidth: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func rows(for subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let neededWidth = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            if neededWidth > maxWidth, !current.indices.isEmpty {
                rows.append(current)
                current = Row()
            }
            current.width = current.indices.isEmpty ? size.width : current.width + spacing + size.width
            current.height = max(current.height, size.height)
            current.indices.append(index)
        }
        if !current.indices.isEmpty {
            rows.append(current)
        }
        return rows
    }
}

#Preview {
    VStack(spacing: 15) {
        FixedQuestionAnswerView(question: FixedQuestion(question: "¿Tienes alguna alergia?", type: .TEXT))
        FixedQuestionAnswerView(question: FixedQuestion(question: "¿Primera vez?", type: .BOOLEAN))
        FixedQuestionAnswerView(question: FixedQuestion(question: "Largo del cabello", type: .MULTIPLE_CHOICE, options: ["Corto", "Medio", "Largo", "Muy largo", "Con extensiones"]))
    }
    .padding(20)
    
}
