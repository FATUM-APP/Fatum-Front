//
//  ServiceDetailsFields.swift
//  Fatum
//

import SwiftUI

/// Estimated time and category of a `ServiceDraft`. The category picker lists
/// the sub-categories of `rootName`; while they load, or after a failure, a
/// placeholder with a retry button takes its place (like `HomeAddressSelector`).
struct ServiceDetailsFields: View {
    @Binding var draft: ServiceDraft
    let rootName: String
    let categories: [FatumCategory]
    var isLoading: Bool = false
    var errorMessage: String? = nil
    var onRetry: () -> Void = {}

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.spacingMedium) {
            LabeledTextField(
                label: "Tiempo estimado en minutos",
                placeholder: "Ej. 60",
                text: $draft.estimatedTimeText,
                icon: "clock",
                isOptional: true,
                maxLength: 5,
                keyboardType: .numberPad,
                submitLabel: .done,
                allowedCharacters: { _, newValue in newValue.filter(\.isNumber) }
            )

            if let first = categories.first, !isLoading {
                LabeledPicker(
                    label: "Categoría (\(rootName))",
                    options: categories,
                    selection: Binding(
                        get: { draft.category ?? first },
                        set: { draft.category = $0 }
                    ),
                    icon: "sparkles"
                ) { $0.name }
            } else {
                VStack(alignment: .leading, spacing: layout.spacingSmall) {
                    Text("CATEGORÍA (\(rootName.uppercased()))")
                        .fatumStyle(.footer)
                        .fontWeight(.bold)
                        .foregroundStyle(.text)

                    categoryPlaceholder
                }
            }
        }
    }

    private var categoryPlaceholder: some View {
        VStack(spacing: layout.internalSpacing) {
            if isLoading {
                ProgressView()
                    .tint(.brandPrimary)

                Text("Cargando subcategorías de \(rootName)…")
                    .fatumStyle(.footer)
                    .foregroundStyle(.text)
            } else {
                Text(errorMessage ?? "No se pudieron cargar las subcategorías de \(rootName)")
                    .fatumStyle(.footer)
                    .foregroundStyle(.text)
                    .multilineTextAlignment(.center)

                Button("Reintentar") {
                    onRetry()
                }
                .buttonStyle(.fatumButton(variant: .bordered))
            }
        }
        .padding(layout.internalPadding)
        .frame(maxWidth: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius)
                .stroke(Color.border, lineWidth: 1)
        )
    }
}

#Preview {
    @Previewable @State var draft = ServiceDraft()

    VStack(spacing: 30) {
        ServiceDetailsFields(
            draft: $draft,
            rootName: "Belleza",
            categories: [
                FatumCategory(name: "Peluquería", slug: "peluqueria", parentSlug: "belleza", schedulingModel: "APPOINTMENT", isAble: true)
            ]
        )

        ServiceDetailsFields(draft: $draft, rootName: "Belleza", categories: [], isLoading: true)
    }
    .padding(20)
    .background(.brandSecondary)
}
