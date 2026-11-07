//
//  ExpandingSearchField.swift
//  Fatum
//

import SwiftUI

extension FatumFieldStyle {
    /// For fields placed on a `.primaryContainer` card: a white box so it stands out from the card.
    static let onContainer = FatumFieldStyle(
        borderColor: .border,
        focusedBorderColor: .brandPrimary,
        errorBorderColor: .errorBorderLogin,
        fillColor: .brandSecondary,
        textColor: .text,
        iconColor: .text
    )
}

/// A search box with the same size and look as `FatumTextField`, but it grows
/// vertically as the text wraps, like a chat composer. After `maxLines` it stops
/// growing and the text scrolls inside it.
struct ExpandingSearchField: View {
    let placeholder: String
    @Binding var text: String
    var style: FatumFieldStyle = .standard
    var maxLines: Int = 5

    @FocusState private var isFocused: Bool
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        // `.top` keeps the icons on the first line once the text wraps.
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
        .background(style.fillColor)
        .clipShape(RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius)
                .stroke(isFocused ? style.focusedBorderColor : style.borderColor, lineWidth: isFocused ? 2 : 1)
        )
        .animation(.easeInOut(duration: 0.15), value: text.isEmpty)
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
    .background(.primaryContainer)
}
