//
//  CatalogImage.swift
//  Fatum
//

import Foundation

/// Mirrors the backend's `CatalogImage` DTO (`GET /catalog/item/images?id=...`).
struct CatalogImage: Codable, Hashable, Identifiable {
    let id: String
    let originalFilename: String
    let contentType: String
    let size: Int64
    let url: String
}
