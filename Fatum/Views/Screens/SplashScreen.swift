//
//  SplashScreen.swift
//  Fatum
//

import SwiftUI

struct SplashScreen: View {
    var body: some View {
        ZStack {
            Color.primaryContainer
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Image("FatumLogin")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200)

                // Pulsing dots loader
                Image(systemName: "ellipsis")
                    .font(.system(size: 40))
                    .foregroundStyle(.brandPrimary)
                    .symbolEffect(.variableColor.iterative, options: .repeat(.continuous))
                    .accessibilityLabel("Cargando")
            }
        }
    }
}

#Preview {
    SplashScreen()
}
