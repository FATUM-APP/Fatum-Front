//
//  VerificationFlowView.swift
//  Fatum
//

import SwiftUI
import UniformTypeIdentifiers

struct VerificationFlowView: View {
    @Environment(UserProvider.self) private var userProvider
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    enum VerificationStep {
        case profileImage
        case document
        case authenticate
    }

    @State private var currentStep: VerificationStep

    init(initialStep: VerificationStep = .profileImage) {
        self._currentStep = State(initialValue: initialStep)
    }
    @State private var isLoading = false
    @State private var showToast = false
    @State private var toastMessage = ""

    // Profile image
    @State private var existingImageURL: String? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isLoadingImage = true

    // Document
    @State private var scannedImages: [UIImage] = []
    @State private var documentPdfData: Data? = nil
    @State private var documentSourceLabel: String? = nil
    @State private var showScanner = false
    @State private var showDocumentPicker = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator

                ScrollView {
                    VStack(spacing: layout.externalSpacing) {
                        switch currentStep {
                        case .profileImage:
                            profileImageView
                        case .document:
                            documentView
                        case .authenticate:
                            authenticateView
                        }
                    }
                    .screenPadding()
                }

                bottomButton
            }
            .overlay(alignment: .bottom) {
                if showToast {
                    ToastMessageView(message: toastMessage)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .onAppear {
                            Task {
                                try? await Task.sleep(for: .seconds(3))
                                withAnimation { showToast = false }
                            }
                        }
                }
            }
            .animation(.easeInOut, value: showToast)
            .background(.brandSecondary)
            .navigationBarBackButtonHidden(true)
        }
        .fullScreenCover(isPresented: $showScanner) {
            DocumentScannerView(
                onScan: { images in
                    scannedImages = images
                    documentPdfData = Self.imagesToPdf(images)
                    documentSourceLabel = "\(images.count) página(s) escaneada(s)"
                    showScanner = false
                },
                onCancel: {
                    showScanner = false
                }
            )
        }
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: [.pdf],
            allowsMultipleSelection: false
        ) { result in
            handleDocumentPick(result)
        }
        .task {
            await loadExistingProfileImage()
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: layout.spacingSmall) {
            ForEach(0..<3) { index in
                Capsule()
                    .fill(index <= stepIndex ? Color.fatumAccent : Color.border)
                    .frame(height: 4)
            }
        }
        .screenPadding(.horizontal)
        .padding(.vertical, layout.spacingMedium)
    }

    private var stepIndex: Int {
        switch currentStep {
        case .profileImage: return 0
        case .document: return 1
        case .authenticate: return 2
        }
    }

    // MARK: - Step 1: Profile Image

    private var profileImageView: some View {
        VStack(spacing: layout.externalSpacing) {
            Text("Foto de perfil")
                .fatumStyle(.header)
                .foregroundStyle(.text)
                .frame(maxWidth: .infinity)

            Text("Sube una foto de perfil para que los usuarios te reconozcan.")
                .fatumStyle(.body)
                .foregroundStyle(.text)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            // Avatar circle + camera / gallery buttons
            ProfileImagePicker(
                selectedImage: $selectedImage,
                existingImageURL: existingImageURL,
                isLoading: isLoadingImage
            )
        }
    }

    // MARK: - Step 2: Document

    private var needsBackSide: Bool {
        let docType = userProvider.currentUser?.documentType ?? .ID
        return docType != .PASSPORT
    }

    private var documentView: some View {
        ScrollView {
            VStack(spacing: layout.externalSpacing) {
                Image(systemName: "doc.text.viewfinder")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundStyle(.brandPrimary)
                    .frame(maxWidth: .infinity)

                Text("Documento de identidad")
                    .fatumStyle(.header)
                    .foregroundStyle(.text)
                    .frame(maxWidth: .infinity)

                let docType = userProvider.currentUser?.documentType.displayName ?? "documento"
                let docNumber = userProvider.currentUser?.document ?? ""

                Text("Sube tu \(docType) con número \(docNumber) en formato PDF.\(needsBackSide ? " Asegúrate de incluir ambos lados del documento." : "")")
                    .fatumStyle(.body)
                    .foregroundStyle(.text)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                // Document preview
                documentPreview

                // Action buttons
                VStack(spacing: layout.spacingMedium) {
                    Button {
                        showScanner = true
                    } label: {
                        Label("Escanear documento", systemImage: "doc.viewfinder")
                    }
                    .buttonStyle(.fatumButton(variant: .bordered))

                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label("Subir PDF", systemImage: "folder")
                    }
                    .buttonStyle(.fatumButton(variant: .bordered))
                }
            }
        }
    }

    private var documentPreview: some View {
        Group {
            if let documentSourceLabel {
                VStack(spacing: layout.spacingSmall) {
                    // Scanned images preview
                    if !scannedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: layout.spacingMedium) {
                                ForEach(scannedImages.indices, id: \.self) { index in
                                    Image(uiImage: scannedImages[index])
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 160)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.border, lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }

                    // Status card
                    HStack(spacing: layout.spacingMedium) {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(.brandPrimary)
                            .font(.title2)

                        Text(documentSourceLabel)
                            .fatumStyle(.body)
                            .foregroundStyle(.brandPrimary)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    .padding(layout.internalPadding)
                    .background(Color.primaryContainer.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.border, lineWidth: 1)
                    )
                }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.primaryContainer.opacity(0.15))
                    .frame(height: 100)
                    .overlay(
                        VStack(spacing: layout.spacingSmall) {
                            Image(systemName: "doc.badge.plus")
                                .font(.title2)
                                .foregroundStyle(.brandPrimary)
                            Text("Ningún documento seleccionado")
                                .fatumStyle(.footer)
                                .foregroundStyle(.brandPrimary.opacity(0.5))
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.border, style: StrokeStyle(lineWidth: 1, dash: [6]))
                    )
            }
        }
    }

    private func handleDocumentPick(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                showError("No se pudo acceder al archivo")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                documentPdfData = try Data(contentsOf: url)
                scannedImages = []
                documentSourceLabel = url.lastPathComponent
            } catch {
                showError("Error al leer el archivo")
            }
        case .failure:
            showError("Error al seleccionar el archivo")
        }
    }

    /// Converts an array of UIImages into a single PDF Data.
    private static func imagesToPdf(_ images: [UIImage]) -> Data? {
        guard !images.isEmpty else { return nil }
        let pdfRenderer = UIGraphicsPDFRenderer(bounds: .zero)
        let data = pdfRenderer.pdfData { context in
            for image in images {
                let pageRect = CGRect(origin: .zero, size: image.size)
                context.beginPage(withBounds: pageRect, pageInfo: [:])
                image.draw(in: pageRect)
            }
        }
        return data
    }

    // MARK: - Step 3: Authenticate

    private var authenticateView: some View {
        VStack(spacing: layout.externalSpacing) {
            Image(systemName: "checkmark.shield")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundStyle(.text)
                .frame(maxWidth: .infinity)

            Text("Confirmar verificación")
                .fatumStyle(.header)
                .foregroundStyle(.text)
                .frame(maxWidth: .infinity)

            Text("Tu foto de perfil y documento han sido subidos exitosamente. Presiona el botón para confirmar tu autentificación.")
                .fatumStyle(.body)
                .foregroundStyle(.text)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        Button {
            handleAction()
        } label: {
            if isLoading {
                ProgressView()
                    .tint(.brandSecondary)
            } else {
                Text(buttonTitle)
            }
        }
        .buttonStyle(.fatumButton(variant: .third))
        .disabled(isLoading || !canProceed)
        .screenPadding([.horizontal, .bottom])
    }

    private var buttonTitle: String {
        switch currentStep {
        case .profileImage: return "Subir foto"
        case .document: return "Subir documento"
        case .authenticate: return "Verificar identidad"
        }
    }

    private var canProceed: Bool {
        switch currentStep {
        case .profileImage:
            return selectedImage != nil || existingImageURL != nil
        case .document:
            return documentPdfData != nil
        case .authenticate:
            return true
        }
    }

    // MARK: - Actions

    private func handleAction() {
        switch currentStep {
        case .profileImage:
            uploadProfileImage()
        case .document:
            uploadDocument()
        case .authenticate:
            authenticate()
        }
    }

    private func loadExistingProfileImage() async {
        isLoadingImage = true
        existingImageURL = await userProvider.fetchProfileImageURL()
        isLoadingImage = false
    }

    private func uploadProfileImage() {
        // If user hasn't selected a new image but already has one, skip upload
        guard let image = selectedImage else {
            if existingImageURL != nil {
                withAnimation { currentStep = .document }
            }
            return
        }

        guard let data = image.jpegData(compressionQuality: 0.8) else { return }

        isLoading = true

        Task {
            let username = userProvider.currentUser?.username ?? "profile"
            let success = await userProvider.uploadProfileImage(
                imageData: data,
                fileName: "\(username).jpeg",
                contentType: "image/jpeg"
            )
            isLoading = false

            if success {
                withAnimation { currentStep = .document }
            } else {
                showError(userProvider.error ?? "Error al subir la foto")
            }
        }
    }

    private func uploadDocument() {
        guard let pdfData = documentPdfData else { return }

        let docType = userProvider.currentUser?.documentType ?? .ID
        let username = userProvider.currentUser?.username ?? "user"

        // If scanned, use [username][documentType].pdf; if picked from files, keep original name
        let fileName = scannedImages.isEmpty
            ? (documentSourceLabel ?? "\(username)\(docType.rawValue).pdf")
            : "\(username)\(docType.rawValue).pdf"

        isLoading = true

        Task {
            let success = await userProvider.uploadDocumentPdf(
                documentType: docType,
                pdfData: pdfData,
                fileName: fileName
            )
            isLoading = false

            if success {
                withAnimation { currentStep = .authenticate }
            } else {
                showError(userProvider.error ?? "Error al subir el documento")
            }
        }
    }

    private func authenticate() {
        isLoading = true

        Task {
            let isAuthenticated = await userProvider.authenticateUser()
            isLoading = false

            if isAuthenticated {
                await userProvider.loadCurrentUser()
                dismiss()
            } else {
                // Sign out the user
                await userProvider.signOut()
                dismiss()
            }
        }
    }

    private func showError(_ message: String) {
        toastMessage = message
        withAnimation { showToast = true }
    }
}

#Preview("Step 1 - Profile Image") {
    let provider = UserProvider()
    VerificationFlowView()
        .environment(provider)
}

#Preview("Step 2 - Document") {
    let provider = UserProvider()
    VerificationFlowView(initialStep: .document)
        .environment(provider)
}

#Preview("Step 3 - Authenticate") {
    let provider = UserProvider()
    VerificationFlowView(initialStep: .authenticate)
        .environment(provider)
}
