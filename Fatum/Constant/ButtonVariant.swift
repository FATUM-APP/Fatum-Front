//
//  ButtonVariant.swift
//  Fatum
//
//  Created by Camilo Castaño on 7/04/26.
//

import Foundation

enum ButtonVariant{
    case primary
    case secondary
    case third
    case bordered
    case borderedExpanded
    case outlined
    /// Filled `.secondaryContainer` with `.brandPrimary` text, only as wide as its label like `.bordered`.
    case compact
}
