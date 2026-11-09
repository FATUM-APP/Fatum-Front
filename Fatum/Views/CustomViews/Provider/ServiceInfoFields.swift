//
//  ServiceInfoFields.swift
//  Fatum
//

import SwiftUI

/// Title and description of a `ServiceDraft`. Step 1 of `CreateServiceScreen`
/// and the matching edit sheet of `ServiceReviewScreen`.
struct ServiceInfoFields: View {
    @Binding var draft: ServiceDraft

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private typealias Request = CatalogProvider.CreateServiceRequest

    var body: some View {
        VStack(alignment: .leading, spacing: layout.spacingMedium) {
            LabeledTextField(
                label: "Título",
                placeholder: "Ej. Corte y cepillado profesional",
                text: $draft.title,
                icon: "textformat",
                maxLength: Request.titleMaxLength,
                showsCounter: true
            )

            LabeledTextEditor(
                label: "Descripción",
                placeholder: "Describe en qué consiste tu servicio, qué incluye y cualquier detalle relevante…",
                text: $draft.descriptionText,
                maxLength: Request.descriptionMaxLength,
                isOptional: true
            )
        }
    }
}

#Preview {
    @Previewable @State var draft = ServiceDraft()

    ServiceInfoFields(draft: $draft)
        .padding(20)
        .background(.brandSecondary)
}
