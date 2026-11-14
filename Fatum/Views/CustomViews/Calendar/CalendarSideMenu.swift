//
//  CalendarSideMenu.swift
//  Fatum
//

import SwiftUI

/// Capsule menu for professionals to pick which calendar they see: the orders
/// they provide ("Como profesional") or the ones they hired ("Como cliente").
/// Styled like the "Filtrar" menu of `MyServicesScreen`.
struct CalendarSideMenu: View {
    @Binding var side: ConfirmingParty

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        Menu {
            Picker("Ver calendario", selection: $side) {
                Label("Como profesional", systemImage: "briefcase")
                    .tag(ConfirmingParty.PROVIDER)
                Label("Como cliente", systemImage: "bag")
                    .tag(ConfirmingParty.CUSTOMER)
            }
        } label: {
            HStack(spacing: layout.spacingSmall) {
                Text(side == .PROVIDER ? "Como profesional" : "Como cliente")
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.text)
            }
            .fatumStyle(.footer)
            .foregroundStyle(.text)
            .padding(layout.smallPadding)
            .overlay(
                Capsule().stroke(Color.brandPrimary, lineWidth: 1)
            )
        }
        // The menu's text and icons in the text color instead of the accent color.
        .tint(.text)
        .accessibilityLabel("Ver calendario")
        .accessibilityValue(side == .PROVIDER ? "Como profesional" : "Como cliente")
    }
}

#Preview {
    @Previewable @State var side: ConfirmingParty = .PROVIDER

    CalendarSideMenu(side: $side)
        .padding()
        .background(.brandSecondary)
}
