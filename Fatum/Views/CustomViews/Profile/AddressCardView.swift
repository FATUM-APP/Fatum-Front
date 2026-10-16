//
//  AddressCardView.swift
//  Fatum
//

import SwiftUI

/// A bordered card showing one saved address: an icon badge, the alias,
/// the residence line, the city/state line and a trailing "more" menu with
/// the actions "Hacer principal" (disabled for the principal address) and "Eliminar".
struct AddressCardView: View {
    let address: FatumAddress
    let isPrincipal: Bool
    let onMakePrincipal: () -> Void
    let onDelete: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    private let badgeSize: CGFloat = 48
    private let badgeIconSize: CGFloat = 22

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        HStack(alignment: .center, spacing: layout.internalSpacing) {
            // Icon badge
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.primaryContainer)
                .frame(width: badgeSize, height: badgeSize)
                .overlay(
                    Image(systemName: isPrincipal ? "house.fill" : "mappin.and.ellipse")
                        .resizable()
                        .scaledToFit()
                        .frame(width: badgeIconSize, height: badgeIconSize)
                        .foregroundStyle(.brandPrimary)
                )

            // Alias, residence and location
            VStack(alignment: .leading, spacing: layout.tiny) {
                Text(address.displayName)
                    .fatumStyle(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(.text)
                    .lineLimit(1)

                // Only show the residence as a second line when the first line is the alias
                if address.hasAlias, let residence = address.residence {
                    Text(residence)
                        .fatumStyle(.body)
                        .foregroundStyle(.text)
                        .lineLimit(2)
                }

                if !address.locationLine.isEmpty {
                    Text(address.locationLine)
                        .fatumStyle(.footer)
                        .foregroundStyle(.text.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Actions menu
            Menu {
                Button {
                    onMakePrincipal()
                } label: {
                    Label("Hacer principal", systemImage: "star")
                }
                .disabled(isPrincipal)

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Eliminar", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .rotationEffect(.degrees(90))
                    .foregroundStyle(.text)
                    .padding(layout.smallPadding)
                    .contentShape(Rectangle())
            }
        }
        .padding(layout.internalPadding)
        .background(.brandSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border, lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 15) {
        AddressCardView(
            address: FatumAddress(
                residence: "Calle 45 #12-34, Apto 502",
                alias: "Casa de mamá",
                city: "Envigado",
                state: "Antioquia",
                country: "Colombia"
            ),
            isPrincipal: true,
            onMakePrincipal: {},
            onDelete: {}
        )

        AddressCardView(
            address: FatumAddress(
                residence: "Carrera 7 #71-21, Piso 9",
                alias: nil,
                city: "Bogotá",
                state: "Cundinamarca",
                country: "Colombia"
            ),
            isPrincipal: false,
            onMakePrincipal: {},
            onDelete: {}
        )
    }
    .padding(20)
    .background(.brandSecondary)
}
