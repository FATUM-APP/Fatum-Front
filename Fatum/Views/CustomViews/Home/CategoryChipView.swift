//
//  CategoryChipView.swift
//  Fatum
//

import SwiftUI

/// A pill with a filter's logo on the left and its name on the right, used in
/// the horizontal categories row on Home.
/// `isSelected` swaps the `.primaryContainer` background for `.fatumAccent`.
struct CategoryChipView: View {
    let filter: CatalogProvider.ServiceFilter
    var isSelected: Bool = false

    @Environment(\.horizontalSizeClass) private var sizeClass

    private let logoSize: CGFloat = 28

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        HStack(spacing: layout.internalSpacing) {
            CategoryLogoView(
                logoUrl: filter.logoUrl,
                placeholderIcon: filter.placeholderIcon,
                size: logoSize
            )

            Text(filter.title)
                .fatumStyle(.footer)
                .fontWeight(.bold)
                .foregroundStyle(.brandPrimary)
                .lineLimit(1)
        }
        .padding(.vertical, layout.smallPadding)
        .padding(.leading, layout.smallPadding)
        .padding(.trailing, layout.internalPadding)
        .background(isSelected ? Color.fatumAccent : .primaryContainer)
        .clipShape(Capsule())
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
