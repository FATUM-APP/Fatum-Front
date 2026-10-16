//
//  ToastMessageView.swift
//  Fatum
//

import SwiftUI

struct ToastMessageView: View {
    let message: String

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        Text(message)
            .fatumStyle(.body)
            .foregroundStyle(.brandSecondary)
            .frame(maxWidth: .infinity)
            .padding(layout.smallPadding)
            .background(.brandPrimary)
    }
}

#Preview {
    ToastMessageView(message: "Función en construcción")
}
