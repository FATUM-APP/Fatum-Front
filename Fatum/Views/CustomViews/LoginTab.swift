//
//  LoginTab.swift
//  Fatum
//
//  Created by Camilo Castaño on 5/04/26.
//

import SwiftUI

struct LoginTab: View {
    
    @Environment(\.horizontalSizeClass) var sizeClass
    
    private let image: String
    private let contentTitle: String
    private let contentBody: String
    
    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }
    
    init(image: String, title: String, body: String) {
        self.image = image
        self.contentTitle = title
        self.contentBody = body
    }
    
    var body: some View {
        VStack(spacing: layout.internalSpacing) {
            Image(image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 350)
                .clipped()
            
            Text(contentTitle)
                .fatumStyle(.premiumHeader)
                .multilineTextAlignment(.center)
                .foregroundStyle(.text)
                .frame(maxWidth: .infinity, alignment: .center)
            
            Text(contentBody)
                .fatumStyle(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.loginText)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}

#Preview {
    LoginTab(
        image: "login",
        title: "Te damos la bienvenida a FATUM",
        body: "Donde la confianza vive en cada servicio"
    )
}
