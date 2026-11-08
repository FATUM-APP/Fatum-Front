//
//  CategoryChipView.swift
//  Fatum
//

import SwiftUI

/// A chip with a filter's logo on the left and its name on the right, used in
/// the horizontal categories row on Home. Styled like `FatumButton`'s `.bordered`:
/// transparent with a `.text` border and text, or filled `.secondaryContainer`
/// with `.brandPrimary` text and icon when `isSelected`.
struct CategoryChipView: View {
    let filter: CatalogProvider.ServiceFilter
    var isSelected: Bool = false

    @Environment(\.horizontalSizeClass) private var sizeClass

    private let logoSize: CGFloat = 28
    private let cornerRadius: CGFloat = 20

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var contentColor: Color {
        isSelected ? .brandPrimary : .text
    }

    var body: some View {
        HStack(spacing: layout.tiny) {
            CategoryLogoView(
                logoUrl: filter.logoUrl,
                placeholderIcon: filter.placeholderIcon,
                size: logoSize,
                tint: contentColor
            )

            Text(filter.title)
                .fatumStyle(.footer)
                .fontWeight(.bold)
                .foregroundStyle(contentColor)
                .lineLimit(1)
        }
        .padding(.horizontal, layout.smallPadding + 1)
        .padding(.vertical, layout.smallPadding)
        .background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(isSelected ? Color.secondaryContainer : .clear)
        )
        // The border stays when selected (same color as the fill) so the chip doesn't change size.
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(isSelected ? Color.secondaryContainer : .text, lineWidth: 2)
        )
        // Makes the transparent inside tappable, not only the logo and text.
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

#Preview {
    HStack {
        CategoryChipView(filter: .all, isSelected: true)
        CategoryChipView(
            filter: .category(FatumCategory(
                name: "Peluquería",
                slug: "peluqueria",
                parentSlug: "belleza",
                schedulingModel: "APPOINTMENT",
                isAble: true
            ))
        )
    }
    .padding(20)
    .background(.brandSecondary)
}
