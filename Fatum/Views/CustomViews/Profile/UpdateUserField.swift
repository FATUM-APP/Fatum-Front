//
//  UpdateUserField.swift
//  Fatum
//

import SwiftUI

struct UpdateUserField: View {
    let fieldName: String
    let fieldValue: String
    var showBottomBorder: Bool = true
    var showArrow: Bool = true

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        HStack(spacing: layout.spacingSmall) {
            // First column: field name + value
            VStack(alignment: .leading, spacing: layout.spacingSmall) {
                Text(fieldName)
                    .fatumStyle(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(.text)

                Text(fieldValue)
                    .fatumStyle(.body)
                    .foregroundStyle(.text.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Second column: arrow (only for editable fields)
            if showArrow {
                Text(">")
                    .foregroundStyle(.text)
            }
        }
        .padding(layout.internalPadding)
        .background(.clear)
        .overlay(
            Group {
                if showBottomBorder {
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(.border)
                }
            },
            alignment: .bottom
        )
    }
}

#Preview {
    VStack(spacing: 0) {
        UpdateUserField(fieldName: "Nombre", fieldValue: "Camilo", showBottomBorder: true)
        UpdateUserField(fieldName: "Correo", fieldValue: "test@example.com", showBottomBorder: true)
        UpdateUserField(fieldName: "Ciudad", fieldValue: "Sin definir", showBottomBorder: false)
    }
    .background(.brandSecondary)
}
