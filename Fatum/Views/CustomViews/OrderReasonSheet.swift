//
//  OrderReasonSheet.swift
//  Fatum
//

import SwiftUI

/// Asks why an order is cancelled, rejected or a stage denied: a list of
/// common reasons and "Otro", which opens a text box. "Confirmar" stays
/// disabled until there is a reason, then passes it to `onConfirm` and closes.
struct OrderReasonSheet: View {
    let title: String
    let options: [String]
    /// Room left for the reason, e.g. less than 500 when a prefix is added later.
    var maxLength: Int = OrderProvider.reasonMaxLength
    let onConfirm: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var selection: String? = nil
    @State private var otherText: String = ""

    private static let otherOption = "Otro"

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var reason: String? {
        guard let selection else { return nil }
        guard selection == Self.otherOption else { return selection }
        let trimmed = otherText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: layout.spacingMedium) {
                    VStack(spacing: 0) {
                        ForEach(options + [Self.otherOption], id: \.self) { option in
                            optionRow(option)

                            if option != Self.otherOption {
                                Divider().overlay(Color.border)
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius)
                            .stroke(Color.border, lineWidth: 1)
                    )

                    if selection == Self.otherOption {
                        LabeledTextEditor(
                            label: "Cuéntanos qué pasó",
                            placeholder: "Escribe la razón…",
                            text: $otherText,
                            maxLength: maxLength
                        )
                    }

                    Button("Confirmar") {
                        guard let reason else { return }
                        onConfirm(reason)
                        dismiss()
                    }
                    .buttonStyle(.fatumButton(variant: .third))
                    .disabled(reason == nil)
                    // `FatumButton` doesn't dim when disabled.
                    .opacity(reason == nil ? 0.5 : 1)
                }
                .screenPadding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.brandSecondary)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .fatumStyle(.subheader)
                        .foregroundStyle(.text)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.text)
                    }
                    .accessibilityLabel("Cerrar")
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func optionRow(_ option: String) -> some View {
        Button {
            selection = option
        } label: {
            HStack(spacing: layout.internalSpacing) {
                Text(option)
                    .fatumStyle(.body)
                    .foregroundStyle(.text)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: selection == option ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(.text)
            }
            .padding(layout.internalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selection == option ? .isSelected : [])
    }
}

#Preview {
    OrderReasonSheet(
        title: "Cancelar orden",
        options: ["Ya no necesito el servicio", "Cambié de fecha u hora"],
        onConfirm: { _ in }
    )
}
