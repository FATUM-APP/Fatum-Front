//
//  ProfileOptionView.swift
//  Fatum
//

import SwiftUI

struct ProfileOptionView: View {
    let icon: String
    let name: String
    let action: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(.text)

                Text(name)
                    .fatumStyle(.body)
                    .foregroundStyle(.text)

                Spacer()
            }
            .padding(layout.internalPadding)
            .background(.clear)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 0) {
        ProfileOptionView(icon: "dollarsign.circle", name: "Conviertete en profesional") {}
        ProfileOptionView(icon: "person.circle", name: "Maneja tu perfil") {}
    }
    .background(.brandSecondary)
}
