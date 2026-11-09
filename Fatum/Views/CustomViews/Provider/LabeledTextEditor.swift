//
//  LabeledTextEditor.swift
//  Fatum
//

import SwiftUI

/// Multi-line counterpart of `LabeledTextField`: an uppercase label with a
/// character counter above a bordered `TextEditor` with a placeholder.
struct LabeledTextEditor: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    let maxLength: Int

    var isOptional: Bool = false

    @Environment(\.horizontalSizeClass) private var sizeClass

    private let minHeight: CGFloat = 130

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var displayLabel: String {
        let base = label.uppercased()
        return isOptional ? "\(base) (OPCIONAL)" : base
    }

    /// Binding that enforces `maxLength`, like `FatumTextField` does.
    private var limitedText: Binding<String> {
        Binding(
            get: { text },
            set: { text = String($0.prefix(maxLength)) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.spacingSmall) {
            HStack {
                Text(displayLabel)
                    .fatumStyle(.footer)
                    .fontWeight(.bold)
                    .foregroundStyle(.text)

                Spacer()

                Text("\(text.count)/\(maxLength)")
                    .fatumStyle(.footer)
                    .foregroundStyle(.text)
            }

            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .fatumStyle(.body)
                        .foregroundStyle(.text.opacity(0.4))
                        .padding(layout.internalPadding)
                }

                TextEditor(text: limitedText)
                    .fatumStyle(.body)
                    .foregroundStyle(.text)
                    .scrollContentBackground(.hidden)
                    .padding(layout.smallPadding)
                    .frame(minHeight: minHeight)
            }
            .clipShape(RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius)
                    .stroke(Color.border, lineWidth: 1)
            )
        }
    }
}

#Preview {
    @Previewable @State var text = ""

    LabeledTextEditor(
        label: "Descripción",
        placeholder: "Describe en qué consiste tu servicio…",
        text: $text,
        maxLength: 1000,
        isOptional: true
    )
    .padding(20)
    .background(.brandSecondary)
}
