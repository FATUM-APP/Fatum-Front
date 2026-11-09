//
//  FatumButton.swift
//  Fatum
//
//  Created by Camilo Castaño on 7/04/26.
//

import SwiftUI

struct FatumButton{}

extension FatumButton{
    
    struct ButtonStyle: SwiftUI.ButtonStyle{
        let variant: ButtonVariant
        var foregroundColor: Color? = nil
        
        func makeBody(configuration: Configuration) -> some View {
            ButttonContent(label: configuration.label, variant: variant, foregroundColor: foregroundColor)
            
        }
        
    }
}	

extension FatumButton{
    struct ButttonContent<Label: View>: View{
        
        let label: Label
        let variant: ButtonVariant
        var foregroundColor: Color? = nil
        var backgroundColor: Color? = nil
        @Environment(\.horizontalSizeClass) var sizeClass
    
        var layout: ResponsiveLayout {
            ResponsiveLayout(isCompact: sizeClass == .compact)
        }
        
        var body: some View{
            switch variant {
            case .primary:
                label
                    .fatumStyle(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(foregroundColor ?? .brandPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(layout.internalPadding)
                    .background(.brandSecondary)
                    .cornerRadius(20)
            case .secondary:
                label
                    .fatumStyle(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(foregroundColor ?? .brandSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(layout.internalPadding)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.brandSecondary, lineWidth: 2)
                    )
            case .third:
                label
                    .fatumStyle(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(foregroundColor ?? .brandSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(layout.internalPadding)
                    .background(.brandPrimary)
                    .cornerRadius(20)
            case .bordered:
                label
                    .fatumStyle(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(foregroundColor ?? .text)
                    .padding(layout.smallPadding)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.brandPrimary, lineWidth: 2)
                    )
            case .borderedExpanded:
                label
                    .fatumStyle(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(foregroundColor ?? .text)
                    .frame(maxWidth: .infinity)
                    .padding(layout.smallPadding)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.brandPrimary, lineWidth: 2)
                    )
            case .outlined:
                label
                    .fatumStyle(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(foregroundColor ?? .brandPrimary)
                    .padding(layout.internalPadding)
                    .cornerRadius(20)
            case .compact:
                label
                    .fatumStyle(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(foregroundColor ?? .brandPrimary)
                    .padding(.vertical,layout.smallPadding)
                    .padding(.horizontal,layout.internalPadding)
                    .background(.secondaryContainer)
                    .cornerRadius(20)
            }
        }
    }
}

extension ButtonStyle where Self == FatumButton.ButtonStyle{
    static func fatumButton(variant: ButtonVariant, foregroundColor: Color? = nil) -> Self {
        .init(variant: variant, foregroundColor: foregroundColor)
    }
}


#Preview {
    VStack {
        Button("Regístrarse") {
            
        }
        .buttonStyle(.fatumButton(variant: .primary))
        
            Button("Iniciar Sesión") {
                
            }
            .buttonStyle(.fatumButton(variant: .secondary))

            Button("Contratar") {}
                .buttonStyle(.fatumButton(variant: .compact))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
        .background(.brandPrimary)
}



