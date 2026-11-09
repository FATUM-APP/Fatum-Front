//
//  CreateServiceScreen.swift
//  Fatum
//

import SwiftUI

/// Multi-step form to offer a new service, built like `RegisterView`: a step
/// indicator, a title and subtitle per step, and a bottom button that validates
/// the step before moving on. After the last step "Continuar" shows
/// `ServiceReviewScreen`, whose "Ofrecer servicio" sends `POST /catalog/item/create`.
struct CreateServiceScreen: View {
    @Environment(Router<ProviderRoute>.self) private var router
    @Environment(UserProvider.self) private var userProvider
    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Root category whose sub-categories can be picked in step 3.
    @State private var catalogProvider = CatalogProvider(root: "Belleza")

    enum CreateStep: CaseIterable {
        case info
        case pricing
        case details
        case questions
        case photos
    }

    // Step tracking
    @State private var currentStep: CreateStep = .info
    @State private var isReviewing = false

    // Form
    @State private var draft = ServiceDraft()
    @State private var questionDraft = FixedQuestionDraft()

    @State private var isLoading = false
    @State private var errorMessage: String? = nil
    @State private var showToast = false
    @State private var toastMessage: String = ""

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var stepIndex: Int {
        switch currentStep {
        case .info: return 0
        case .pricing: return 1
        case .details: return 2
        case .questions: return 3
        case .photos: return 4
        }
    }

    /// Only enabled sub-categories can be picked, unless the backend has none enabled.
    private var availableCategories: [FatumCategory] {
        let enabled = catalogProvider.categories.filter(\.isAble)
        return enabled.isEmpty ? catalogProvider.categories : enabled
    }

    // MARK: - Body

    var body: some View {
        Group {
            if isReviewing {
                ServiceReviewScreen(
                    draft: $draft,
                    rootName: catalogProvider.root,
                    categories: availableCategories,
                    isSubmitting: isLoading,
                    onBack: { withAnimation { isReviewing = false } },
                    onPublish: publish
                )
            } else {
                formContent
            }
        }
        .overlay(alignment: .bottom) {
            if showToast {
                ToastMessageView(message: toastMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        Task {
                            try? await Task.sleep(for: .seconds(3))
                            withAnimation {
                                showToast = false
                            }
                        }
                    }
            }
        }
        .animation(.easeInOut, value: showToast)
        .navigationBarBackButtonHidden(true)
        .task {
            if catalogProvider.categories.isEmpty {
                await loadCategories()
            }
        }
    }

