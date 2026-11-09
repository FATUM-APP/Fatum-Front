//
//  ServicePricingFields.swift
//  Fatum
//

import SwiftUI

/// Base price, price type and the negotiable checkbox of a `ServiceDraft`.
/// Step 2 of `CreateServiceScreen` and part of an edit sheet of `ServiceReviewScreen`.
struct ServicePricingFields: View {
    @Binding var draft: ServiceDraft

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.spacingMedium) {
            LabeledTextField(
                label: "Precio base",
                placeholder: "0 (Si lo dejas vacío será 0)",
                text: $draft.basePriceText,
                icon: "dollarsign.circle",
                isOptional: true,
                keyboardType: .decimalPad,
                submitLabel: .done,
                allowedCharacters: Self.decimalCharacters
            )

            LabeledPicker(
                label: "Tipo de precio",
                options: PriceType.allCases,
                selection: $draft.priceType,
                icon: "tag"
            ) { $0.displayName }

            LabeledCheckbox(
                title: "Precio negociable",
                message: "Permite que los clientes propongan un valor diferente",
                isOn: $draft.isNegotiable
            )
        }
    }

    /// Keeps digits and a single decimal separator; a comma is turned into a dot.
    nonisolated private static func decimalCharacters(oldValue: String, newValue: String) -> String {
        let filtered = newValue
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        return filtered.filter { $0 == "." }.count > 1 ? oldValue : filtered
    }
}

#Preview {
    @Previewable @State var draft = ServiceDraft()

    ServicePricingFields(draft: $draft)
        .padding(20)
        .background(.brandSecondary)
}
