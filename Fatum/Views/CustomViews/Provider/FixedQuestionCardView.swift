//
//  FixedQuestionCardView.swift
//  Fatum
//

import SwiftUI

/// A bordered card summarising one `FixedQuestion` (text, type and options)
/// with a trailing delete button. Used in the create-service flow and its review sheet.
struct FixedQuestionCardView: View {
    let question: FixedQuestion
    let onDelete: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        HStack(alignment: .top, spacing: layout.internalSpacing) {
            VStack(alignment: .leading, spacing: layout.tiny) {
                Text(question.question)
                    .fatumStyle(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(.text)

                Text("Tipo: \(question.type.displayName)")
                    .fatumStyle(.footer)
                    .foregroundStyle(.text.opacity(0.7))

                if !question.options.isEmpty {
                    Text("Opciones: \(question.options.joined(separator: ", "))")
                        .fatumStyle(.footer)
                        .foregroundStyle(.text.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .foregroundStyle(.errorBorderLogin)
            }
            .buttonStyle(.plain)
        }
        .padding(layout.internalPadding)
        .background(.brandSecondary)
        .clipShape(RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius)
                .stroke(Color.border, lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 15) {
        FixedQuestionCardView(
            question: FixedQuestion(question: "¿Tienes alguna alergia?", type: .TEXT),
            onDelete: {}
        )

        FixedQuestionCardView(
            question: FixedQuestion(question: "Largo del cabello", type: .SINGLE_CHOICE, options: ["Corto", "Medio", "Largo"]),
            onDelete: {}
        )
    }
    .padding(20)
    .background(.brandSecondary)
}
