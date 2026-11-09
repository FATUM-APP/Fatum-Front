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
                keyboardType: .numberPad,
                submitLabel: .done,
                allowedCharacters: Self.groupedPesos
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

    /// Formats the price while typing: keeps only digits and groups thousands
    /// with dots, e.g. "50000" → "50.000". `ServiceDraft.basePrice` removes the
    /// dots again. Pesos are whole numbers, so there is no decimal part.
    nonisolated private static func groupedPesos(oldValue: String, newValue: String) -> String {
        let digits = String(newValue.filter(\.isNumber).drop { $0 == "0" }.prefix(maxDigits))
        guard !digits.isEmpty else { return newValue.contains("0") ? "0" : "" }

        var grouped = ""
        for (index, digit) in digits.enumerated() {
            if index > 0 && (digits.count - index) % 3 == 0 {
                grouped.append(".")
            }
            grouped.append(digit)
        }
        return grouped
    }

    /// Up to 999.999.999.999 COP.
    nonisolated private static let maxDigits = 12
}

#Preview {
    @Previewable @State var draft = ServiceDraft()

    ServicePricingFields(draft: $draft)
        .padding(20)
        .background(.brandSecondary)
}
