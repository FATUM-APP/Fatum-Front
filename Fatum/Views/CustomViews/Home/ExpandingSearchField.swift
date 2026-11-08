//
//  ExpandingSearchField.swift
//  Fatum
//

import SwiftUI

extension FatumFieldStyle {
    /// For fields placed on a card: a clean container with subtle border.
    static let onContainer = FatumFieldStyle(
        borderColor: .border,
        focusedBorderColor: .border,
        errorBorderColor: .errorBorderLogin,
        fillColor: .brandSecondary,
        textColor: .text,
        iconColor: .text
    )
}

/// A Liquid Glass search box that grows vertically as the text wraps, like a chat
/// composer. After `maxLines` it stops growing and the text scrolls inside it.
///
/// Next to it there is a microphone button that calls `onMicTapped`, used to open
/// the voice search screen (`VoiceSearchScreen`).
struct ExpandingSearchField: View {
    let placeholder: String
    @Binding var text: String
    var style: FatumFieldStyle = .standard
    var maxLines: Int = 5
    var onMicTapped: () -> Void = {}

    @FocusState private var isFocused: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Namespace private var glassNamespace

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var fieldShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius)
    }

    var body: some View {
        // The container lets the field and the mic button blend as Liquid Glass.
        GlassEffectContainer(spacing: layout.internalSpacing) {
            HStack(alignment: .bottom, spacing: layout.internalSpacing) {
                field
                micButton
            }
        }
        .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
    }

    // MARK: - Field

    private var field: some View {
        HStack(alignment: .top, spacing: layout.internalSpacing) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(style.iconColor)

            // `axis: .vertical` + `lineLimit(1...maxLines)` is what makes it grow, then scroll.
            TextField(placeholder, text: $text, axis: .vertical)
                .lineLimit(1...maxLines)
                .focused($isFocused)
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(style.iconColor.opacity(0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Borrar búsqueda")
            }
        }
        .fatumStyle(.body)
        .foregroundStyle(style.textColor)
        .padding(layout.internalPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.interactive(), in: fieldShape)
        .glassEffectID("field", in: glassNamespace)
        .overlay {
            fieldShape
                .stroke(Color.border, lineWidth: 1)
        }
    }

    // MARK: - Microphone

    private var micButton: some View {
        Button {
            isFocused = false
            onMicTapped()
        } label: {
            Image(systemName: "mic")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(style.iconColor)
                .frame(width: 20, height: 20)
                .padding(layout.internalPadding)
                .glassEffect(.regular.interactive(), in: .circle)
                .glassEffectID("mic", in: glassNamespace)
                .overlay {
                    Circle()
                        .stroke(Color.border, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Buscar con tu voz")
    }
}

#Preview {
    VStack(spacing: 20) {
        ExpandingSearchField(placeholder: "Ej. Corte de cabello", text: .constant(""))

        ExpandingSearchField(
            placeholder: "Ej. Corte de cabello",
            text: .constant("Necesito un corte de cabello y un tinte para este sábado en la tarde, idealmente a domicilio"),
            style: .onContainer
        )
    }
    .padding(20)
    .background(.secondaryContainer)
}
