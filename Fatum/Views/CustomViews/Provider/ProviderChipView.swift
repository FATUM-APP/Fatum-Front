//
//  ProviderChipView.swift
//  Fatum
//

import SwiftUI

/// A bordered chip with an SF Symbol and a title, used for the quick actions
/// at the top of `ProviderScreen`. Styled like `CategoryChipView` when not selected.
struct ProviderChipView: View {
    let title: String
    let icon: String
    let action: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    private let cornerRadius: CGFloat = 20

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: layout.tiny) {
                Image(systemName: icon)
                    .foregroundStyle(.text)

                Text(title)
                    .fatumStyle(.footer)
                    .fontWeight(.bold)
                    .foregroundStyle(.text)
                    .lineLimit(1)
            }
            .padding(.horizontal, layout.smallPadding + 4)
            .padding(.vertical, layout.smallPadding)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(Color.text, lineWidth: 2)
            )
            // Makes the transparent inside tappable, not only the icon and text.
            .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack {
        ProviderChipView(title: "Contratar", icon: "bag") {}
        ProviderChipView(title: "Mis Favoritos", icon: "heart") {}
    }
    .padding(20)
    .background(.brandSecondary)
}
