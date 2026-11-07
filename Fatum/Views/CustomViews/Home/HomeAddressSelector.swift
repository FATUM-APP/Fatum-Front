//
//  HomeAddressSelector.swift
//  Fatum
//

import SwiftUI

/// Address picker at the top-left of Home.
///
/// Folded, it shows the selected address's alias and "City, Country". Tapping it
/// unfolds a panel below with the saved addresses (tap one to select it), an
/// option to make the selected one principal, and links to add or manage addresses.
/// Selecting an address only changes `selected`; it does not touch the principal.
struct HomeAddressSelector: View {
    let addresses: [FatumAddress]
    let principal: FatumAddress?
    @Binding var selected: FatumAddress?
    var isLoading: Bool = false
    /// Message from the last failed load; shown inside the panel with a retry option.
    var errorMessage: String? = nil

    var onMakePrincipal: (FatumAddress) -> Void
    var onAdd: () -> Void
    var onManage: () -> Void
    var onRetry: () -> Void

    @State private var isExpanded = false
    @Environment(\.horizontalSizeClass) private var sizeClass

    private let badgeSize: CGFloat = 44

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var title: String {
        if let selected { return selected.displayName }
        if isLoading { return "Cargando direcciones…" }
        if errorMessage != nil { return "No pudimos cargar tus direcciones" }
        return "Agrega una dirección"
    }

    private var subtitle: String {
        if let selected {
            let line = selected.cityAndCountry
            return line.isEmpty ? (selected.residence ?? "") : line
        }
        return "Toca para elegir dónde atenderte"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.internalSpacing) {
            Button {
                withAnimation(.snappy) { isExpanded.toggle() }
            } label: {
                header
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Oculta tus direcciones" : "Muestra tus direcciones")

            if isExpanded {
                panel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: layout.internalSpacing) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.brandPrimary)
                .frame(width: badgeSize, height: badgeSize)
                .background(.primaryContainer, in: Circle())

            VStack(alignment: .leading, spacing: layout.tiny) {
                Text(title)
                    .fatumStyle(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(.text)
                    .lineLimit(1)

                HStack(spacing: layout.spacingSmall) {
                    Text(subtitle)
                        .fatumStyle(.footer)
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.semibold))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .foregroundStyle(.text.opacity(0.7))
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Panel

    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let errorMessage, addresses.isEmpty {
                Text(errorMessage)
                    .fatumStyle(.footer)
                    .foregroundStyle(.text.opacity(0.7))
                    .padding(layout.internalPadding)
                divider
                actionRow(icon: "arrow.clockwise", title: "Reintentar") { onRetry() }
                divider
            } else if addresses.isEmpty && !isLoading {
                Text("Aún no tienes direcciones guardadas")
                    .fatumStyle(.footer)
                    .foregroundStyle(.text.opacity(0.7))
                    .padding(layout.internalPadding)
                divider
            }

            ForEach(addresses, id: \.self) { address in
                Button {
                    selected = address
                    collapse()
                } label: {
                    addressRow(address)
                }
                .buttonStyle(.plain)
                divider
            }

            if let selected, selected != principal {
                actionRow(icon: "star", title: "Establecer como principal") {
                    onMakePrincipal(selected)
                }
                divider
            }

            actionRow(icon: "plus.circle", title: "Agregar nueva dirección") { onAdd() }
            divider
            actionRow(icon: "list.bullet", title: "Administrar direcciones") { onManage() }
        }
        .background(.brandSecondary)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.border, lineWidth: 1)
        )
    }

    private func addressRow(_ address: FatumAddress) -> some View {
        HStack(spacing: layout.internalSpacing) {
            VStack(alignment: .leading, spacing: layout.tiny) {
                HStack(spacing: layout.spacingSmall) {
                    Text(address.displayName)
                        .fatumStyle(.body)
                        .fontWeight(.bold)
                        .lineLimit(1)

                    if address == principal {
                        Text("Principal")
                            .fatumStyle(.footer)
                            .foregroundStyle(.brandPrimary)
                            .padding(.horizontal, layout.smallPadding)
                            .padding(.vertical, layout.tiny)
                            .background(.primaryContainer, in: Capsule())
                    }
                }

                if !address.cityAndCountry.isEmpty {
                    Text(address.cityAndCountry)
                        .fatumStyle(.footer)
                        .foregroundStyle(.text.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if address == selected {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(.brandPrimary)
            }
        }
        .foregroundStyle(.text)
        .padding(layout.internalPadding)
        .contentShape(Rectangle())
        .accessibilityAddTraits(address == selected ? .isSelected : [])
    }

    /// A tappable row with an icon and a title. Folds the panel before running `action`.
    private func actionRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button {
            collapse()
            action()
        } label: {
            HStack(spacing: layout.internalSpacing) {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                    .fatumStyle(.body)
                Spacer()
            }
            .foregroundStyle(.text)
            .padding(layout.internalPadding)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Divider().overlay(Color.border)
    }

    private func collapse() {
        withAnimation(.snappy) { isExpanded = false }
    }
}

#Preview {
    @Previewable @State var selected: FatumAddress? = FatumAddress(
        residence: "Calle 45 #12-34, Apto 502",
        alias: "Casa de mamá",
        city: "Envigado",
        state: "Antioquia",
        country: "Colombia"
    )
    let principal = FatumAddress(
        residence: "Carrera 7 #71-21, Piso 9",
        alias: "Oficina",
        city: "Bogotá",
        state: "Cundinamarca",
        country: "Colombia"
    )

    HomeAddressSelector(
        addresses: [principal, selected!],
        principal: principal,
        selected: $selected,
        onMakePrincipal: { _ in },
        onAdd: {},
        onManage: {},
        onRetry: {}
    )
    .padding(20)
    .frame(maxHeight: .infinity, alignment: .top)
    .background(.brandSecondary)
}
