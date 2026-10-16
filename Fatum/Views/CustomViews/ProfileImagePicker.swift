//
//  ProfileImagePicker.swift
//  Fatum
//

import SwiftUI
import PhotosUI

/// Circular avatar preview with "take photo" and "choose photo" buttons.
///
/// The avatar shows, in priority order: a spinner while `isLoading` is true,
/// the newly `selectedImage`, the remote `existingImageURL`, or a placeholder.
/// The view owns the camera sheet and the photo picker; the parent only
/// receives the resulting `UIImage` through the `selectedImage` binding.
struct ProfileImagePicker: View {
    @Binding var selectedImage: UIImage?
    var existingImageURL: String? = nil
    var isLoading: Bool = false

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var showCamera = false
    @State private var photoPickerItem: PhotosPickerItem? = nil

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        VStack(spacing: layout.externalSpacing) {
            avatar

            // Camera and Gallery buttons
            HStack(spacing: layout.spacingMedium) {
                Button {
                    showCamera = true
                } label: {
                    Label("Tomar foto", systemImage: "camera")
                }
                .buttonStyle(.fatumButton(variant: .borderedExpanded))

                PhotosPicker(selection: $photoPickerItem, matching: .images) {
                    Label("Seleccionar foto", systemImage: "photo.on.rectangle")
                        .foregroundStyle(.text)
                        .fatumStyle(.body)
                        .frame(maxWidth: .infinity)
                        .padding(layout.smallPadding)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.brandPrimary, lineWidth: 2)
                        )
                }
                .tint(.brandPrimary)
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                selectedImage = image
            }
            .ignoresSafeArea()
        }
        .onChange(of: photoPickerItem) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
                photoPickerItem = nil
            }
        }
    }

    // MARK: - Avatar

    @ViewBuilder
    private var avatar: some View {
        if isLoading {
            Circle()
                .fill(Color.primaryContainer)
                .frame(width: 150, height: 150)
                .overlay(ProgressView().tint(.brandPrimary))
        } else if let selectedImage {
            circularImage(Image(uiImage: selectedImage))
        } else if let existingImageURL, let url = URL(string: existingImageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    circularImage(image)
                default:
                    avatarPlaceholder
                }
            }
        } else {
            avatarPlaceholder
        }
    }

    private func circularImage(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFill()
            .frame(width: 150, height: 150)
            .clipShape(Circle())
            .overlay(Circle().stroke(Color.border, lineWidth: 2))
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(Color.primaryContainer)
            .frame(width: 150, height: 150)
            .overlay(
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundStyle(.brandPrimary)
            )
    }
}

// MARK: - Camera wrapper

struct CameraView: UIViewControllerRepresentable {
    let onImageCaptured: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured, dismiss: dismiss)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onImageCaptured: (UIImage) -> Void
        let dismiss: DismissAction

        init(onImageCaptured: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImageCaptured = onImageCaptured
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImageCaptured(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

#Preview {
    @Previewable @State var image: UIImage? = nil
    ProfileImagePicker(selectedImage: $image)
        .padding()
        .background(.brandSecondary)
}
