//
//  AllCategoriesSheet.swift
//  Fatum
//

import SwiftUI

/// Sheet opened from "Ver todas" on Home: every filter ("Todas" plus each
/// enabled category) in a grid of `CategoryCardView`s. 3 columns on compact
/// width, 4 on regular. Picking one calls `onSelect` and dismisses.
struct AllCategoriesSheet: View {
    let categories: [FatumCategory]
    var onSelect: (CatalogProvider.ServiceFilter) -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var columns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: layout.internalSpacing, alignment: .top),
            count: sizeClass == .compact ? 3 : 4
        )
    }

    private var filters: [CatalogProvider.ServiceFilter] {
        [.all] + categories.map { .category($0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: layout.internalSpacing) {
                    ForEach(filters, id: \.self) { filter in
                        Button {
                            onSelect(filter)
                            dismiss()
                        } label: {
                            CategoryCardView(filter: filter)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .screenPadding()
            }
            .background(.brandSecondary)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.text)
                    }
                }

                ToolbarItem(placement: .principal) {
                    Text("Categorías")
                        .fatumStyle(.subheader)
                        .foregroundStyle(.text)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

#Preview {
    AllCategoriesSheet(
        categories: [
            FatumCategory(name: "Peluquería", slug: "peluqueria", schedulingModel: "APPOINTMENT", isAble: true),
            FatumCategory(name: "Manicure y pedicure", slug: "manicure", schedulingModel: "APPOINTMENT", isAble: true),
            FatumCategory(name: "Maquillaje", slug: "maquillaje", schedulingModel: "APPOINTMENT", isAble: true),
            FatumCategory(name: "Barbería", slug: "barberia", schedulingModel: "APPOINTMENT", isAble: true),
        ],
        onSelect: { _ in }
    )
}
