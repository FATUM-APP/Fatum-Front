//
//  ServiceReviewScreen.swift
//  Fatum
//

import SwiftUI

/// Last screen of the create-service flow. Shows the service the way clients
/// will see it (photo carousel, title, provider, description, information grid),
/// lets the provider edit every section in a sheet, previews the hiring controls
/// (date and time, fixed questions, negotiated price) and publishes with "Ofrecer servicio".
///
/// Hiring itself is not available yet, so "Contratar" only shows a toast.
struct ServiceReviewScreen: View {
    @Binding var draft: ServiceDraft
    let rootName: String
    let categories: [FatumCategory]
    let isSubmitting: Bool
    let onBack: () -> Void
    let onPublish: () -> Void

    @Environment(UserProvider.self) private var userProvider
    @Environment(\.horizontalSizeClass) private var sizeClass

    private enum EditSection: Identifiable {
        case info
        case details
        case questions
        case photos

        var id: Self { self }
    }

    @State private var editingSection: EditSection? = nil
    @State private var questionDraft = FixedQuestionDraft()
    @State private var currentPhotoIndex = 0
    @State private var providerImageURL: String? = nil

    // Hiring preview
    @State private var selectedDate = Date()
    @State private var proposedPrice: Decimal = 0

    @State private var showToast = false
    @State private var toastMessage: String = ""

    private let heroHeight: CGFloat = 340
    private let avatarSize: CGFloat = 44
    private let circleButtonSize: CGFloat = 38
    private let editButtonSize: CGFloat = 32
    private let dividerHeight: CGFloat = 42
    private let bottomBarRadius: CGFloat = 24
    /// How much "−" and "+" change the proposed price.
    private let priceStep: Decimal = 1000

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var basePrice: Decimal {
        draft.basePrice ?? 0
    }

