//
//  FatumText.swift
//  Fatum
//
//  Created by Camilo Castaño on 4/04/26.
//

import SwiftUI

struct FatumTextStyle: ViewModifier {
    let type: TextType
    @ScaledMetric private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        switch type {
        case .premiumHeader:
            content
                .font(.custom("PlayDisplay-Regular", size: 24 * scale))
                .fontWeight(.medium)
        case .header:
            content
                .font(.custom("Poppins-Regular", size: 24 * scale))
                .fontWeight(.bold)
        case .subheader:
            content
                .font(.custom("Poppins-Regular", size: 20 * scale))
                .fontWeight(.medium)
        case .body:
            content
                .font(.custom("Lato-Regular", size: 16 * scale))
        case .caption:
            content
                .font(.custom("Lato-Regular", size: 15 * scale))
        case .footer:
            content
                .font(.custom("Lato-Regular", size: 14 * scale))
        }
    }
}

extension View {
    func fatumStyle(_ type: TextType) -> some View {
        modifier(FatumTextStyle(type: type))
    }
}

#Preview {
    VStack(spacing: 12) {
        Text("Bienvenido a FATUM")
            .fatumStyle(.premiumHeader)
        Text("Encuentra tu profesional")
            .fatumStyle(.header)
        Text("Servicios cerca de ti")
            .fatumStyle(.subheader)
        Text("Conectamos clientes con profesionales")
            .fatumStyle(.body)
        Text("Ver más detalles")
            .fatumStyle(.caption)
        Text("Términos y condiciones")
            .fatumStyle(.footer)
    }
    .padding()
}
