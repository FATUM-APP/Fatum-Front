//
//  RequiredActionDialog.swift
//  Fatum
//
//  Created by Camilo Castaño on 5/8/26.
//

import SwiftUI

struct RequiredActionDialog<Content: View>: View {
    let description: String
    @ViewBuilder let content: Content

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            // Dialog card
            VStack(spacing: layout.spacingMedium) {
                Text(description)
                    .fatumStyle(.subheader)
                    .foregroundStyle(.text)
                    .multilineTextAlignment(.center)

                content
            }
            .padding(layout.internalPadding)
            .background(.brandSecondary)
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 4)
            .padding(.horizontal, layout.padding)
        }
    }
}

#Preview {
    RequiredActionDialog(description: "No estas autentificado") {
        Button("Autentificarse") {}
            .buttonStyle(.fatumButton(variant: .third))
    }
}