    private var formContent: some View {
        VStack(spacing: 0) {
            stepIndicator

            ScrollView {
                VStack(alignment: .leading, spacing: layout.externalSpacing) {
                    // Header
                    VStack(alignment: .leading, spacing: layout.spacingSmall) {
                        Text(stepTitle)
                            .fatumStyle(.header)
                            .foregroundStyle(.text)

                        Text(stepSubtitle)
                            .fatumStyle(.body)
                            .foregroundStyle(.text.opacity(0.7))
                    }

                    // Form fields per step
                    VStack(alignment: .leading, spacing: layout.spacingMedium) {
                        switch currentStep {
                        case .info:
                            ServiceInfoFields(draft: $draft)
                        case .pricing:
                            ServicePricingFields(draft: $draft)
                        case .details:
                            ServiceDetailsFields(
                                draft: $draft,
                                rootName: catalogProvider.root,
                                categories: availableCategories,
                                isLoading: catalogProvider.isLoadingCategories,
                                errorMessage: catalogProvider.categoriesLoadFailed ? catalogProvider.error : nil,
                                onRetry: { Task { await loadCategories() } }
                            )
                        case .questions:
                            questionsFields
                        case .photos:
                            ServicePhotosPicker(images: $draft.images)
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .fatumStyle(.footer)
                                .foregroundStyle(.errorBorderLogin)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
                .screenPadding()
            }
            .scrollDismissesKeyboard(.interactively)

            // Action button
            Button(currentStep == .photos ? "Continuar" : "Siguiente") {
                advanceStep()
            }
            .buttonStyle(.fatumButton(variant: .third))
            .screenPadding([.horizontal, .bottom])
        }
        .background(.brandSecondary)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.text)
                }
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        VStack(alignment: .leading, spacing: layout.spacingSmall) {
            Text("Paso \(stepIndex + 1) de \(CreateStep.allCases.count)")
                .fatumStyle(.footer)
                .fontWeight(.bold)
                .foregroundStyle(.text.opacity(0.7))

            HStack(spacing: layout.spacingSmall) {
                ForEach(0..<CreateStep.allCases.count, id: \.self) { index in
                    Capsule()
                        .fill(index <= stepIndex ? Color.brandPrimary : Color.border)
                        .frame(height: 4)
                }
            }
        }
        .screenPadding(.horizontal)
        .padding(.vertical, layout.spacingMedium)
    }

    // MARK: - Step Titles

    private var stepTitle: String {
        switch currentStep {
        case .info: return "Información del servicio"
        case .pricing: return "Precio y modalidad"
        case .details: return "Tiempo y categoría"
        case .questions: return "Preguntas fijas"
        case .photos: return "Fotos del servicio"
        }
    }

    private var stepSubtitle: String {
        switch currentStep {
        case .info: return "Define el título y una descripción para tu servicio"
        case .pricing: return "Indica el precio base, el tipo de cobro y si es negociable"
        case .details: return "Ingresa el tiempo estimado y selecciona una subcategoría de \(catalogProvider.root)"
        case .questions: return "Agrega preguntas opcionales que el cliente responderá al solicitar el servicio"
        case .photos: return "Sube entre \(ServiceDraft.minPhotos) y \(ServiceDraft.maxPhotos) fotos para mostrar tu trabajo"
        }
    }

    // MARK: - Step 4: Fixed Questions

    private var questionsFields: some View {
        VStack(alignment: .leading, spacing: layout.spacingMedium) {
            if !draft.fixedQuestions.isEmpty {
                Text("PREGUNTAS AGREGADAS (\(draft.fixedQuestions.count))")
                    .fatumStyle(.footer)
                    .fontWeight(.bold)
                    .foregroundStyle(.text)

                ForEach(draft.fixedQuestions) { question in
                    FixedQuestionCardView(question: question) {
                        draft.fixedQuestions.removeAll { $0 == question }
                    }
                }
            }

            FixedQuestionBuilder(draft: $questionDraft, existing: draft.fixedQuestions) { question in
                draft.fixedQuestions.append(question)
            }
        }
    }

    // MARK: - Validation

    private func validateCurrentStep() -> Bool {
        errorMessage = nil

        switch currentStep {
        case .info:
            if !draft.hasValidInfo {
                errorMessage = "El título es obligatorio"
                return false
            }
            return true

        case .pricing:
            if !draft.hasValidPricing {
                errorMessage = "Ingresa un precio base válido mayor o igual a 0"
                return false
            }
            return true

        case .details:
            if draft.category == nil {
                errorMessage = "Debes seleccionar una categoría"
                return false
            }
            if !draft.hasValidDetails {
                errorMessage = "Ingresa un tiempo estimado válido"
                return false
            }
            return true

        case .questions:
            // A question typed but not added yet is added for the user, or blocks the step if incomplete.
            guard !questionDraft.isEmpty else { return true }
            guard let question = questionDraft.fixedQuestion else {
                errorMessage = "Completa la pregunta (las de selección necesitan al menos \(FixedQuestion.minOptions) opciones) o bórrala"
                return false
            }
            if !draft.fixedQuestions.contains(question) {
                draft.fixedQuestions.append(question)
            }
            questionDraft = FixedQuestionDraft()
            return true

        case .photos:
            if !draft.hasValidPhotos {
                errorMessage = "Debes subir entre \(ServiceDraft.minPhotos) y \(ServiceDraft.maxPhotos) fotos"
                return false
            }
            return true
        }
    }

    // MARK: - Actions

    private func advanceStep() {
        guard validateCurrentStep() else { return }
        withAnimation {
            switch currentStep {
            case .info:
                currentStep = .pricing
            case .pricing:
                currentStep = .details
            case .details:
                currentStep = .questions
            case .questions:
                currentStep = .photos
            case .photos:
                isReviewing = true
            }
        }
    }

    private func goBack() {
        errorMessage = nil
        withAnimation {
            switch currentStep {
            case .info:
                router.pop()
            case .pricing:
                currentStep = .info
            case .details:
                currentStep = .pricing
            case .questions:
                currentStep = .details
            case .photos:
                currentStep = .questions
            }
        }
    }

    /// Loads the sub-categories and preselects the first one if none is picked yet.
    private func loadCategories() async {
        await catalogProvider.loadCategories()
        if draft.category == nil {
            draft.category = availableCategories.first
        }
    }

    private func publish() {
        guard let providerId = userProvider.currentUser?.userId, !providerId.isEmpty else {
            showMessage("No se encontró la sesión del proveedor")
            return
        }
        guard let request = draft.request(providerId: providerId) else {
            showMessage("Revisa la información del servicio antes de publicarlo")
            return
        }
        let images = draft.imageData
        guard !images.isEmpty else {
            showMessage("No se pudieron procesar las imágenes seleccionadas")
            return
        }

        isLoading = true

        Task {
            let success = await catalogProvider.createItem(request, images: images)
            isLoading = false

            if success {
                router.pop(message: "Servicio creado exitosamente")
            } else {
                showMessage(catalogProvider.error ?? "No se pudo crear el servicio")
            }
        }
    }

    private func showMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
    }
}

#Preview {
    NavigationStack {
        CreateServiceScreen()
    }
    .environment(Router<ProviderRoute>())
    .environment(UserProvider())
}
