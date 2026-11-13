//
//  ServiceStatusTag.swift
//  Fatum
//

import SwiftUI

/// A service's status as a tag: a dot and a tinted background in the status
/// color, with the label in the text color so it stays readable on every tint.
///
/// With `onToggleActive`, holding the tag activates an inactive service or
/// deactivates an active one. Services in review or suspended can't be changed,
/// so the gesture does nothing for them.
struct ServiceStatusTag: View {
    let status: ServiceStatus
    /// Minimum height of the content, e.g. to match the category chip next to it.
    var minHeight: CGFloat? = nil
    /// Shows a spinner instead of the dot and ignores the gesture while a change is in flight.
    var isUpdating: Bool = false
    /// Called with `true` to activate and `false` to deactivate the service.
    var onToggleActive: ((Bool) -> Void)? = nil

    @Environment(\.horizontalSizeClass) private var sizeClass

    private let cornerRadius: CGFloat = 12
    private let dotSize: CGFloat = 8

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var canToggle: Bool {
        onToggleActive != nil && status.canToggleActive && !isUpdating
    }

    /// `true` activates (the service is inactive), `false` deactivates.
    private var activates: Bool {
        status == .INACTIVE
    }

    var body: some View {
        HStack(spacing: layout.spacingSmall) {
            if isUpdating {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.text)
            } else {
                Circle()
                    .fill(status.color)
                    .frame(width: dotSize, height: dotSize)
                    .accessibilityHidden(true)
            }

            Text(status.displayName)
                .fatumStyle(.footer)
                .foregroundStyle(.text)
                .lineLimit(1)
        }
        .frame(minHeight: minHeight)
        .padding(layout.smallPadding)
        .background(status.color.opacity(0.18), in: RoundedRectangle(cornerRadius: cornerRadius))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        .onLongPressGesture {
            guard canToggle else { return }
            onToggleActive?(activates)
        }
        .sensoryFeedback(.impact, trigger: isUpdating) { _, updating in updating }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Estado \(status.displayName)")
        .accessibilityHint(canToggle ? "Mantén presionado para \(activates ? "activar" : "desactivar") el servicio" : "")
        .accessibilityActions {
            if canToggle {
                Button(activates ? "Activar" : "Desactivar") { onToggleActive?(activates) }
            }
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ForEach(ServiceStatus.allCases, id: \.self) { status in
            ServiceStatusTag(status: status)
        }
        ServiceStatusTag(status: .ACTIVE, isUpdating: true)
    }
    .padding(20)
    .background(.brandSecondary)
}
