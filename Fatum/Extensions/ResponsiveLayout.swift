//
//  ResponsiveLayout.swift
//  Fatum
//
//  Created by Camilo Castaño on 17/04/26.
//

import SwiftUI

struct ResponsiveLayout {
    let isCompact: Bool

    //Padding
    var padding: CGFloat { isCompact ? 25 : 40 }
    var internalPadding: CGFloat { isCompact ? 15 : 30 }
    var smallPadding: CGFloat { isCompact ? 7 : 12 }
    var tinyPadding: CGFloat { isCompact ? 5 : 10 }
    
    //Spacing
    var tiny: CGFloat { 3 }
    var spacingSmall: CGFloat { 5 }
    var internalSpacing: CGFloat { 10 }
    var spacingMedium: CGFloat { 20 }
    var externalSpacing: CGFloat { 25 }
}

extension View {
    /// The outer padding every screen puts around its main content
    /// (`ResponsiveLayout.padding`). Pass `edges` to pad only some sides,
    /// e.g. `.screenPadding(.horizontal)` for a step indicator or a bottom button.
    func screenPadding(_ edges: Edge.Set = .all) -> some View {
        modifier(ScreenPaddingModifier(edges: edges))
    }
}

private struct ScreenPaddingModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var sizeClass
    let edges: Edge.Set

    func body(content: Content) -> some View {
        content.padding(edges, ResponsiveLayout(isCompact: sizeClass == .compact).padding)
    }
}

