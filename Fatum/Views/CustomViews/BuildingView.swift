//
//  BuildingView.swift
//  Fatum
//

import SwiftUI

struct BuildingView: View {
    let name: String

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "building.2.fill")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .foregroundStyle(.brandPrimary)

            Text("Building screen \(name)")
                .fatumStyle(.header)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    BuildingView(name: "Home")
}
