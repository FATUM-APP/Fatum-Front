//
//  ServicePhotosPicker.swift
//  Fatum
//

import SwiftUI
import PhotosUI

/// Picks the photos of a service: camera and gallery buttons, a "count/max"
/// header and a three-column grid where each photo can be removed.
/// Limits come from `ServiceDraft.minPhotos` and `ServiceDraft.maxPhotos`.
struct ServicePhotosPicker: View {
    @Binding var images: [UIImage]

    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false

    private let thumbnailHeight: CGFloat = 100
    private let placeholderHeight: CGFloat = 140
    private let thumbnailCornerRadius: CGFloat = 12

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var remainingSlots: Int {
        max(0, ServiceDraft.maxPhotos - images.count)
    }

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: layout.internalSpacing), count: 3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.spacingMedium) {
            HStack {
                Text("FOTOS SELECCIONADAS")
                    .fatumStyle(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.text)

                Spacer()

                Text("\(images.count)/\(ServiceDraft.maxPhotos) (mín. \(ServiceDraft.minPhotos))")
                    .fatumStyle(.caption)
                    .foregroundStyle(.text)
            }

            if remainingSlots > 0 {
                HStack(spacing: layout.spacingMedium) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("Tomar foto", systemImage: "camera")
                    }
                    .buttonStyle(.fatumButton(variant: .borderedExpanded))

                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: remainingSlots,
                        matching: .images
                    ) {
                        Label("Galería", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(.fatumButton(variant: .borderedExpanded))
                }
            }

            if images.isEmpty {
                emptyPlaceholder
            } else {
                LazyVGrid(columns: columns, spacing: layout.internalSpacing) {
                    ForEach(images.indices, id: \.self) { index in
                        thumbnail(at: index)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                if images.count < ServiceDraft.maxPhotos {
                    images.append(image)
                }
            }
            .ignoresSafeArea()
        }
        .onChange(of: pickerItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task {
                for item in newItems {
                    guard images.count < ServiceDraft.maxPhotos else { break }
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        images.append(image)
                    }
                }
                pickerItems = []
            }
        }
    }

    private var emptyPlaceholder: some View {
        RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius)
            .fill(Color.primaryContainer.opacity(0.15))
            .frame(height: placeholderHeight)
            .overlay(
                VStack(spacing: layout.spacingSmall) {
                    Image(systemName: "photo.badge.plus")
                        .font(.title2)
                        .foregroundStyle(.brandPrimary)

                    Text("Selecciona al menos \(ServiceDraft.minPhotos) foto (máximo \(ServiceDraft.maxPhotos))")
                        .fatumStyle(.footer)
                        .foregroundStyle(.brandPrimary)
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius)
                    .stroke(Color.border, style: StrokeStyle(lineWidth: 1, dash: [6]))
            )
    }

    private func thumbnail(at index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: images[index])
                .resizable()
                .scaledToFill()
                .frame(height: thumbnailHeight)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: thumbnailCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: thumbnailCornerRadius)
                        .stroke(Color.border, lineWidth: 1)
                )

            Button {
                images.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.brandSecondary)
                    .background(Circle().fill(Color.brandPrimary))
            }
            .buttonStyle(.plain)
            .padding(layout.tinyPadding)
        }
    }
}

#Preview {
    @Previewable @State var images: [UIImage] = []

    ServicePhotosPicker(images: $images)
        .padding(20)
        .background(.brandSecondary)
}
