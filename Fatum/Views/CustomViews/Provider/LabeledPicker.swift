//
//  LabeledPicker.swift
//  Fatum
//

import SwiftUI

/// A small uppercase label above a `FatumPicker`, so pickers line up with
/// `LabeledTextField` in the same form.
struct LabeledPicker<Option: Hashable>: View {
    let label: String
    let options: [Option]
    @Binding var selection: Option
    var icon: String? = nil
    let optionLabel: (Option) -> String

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.spacingSmall) {
            Text(label.uppercased())
                .fatumStyle(.footer)
                .fontWeight(.bold)
                .foregroundStyle(.text)

            FatumPicker(
                title: label,
                options: options,
                selection: $selection,
                style: .standard,
                icon: icon,
                label: optionLabel
            )
        }
    }
}

#Preview {
    @Previewable @State var priceType: PriceType = .FIXED

    LabeledPicker(
        label: "Tipo de precio",
        options: PriceType.allCases,
        selection: $priceType,
        icon: "tag"
    ) { $0.displayName }
    .padding(20)
    .background(.brandSecondary)
}