    private var providerName: String {
        userProvider.currentUser?.name.capitalized ?? "Profesional"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroCarousel

                    VStack(alignment: .leading, spacing: layout.externalSpacing) {
                        titleSection

                        divider

                        descriptionSection

                        divider

                        informationSection

                        divider

                        hiringSection

                        publishSection
                    }
                    .screenPadding()
                }
            }
            .scrollDismissesKeyboard(.interactively)

            hiringBar
        }
        .background(.brandSecondary)
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
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            proposedPrice = basePrice
        }
        .onChange(of: draft.basePriceText) {
            proposedPrice = basePrice
        }
        .onChange(of: draft.images.count) {
            currentPhotoIndex = min(currentPhotoIndex, max(0, draft.images.count - 1))
        }
        .task {
            providerImageURL = await userProvider.fetchProfileImageURL()
        }
        .sheet(item: $editingSection) { section in
            editSheet(for: section)
        }
    }

    // MARK: - Photo Carousel

    private var heroCarousel: some View {
        ZStack(alignment: .bottomTrailing) {
            if draft.images.isEmpty {
                Rectangle()
                    .fill(Color.primaryContainer.opacity(0.25))
                    .frame(height: heroHeight)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundStyle(.brandPrimary.opacity(0.5))
                    )
            } else {
                TabView(selection: $currentPhotoIndex) {
                    ForEach(draft.images.indices, id: \.self) { index in
                        Image(uiImage: draft.images[index])
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: heroHeight)
                            .clipped()
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: heroHeight)
            }

            // Photo counter, e.g. "1/10"
            Text("\(draft.images.isEmpty ? 0 : currentPhotoIndex + 1)/\(draft.images.count)")
                .fatumStyle(.footer)
                .fontWeight(.bold)
                .foregroundStyle(.brandSecondary)
                .padding(.horizontal, layout.internalSpacing)
                .padding(.vertical, layout.tinyPadding)
                .background(Color.brandPrimary.opacity(0.75), in: Capsule())
                .padding(layout.internalPadding)
        }
        // Back and "Editar fotos" float over the photo
        .overlay(alignment: .top) {
            HStack {
                Button {
                    onBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.bold)
                        .foregroundStyle(.brandSecondary)
                        .frame(width: circleButtonSize, height: circleButtonSize)
                        .background(Color.brandPrimary.opacity(0.75), in: Circle())
                }
                .accessibilityLabel("Volver")

                Spacer()

                Button {
                    editingSection = .photos
                } label: {
                    Label("Editar fotos", systemImage: "photo.on.rectangle.angled")
                        .fatumStyle(.footer)
                        .fontWeight(.bold)
                        .foregroundStyle(.brandSecondary)
                        .padding(.horizontal, layout.internalSpacing)
                        .padding(.vertical, layout.smallPadding)
                        .background(Color.brandPrimary.opacity(0.75), in: Capsule())
                }
            }
            .disabled(isSubmitting)
            .screenPadding(.horizontal)
            .padding(.top, layout.internalPadding)
        }
    }

    // MARK: - Title & Provider

    private var titleSection: some View {
        VStack(spacing: layout.spacingMedium) {
            HStack(alignment: .top, spacing: layout.internalSpacing) {
                Text(draft.trimmedTitle.isEmpty ? "Sin título" : draft.trimmedTitle)
                    .fatumStyle(.header)
                    .foregroundStyle(.text)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)

                Button {
                    editingSection = .info
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(.brandPrimary)
                        .frame(width: editButtonSize, height: editButtonSize)
                        .overlay(Circle().stroke(Color.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Editar título")
            }

            // Rating | provider | reviews. A new service has no rating or reviews yet.
            HStack(spacing: 0) {
                VStack(spacing: layout.tiny) {
                    Text("Nuevo")
                        .fatumStyle(.subheader)
                        .fontWeight(.bold)
                        .foregroundStyle(.text)

                    Text("Sin calificación")
                        .fatumStyle(.footer)
                        .foregroundStyle(.text.opacity(0.7))
                }
                .frame(maxWidth: .infinity)

                verticalDivider

                VStack(spacing: layout.tiny) {
                    providerAvatar

                    Text(providerName)
                        .fatumStyle(.footer)
                        .fontWeight(.bold)
                        .foregroundStyle(.text)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)

                verticalDivider

                VStack(spacing: layout.tiny) {
                    Text("0")
                        .fatumStyle(.subheader)
                        .fontWeight(.bold)
                        .foregroundStyle(.text)

                    Text("Reseñas")
                        .fatumStyle(.footer)
                        .foregroundStyle(.text.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var providerAvatar: some View {
        AsyncImage(url: providerImageURL.flatMap(URL.init(string:))) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Circle()
                    .fill(Color.primaryContainer.opacity(0.4))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(.brandPrimary)
                    )
            }
        }
        .frame(width: avatarSize, height: avatarSize)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.border, lineWidth: 1))
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: layout.internalSpacing) {
            sectionHeader("Descripción del servicio") {
                editingSection = .info
            }

            Text(draft.trimmedDescription.isEmpty ? "Sin descripción adicional para este servicio." : draft.trimmedDescription)
                .fatumStyle(.body)
                .foregroundStyle(.text.opacity(draft.trimmedDescription.isEmpty ? 0.5 : 0.85))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Service Information

    private var informationSection: some View {
        VStack(alignment: .leading, spacing: layout.internalSpacing) {
            sectionHeader("Información del servicio") {
                editingSection = .details
            }

            HStack(spacing: 0) {
                infoCell("Categoría", value: draft.category?.name ?? rootName, alignment: .leading)
                verticalDivider
                infoCell("Tiempo estimado", value: draft.estimatedTimeDisplay, alignment: .trailing)
            }

            divider

            HStack(spacing: 0) {
                infoCell("Tipo de cobro", value: draft.priceType.displayName, alignment: .leading)
                verticalDivider
                infoCell("Negociable", value: draft.isNegotiable ? "Sí" : "No", alignment: .trailing)
            }
        }
    }

    private func infoCell(_ label: String, value: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: layout.tiny) {
            Text(label)
                .fatumStyle(.footer)
                .foregroundStyle(.text.opacity(0.7))

            Text(value)
                .fatumStyle(.body)
                .fontWeight(.bold)
                .foregroundStyle(.fatumAccent)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        .padding(.horizontal, layout.tinyPadding)
    }

    // MARK: - Hiring Preview

    private var hiringSection: some View {
        VStack(alignment: .leading, spacing: layout.spacingMedium) {
            VStack(alignment: .leading, spacing: layout.tiny) {
                Text("Personaliza tu solicitud")
                    .fatumStyle(.subheader)
                    .foregroundStyle(.text)

                Text("Vista previa de lo que el cliente completará al contratar tu servicio")
                    .fatumStyle(.footer)
                    .foregroundStyle(.text.opacity(0.65))
            }

            // Date and time
            card {
                VStack(alignment: .leading, spacing: layout.internalSpacing) {
                    cardLabel("Fecha y hora del servicio", icon: "calendar.badge.clock")

                    DatePicker(
                        "Selecciona fecha y hora",
                        selection: $selectedDate,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .fatumStyle(.body)
                    .foregroundStyle(.text)
                    .tint(.brandPrimary)
                }
            }

            // Proposed price, only for negotiable services
            if draft.isNegotiable {
                card {
                    VStack(alignment: .leading, spacing: layout.internalSpacing) {
                        cardLabel("Proponer precio", icon: "banknote")

                        Text("Precio sugerido por el profesional: \(Self.formatPrice(basePrice)) \(draft.priceType.unitLabel)")
                            .fatumStyle(.footer)
                            .foregroundStyle(.text.opacity(0.7))

                        HStack(spacing: layout.internalSpacing) {
                            stepperButton(systemImage: "minus", delta: -priceStep)

                            Text("\(Self.formatPrice(proposedPrice)) \(draft.priceType.unitLabel)")
                                .fatumStyle(.body)
                                .fontWeight(.bold)
                                .foregroundStyle(.brandPrimary)
                                .frame(maxWidth: .infinity)

                            stepperButton(systemImage: "plus", delta: priceStep)
                        }
                    }
                }
            }

            // Fixed questions
            VStack(alignment: .leading, spacing: layout.internalSpacing) {
                sectionHeader("Preguntas del servicio (\(draft.fixedQuestions.count))") {
                    editingSection = .questions
                }

                if draft.fixedQuestions.isEmpty {
                    Text("No agregaste preguntas fijas para el cliente.")
                        .fatumStyle(.footer)
                        .foregroundStyle(.text.opacity(0.65))
                } else {
                    ForEach(draft.fixedQuestions) { question in
                        FixedQuestionAnswerView(question: question)
                    }
                }
            }
        }
    }

    // MARK: - Publish

    private var publishSection: some View {
        VStack(alignment: .leading, spacing: layout.internalSpacing) {
            Text("¿Todo listo para publicar tu servicio?")
                .fatumStyle(.footer)
                .foregroundStyle(.text.opacity(0.75))

            Button {
                onPublish()
            } label: {
                if isSubmitting {
                    ProgressView()
                        .tint(.brandSecondary)
                } else {
                    Text("Ofrecer servicio")
                }
            }
            .buttonStyle(.fatumButton(variant: .third))
            .disabled(isSubmitting)
        }
    }

    // MARK: - Hiring Bar

    /// Dark bottom bar as clients will see it: price (with a stepper when negotiable),
    /// date, job type and "Contratar".
    private var hiringBar: some View {
        HStack(spacing: layout.internalSpacing) {
            VStack(alignment: .leading, spacing: layout.tiny) {
                HStack(spacing: layout.internalSpacing) {
                    if draft.isNegotiable {
                        HStack(spacing: layout.internalSpacing) {
                            barStepperButton(systemImage: "minus", delta: -priceStep)

                            Text(Self.formatPrice(proposedPrice))
                                .fatumStyle(.body)
                                .fontWeight(.bold)
                                .foregroundStyle(.brandSecondary)

                            barStepperButton(systemImage: "plus", delta: priceStep)
                        }
                        .padding(.horizontal, layout.internalSpacing)
                        .padding(.vertical, layout.tinyPadding)
                        .background(Color.fatumAccent.opacity(0.85), in: Capsule())
                    } else {
                        Text(Self.formatPrice(basePrice))
                            .fatumStyle(.subheader)
                            .fontWeight(.bold)
                            .foregroundStyle(.brandSecondary)
                    }

                    Text(draft.priceType.unitLabel)
                        .fatumStyle(.footer)
                        .fontWeight(.bold)
                        .foregroundStyle(.brandSecondary)
                }

                Text("\(selectedDate.formatted(Self.bookingDateStyle)) • \(JobType.PRESENCIAL.displayName)")
                    .fatumStyle(.footer)
                    .foregroundStyle(.brandSecondary.opacity(0.8))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                showMessage("Función en construcción")
            } label: {
                Text("Contratar")
                    .fatumStyle(.body)
                    .fontWeight(.bold)
                    .foregroundStyle(.brandPrimary)
                    .padding(.horizontal, layout.internalPadding)
                    .padding(.vertical, layout.smallPadding)
                    .background(Color.secondaryContainer, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .screenPadding(.horizontal)
        .padding(.vertical, layout.internalPadding)
        .background(
            UnevenRoundedRectangle(topLeadingRadius: bottomBarRadius, topTrailingRadius: bottomBarRadius)
                .fill(Color.brandPrimary)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    // MARK: - Edit Sheets

    private func editSheet(for section: EditSection) -> some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: layout.spacingMedium) {
                    switch section {
                    case .info:
                        ServiceInfoFields(draft: $draft)
                    case .details:
                        ServicePricingFields(draft: $draft)
                        ServiceDetailsFields(draft: $draft, rootName: rootName, categories: categories)
                    case .questions:
                        ForEach(draft.fixedQuestions) { question in
                            FixedQuestionCardView(question: question) {
                                draft.fixedQuestions.removeAll { $0 == question }
                            }
                        }

                        FixedQuestionBuilder(draft: $questionDraft, existing: draft.fixedQuestions) { question in
                            draft.fixedQuestions.append(question)
                        }
                    case .photos:
                        ServicePhotosPicker(images: $draft.images)
                    }
                }
                .screenPadding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.brandSecondary)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(editSheetTitle(for: section))
                        .fatumStyle(.subheader)
                        .foregroundStyle(.text)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        editingSection = nil
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(.brandPrimary)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func editSheetTitle(for section: EditSection) -> String {
        switch section {
        case .info: return "Título y descripción"
        case .details: return "Información y precio"
        case .questions: return "Preguntas fijas"
        case .photos: return "Fotos"
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String, onEdit: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .fatumStyle(.subheader)
                .foregroundStyle(.text)

            Spacer()

            Button(action: onEdit) {
                Label("Editar", systemImage: "pencil")
                    .fatumStyle(.footer)
                    .fontWeight(.bold)
                    .foregroundStyle(.brandPrimary)
            }
            .buttonStyle(.plain)
        }
    }

    /// Bordered container used by the hiring preview cards.
    private func card<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(layout.internalPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius)
                    .stroke(Color.border, lineWidth: 1)
            )
    }

    private func cardLabel(_ title: String, icon: String) -> some View {
        Label {
            Text(title.uppercased())
                .fatumStyle(.footer)
                .fontWeight(.bold)
                .foregroundStyle(.text)
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(.brandPrimary)
        }
    }

    private func stepperButton(systemImage: String, delta: Decimal) -> some View {
        Button {
            adjustProposedPrice(by: delta)
        } label: {
            Image(systemName: systemImage)
                .fontWeight(.bold)
                .foregroundStyle(.text)
                .frame(width: circleButtonSize, height: circleButtonSize)
                .overlay(
                    RoundedRectangle(cornerRadius: FatumFieldStyle.cornerRadius)
                        .stroke(Color.border, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func barStepperButton(systemImage: String, delta: Decimal) -> some View {
        Button {
            adjustProposedPrice(by: delta)
        } label: {
            Image(systemName: systemImage)
                .fontWeight(.bold)
                .foregroundStyle(.brandSecondary)
        }
        .buttonStyle(.plain)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.border)
            .frame(height: 1)
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(Color.border)
            .frame(width: 1, height: dividerHeight)
    }

    private func adjustProposedPrice(by delta: Decimal) {
        proposedPrice = max(0, proposedPrice + delta)
    }

    private func showMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
    }

    /// "28.000": Colombian grouping, no decimals.
    private static func formatPrice(_ value: Decimal) -> String {
        value.formatted(.number.precision(.fractionLength(0)).locale(Locale(identifier: "es_CO")))
    }

    /// "12/09/25, 8:00 a. m."
    private static let bookingDateStyle = Date.FormatStyle(date: .numeric, time: .shortened)
        .locale(Locale(identifier: "es_CO"))
}

#Preview {
    @Previewable @State var draft = ServiceDraft(
        title: "Corte y cepillado",
        descriptionText: "Corte personalizado con lavado y cepillado.",
        basePriceText: "28000",
        priceType: .HOURLY,
        isNegotiable: true,
        estimatedTimeText: "90",
        fixedQuestions: [FixedQuestion(question: "¿Tienes alguna alergia?", type: .BOOLEAN)]
    )

    ServiceReviewScreen(
        draft: $draft,
        rootName: "Belleza",
        categories: [],
        isSubmitting: false,
        onBack: {},
        onPublish: {}
    )
    .environment(UserProvider())
}
