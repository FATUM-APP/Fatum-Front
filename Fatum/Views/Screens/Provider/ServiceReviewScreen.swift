//
//  ServiceReviewScreen.swift
//  Fatum
//

import SwiftUI

/// The service page: photo carousel, title, provider, description, information
/// grid, the hiring controls (date and time, fixed questions, negotiated price)
/// and the dark hiring bar. Used in three modes:
///
/// - `.create`: last step of `CreateServiceScreen`. Every section is editable in a
///   sheet and "Ofrecer servicio" publishes it.
/// - `.edit`: the provider opened one of their services from "Mis servicios".
///   Same as `.create`, but "Guardar cambios" updates it and the category can't change.
/// - `.client`: a client opened the service from Home. Nothing is editable; the
///   provider's name and photo load from the public user endpoints, and
///   "Contratar" sends the request through `onHire`.
///
/// In `.create` and `.edit`, "Contratar" is shown as clients will see it but does
/// nothing: the provider can't hire their own service.
struct ServiceReviewScreen: View {
    enum Mode {
        case create
        case edit
        case client
    }

    /// What the client filled in "Personaliza tu solicitud", passed to `onHire`.
    struct HireRequest {
        let booking: Date
        /// Only for negotiable services.
        let negotiatedPrice: Decimal?
        let answers: [OrderProvider.QuestionAnswer]
        let requirements: String?
    }

    @Binding var draft: ServiceDraft
    let rootName: String
    let categories: [FatumCategory]
    var mode: Mode = .create
    /// Shown in `.client` mode until the provider's public profile loads; the
    /// other modes show the signed-in provider.
    var providerName: String? = nil
    /// In `.client` mode, used to load the provider's public name and photo.
    var providerId: String? = nil
    /// Shows a spinner on "Contratar" while the request is in flight.
    var isHiring: Bool = false
    /// Called by "Contratar" in `.client` mode once every question is answered.
    var onHire: (HireRequest) -> Void = { _ in }
    /// In `.client` mode, checks whether the provider is free at the chosen date:
    /// `true` or `false`, or `nil` when the check fails. Without it there's no tag.
    var checkAvailability: ((Date) async -> Bool?)? = nil
    /// Category slug of a published service (`FatumItem.category`), shown in the
    /// chip in `.edit` and `.client`. In `.create` the chip shows `draft.category`'s name.
    var categorySlug: String? = nil
    /// Status of a published service, shown next to the category chip in `.edit` only.
    var status: ServiceStatus? = nil
    var isUpdatingStatus: Bool = false
    /// Holding the status tag calls this with `true` to activate and `false` to deactivate.
    var onToggleActive: ((Bool) -> Void)? = nil
    var isSubmitting: Bool = false
    /// `.client` mode only: fills the heart at the top right of the photos.
    var isFavorite: Bool = false
    /// `.client` mode only: the heart adds or removes the service from favorites. Without it there's no heart.
    var onToggleFavorite: (() -> Void)? = nil
    let onBack: () -> Void
    var onPublish: () -> Void = {}

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
    /// The provider's name from `GET /users/user/{id}` (`.client` mode only).
    @State private var loadedProviderName: String? = nil

    // Hiring preview
    @State private var selectedDate = Date()
    @State private var proposedPrice: Decimal = 0
    /// Answers keyed by `FixedQuestion.question`.
    @State private var answers: [String: Set<String>] = [:]
    @State private var requirements: String = ""

    private enum Availability {
        case checking
        case available
        case unavailable
        /// The request failed, so the slot is unknown.
        case failed
    }

    /// Result of `checkAvailability` for `selectedDate`; `nil` when there's no check, which hides the tag.
    @State private var availability: Availability? = nil

    /// With a check, "Contratar" only works once it confirms the provider is free.
    private var canHire: Bool {
        checkAvailability == nil || availability == .available
    }

    @State private var showToast = false
    @State private var toastMessage: String = ""

    private let heroHeight: CGFloat = 340
    private let avatarSize: CGFloat = 44
    private let circleButtonSize: CGFloat = 38
    private let editButtonSize: CGFloat = 32
    private let dividerHeight: CGFloat = 42
    private let bottomBarRadius: CGFloat = 24
    private let chipCornerRadius: CGFloat = 20
    /// Same logo size as `CategoryChipView` on Home.
    private let chipLogoSize: CGFloat = 28
    /// How much "−" and "+" change the proposed price.
    private let priceStep: Decimal = 1000

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var basePrice: Decimal {
        draft.basePrice ?? 0
    }

    /// What the client would pay: their proposal when the price is negotiable, otherwise the base price.
    private var displayedPrice: Decimal {
        draft.isNegotiable ? proposedPrice : basePrice
    }

    private static let hiringSectionID = "hiringSection"

    /// Placeholder until the service has real reviews.
    private let placeholderRating = 5

    /// Only the provider can change the service; clients just see it.
    private var canEdit: Bool {
        mode != .client
    }

    private var displayedProviderName: String {
        let name = mode == .client ? (loadedProviderName ?? providerName) : userProvider.currentUser?.name
        return name?.capitalized ?? "Profesional"
    }

    // MARK: - Body

    var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        heroCarousel

                        VStack(alignment: .leading, spacing: layout.externalSpacing) {
                            titleSection

                            divider

                            // No description means no section; the title's pencil still edits it.
                            if !draft.trimmedDescription.isEmpty {
                                descriptionSection

                                divider
                            }

                            informationSection

                            divider

                            hiringSection
                                .id(Self.hiringSectionID)

                            if canEdit {
                                publishSection
                            }
                        }
                        .screenPadding()
                    }
                }
                .scrollDismissesKeyboard(.interactively)
                .overlay(alignment: .top) {
                    floatingButtons
                }

                hiringBar {
                    withAnimation {
                        proxy.scrollTo(Self.hiringSectionID, anchor: .top)
                    }
                }
            }
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
        // The proposed price only differs from the base price while the service is negotiable.
        .onChange(of: draft.basePriceText) {
            proposedPrice = basePrice
        }
        .onChange(of: draft.isNegotiable) {
            proposedPrice = basePrice
        }
        .onChange(of: draft.images.count) {
            currentPhotoIndex = min(currentPhotoIndex, max(0, draft.images.count - 1))
        }
        .task {
            if canEdit {
                providerImageURL = await userProvider.fetchProfileImageURL()
            } else if let providerId {
                // The provider's profile by id, not `/me`, so any client can see it.
                async let profile = userProvider.fetchPublicProfile(userId: providerId)
                async let imageURL = userProvider.fetchProfileImageURL(userId: providerId)
                loadedProviderName = await profile?.name
                providerImageURL = await imageURL
            }
        }
        // Runs again on every date change; the pause skips the dates scrolled past in the picker.
        .task(id: selectedDate) {
            guard let checkAvailability else { return }
            availability = .checking
            do {
                try await Task.sleep(for: .milliseconds(500))
            } catch {
                return
            }
            let available = await checkAvailability(selectedDate)
            guard !Task.isCancelled else { return }
            availability = available.map { $0 ? .available : .unavailable } ?? .failed
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
                .foregroundStyle(.text)
                .padding(.horizontal, layout.internalSpacing)
                .padding(.vertical, layout.tinyPadding)
                .glassEffect(.regular, in: .capsule)
                .padding(layout.internalPadding)
        }
    }

    /// Back and "Editar fotos", in Liquid Glass like the navigation bar buttons of
    /// the other screens. They sit outside the `ScrollView` and the photo
    /// carousel so their gestures can't swallow the taps, and stay visible while scrolling.
    private var floatingButtons: some View {
        HStack {
            Button {
                onBack()
            } label: {
                Image(systemName: "chevron.left")
                    .fontWeight(.bold)
                    .foregroundStyle(.text)
                    .frame(width: circleButtonSize, height: circleButtonSize)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel("Volver")

            Spacer()

            if canEdit {
                Button {
                    editingSection = .photos
                } label: {
                    Label("Editar fotos", systemImage: "photo.on.rectangle.angled")
                        .fatumStyle(.footer)
                        .fontWeight(.bold)
                        .foregroundStyle(.text)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.capsule)
            } else if let onToggleFavorite {
                Button(action: onToggleFavorite) {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .fontWeight(.bold)
                        .foregroundStyle(isFavorite ? .fatumAccent : .text)
                        .contentTransition(.symbolEffect(.replace))
                        .frame(width: circleButtonSize, height: circleButtonSize)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .sensoryFeedback(.selection, trigger: isFavorite)
                .accessibilityLabel(isFavorite ? "Quitar de favoritos" : "Agregar a favoritos")
            }
        }
        .disabled(isSubmitting)
        .padding(layout.internalPadding)
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

                if canEdit {
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
            }

            HStack(spacing: layout.internalSpacing) {
                if let chipTitle = categoryChipTitle {
                    categoryChip(title: chipTitle, logoUrl: draft.category?.logoUrl)
                }

                if mode == .edit, let status {
                    // Same content height as the chip's logo, so both line up.
                    ServiceStatusTag(
                        status: status,
                        minHeight: chipLogoSize,
                        isUpdating: isUpdatingStatus,
                        onToggleActive: onToggleActive
                    )
                }
            }

            // Rating | provider | reviews
            HStack(spacing: 0) {
                VStack(spacing: layout.tiny) {
                    Text("\(placeholderRating).0")
                        .fatumStyle(.subheader)
                        .fontWeight(.bold)
                        .foregroundStyle(.text)

                    HStack(spacing: layout.tiny) {
                        ForEach(0..<placeholderRating, id: \.self) { _ in
                            Image(systemName: "star.fill")
                                .font(.caption2)
                                .foregroundStyle(.text)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Calificación \(placeholderRating) de 5")

                verticalDivider

                VStack(spacing: layout.tiny) {
                    providerAvatar

                    Text(displayedProviderName)
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
                        .foregroundStyle(.text)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    /// The service's category as a chip with its logo, styled like an unselected `CategoryChipView`.
    /// The category name while creating; the slug from the backend once published.
    private var categoryChipTitle: String? {
        mode == .create ? draft.category?.name : categorySlug
    }

    private func categoryChip(title: String, logoUrl: String?) -> some View {
        HStack(spacing: layout.tiny) {
            CategoryLogoView(
                logoUrl: logoUrl,
                placeholderIcon: "square.grid.2x2",
                size: chipLogoSize,
                tint: .text
            )

            Text(title)
                .fatumStyle(.footer)
                .fontWeight(.bold)
                .foregroundStyle(.text)
        }
        .padding(.horizontal, layout.smallPadding + 1)
        .padding(.vertical, layout.smallPadding)
        .overlay(
            RoundedRectangle(cornerRadius: chipCornerRadius)
                .stroke(Color.text, lineWidth: 2)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Categoría \(title)")
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

            Text(draft.trimmedDescription)
                .fatumStyle(.body)
                .foregroundStyle(.text.opacity(0.85))
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
                infoCell("Precio", alignment: .leading) {
                    HStack(spacing: layout.tiny) {
                        infoValue(FatumFormat.price(basePrice))

                        negotiableIcon
                    }
                }

                verticalDivider

                infoCell("Tipo de cobro", alignment: .center) {
                    infoValue(draft.priceType.displayName)
                }

                verticalDivider

                infoCell("Tiempo estimado", alignment: .trailing) {
                    infoValue(draft.estimatedTimeDisplay)
                }
            }
        }
    }

    /// Two arrows when the client can propose another price, a lock when the price is fixed.
    private var negotiableIcon: some View {
        Image(systemName: draft.isNegotiable ? "arrow.left.arrow.right.circle.fill" : "lock.fill")
            .font(.footnote)
            .foregroundStyle(.text)
            .accessibilityLabel(draft.isNegotiable ? "Precio negociable" : "Precio fijo")
    }

    private func infoCell<Value: View>(
        _ label: String,
        alignment: HorizontalAlignment,
        @ViewBuilder value: () -> Value
    ) -> some View {
        VStack(alignment: alignment, spacing: layout.tiny) {
            Text(label)
                .fatumStyle(.footer)
                .foregroundStyle(.text)

            value()
        }
        .frame(maxWidth: .infinity, alignment: Alignment(horizontal: alignment, vertical: .center))
        .padding(.horizontal, layout.tinyPadding)
    }

    private func infoValue(_ value: String) -> some View {
        Text(value)
            .fatumStyle(.body)
            .fontWeight(.bold)
            .foregroundStyle(.text)
            .multilineTextAlignment(.center)
    }

    // MARK: - Hiring Preview

    private var hiringSection: some View {
        VStack(alignment: .leading, spacing: layout.spacingMedium) {
            VStack(alignment: .leading, spacing: layout.tiny) {
                Text("Personaliza tu solicitud")
                    .fatumStyle(.subheader)
                    .foregroundStyle(.text)

                Text(canEdit
                     ? "Vista previa de lo que el cliente completará al contratar tu servicio"
                     : "Completa estos datos para contratar el servicio")
                    .fatumStyle(.footer)
                    .foregroundStyle(.text)
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

                    if let availability {
                        availabilityTag(availability)
                    }
                }
            }

            // Proposed price, only for negotiable services
            if draft.isNegotiable {
                card {
                    VStack(alignment: .leading, spacing: layout.internalSpacing) {
                        cardLabel("Proponer precio", icon: "banknote")

                        Text("Precio sugerido por el profesional: \(FatumFormat.price(basePrice)) \(draft.priceType.unitLabel)")
                            .fatumStyle(.footer)
                            .foregroundStyle(.text)

                        HStack(spacing: layout.internalSpacing) {
                            stepperButton(systemImage: "minus", delta: -priceStep)

                            Text("\(FatumFormat.price(proposedPrice)) \(draft.priceType.unitLabel)")
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
                    Text(canEdit
                         ? "No agregaste preguntas fijas para el cliente."
                         : "Este servicio no tiene preguntas.")
                        .fatumStyle(.footer)
                        .foregroundStyle(.text)
                } else {
                    FixedQuestionsCarousel(questions: draft.fixedQuestions, answers: $answers)
                }
            }

            LabeledTextEditor(
                label: "Requerimientos adicionales",
                placeholder: "Cuéntale al profesional cualquier detalle extra de tu solicitud…",
                text: $requirements,
                maxLength: OrderProvider.BookServiceRequest.requirementsMaxLength,
                isOptional: true
            )
        }
    }

    // MARK: - Publish

    private var publishSection: some View {
        VStack(alignment: .leading, spacing: layout.internalSpacing) {
            Text(mode == .edit
                 ? "¿Listo para guardar los cambios?"
                 : "¿Todo listo para publicar tu servicio?")
                .fatumStyle(.footer)
                .foregroundStyle(.text)

            Button {
                onPublish()
            } label: {
                if isSubmitting {
                    ProgressView()
                        .tint(.brandSecondary)
                } else {
                    Text(mode == .edit ? "Guardar cambios" : "Ofrecer servicio")
                }
            }
            .buttonStyle(.fatumButton(variant: .third))
            .disabled(isSubmitting)
        }
    }

    // MARK: - Hiring Bar

    /// Dark bottom bar as clients will see it. The left side only summarises the
    /// request (price, date, job type); tapping it scrolls to "Personaliza tu solicitud",
    /// where those values are changed.
    private func hiringBar(onOpenRequest: @escaping () -> Void) -> some View {
        HStack(spacing: layout.internalSpacing) {
            Button(action: onOpenRequest) {
                VStack(alignment: .leading, spacing: layout.tiny) {
                    HStack(alignment: .firstTextBaseline, spacing: layout.internalSpacing) {
                        Text(FatumFormat.price(displayedPrice))
                            .fatumStyle(.subheader)
                            .fontWeight(.bold)
                            .foregroundStyle(.brandSecondary)

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
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Muestra las opciones para personalizar tu solicitud")

            Spacer()

            if canEdit {
                // Preview only: the provider can't hire their own service. `FatumButton`
                // doesn't dim when disabled, so it keeps the look clients will see.
                Button("Contratar") {}
                    .buttonStyle(.fatumButton(variant: .compact))
                    .disabled(true)
                    .accessibilityHint("Vista previa: los clientes usarán este botón para contratar")
            } else {
                Button {
                    hire()
                } label: {
                    if isHiring {
                        ProgressView()
                            .tint(.brandPrimary)
                    } else {
                        Text("Contratar")
                    }
                }
                .buttonStyle(.fatumButton(variant: .compact))
                .disabled(isHiring || !canHire)
                // `FatumButton` doesn't dim when disabled.
                .opacity(canHire ? 1 : 0.7)
                .accessibilityHint(hireHint)
            }
        }
        .padding(layout.internalPadding)
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
                        // `UpdateServiceRequest` has no category, so it can't change once published.
                        ServiceDetailsFields(
                            draft: $draft,
                            rootName: rootName,
                            categories: categories,
                            showsCategory: mode == .create
                        )
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

    /// Section title with an "Editar" button, which clients don't see.
    private func sectionHeader(_ title: String, onEdit: @escaping () -> Void) -> some View {
        HStack {
            Text(title)
                .fatumStyle(.subheader)
                .foregroundStyle(.text)

            Spacer()

            if canEdit {
                Button(action: onEdit) {
                    Label("Editar", systemImage: "pencil")
                        .fatumStyle(.footer)
                        .fontWeight(.bold)
                        .foregroundStyle(.brandPrimary)
                }
                .buttonStyle(.plain)
            }
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

    /// Why "Contratar" is disabled, for VoiceOver.
    private var hireHint: String {
        switch availability {
        case .checking: "Verificando la disponibilidad del profesional"
        case .unavailable: "El profesional no está disponible en la fecha y hora elegidas"
        case .failed: "No se pudo verificar la disponibilidad del profesional"
        case .available, nil: ""
        }
    }

    /// Small tag below the date picker: the text color on `.fatumAccent`, `.inactive` or `.special`, like `ServiceStatusTag`.
    private func availabilityTag(_ availability: Availability) -> some View {
        let (title, color): (String, Color) = switch availability {
        case .checking: ("Verificando…", .inactive)
        case .available: ("Disponible", .fatumAccent)
        case .unavailable: ("No disponible", .inactive)
        case .failed: ("No se pudo verificar", .special)
        }

        return HStack(spacing: layout.spacingSmall) {
            if availability == .checking {
                ProgressView()
                    .controlSize(.mini)
                    .tint(.text)
            }

            Text(title)
                .fatumStyle(.footer)
                .foregroundStyle(.text)
                .lineLimit(1)
        }
        .padding(.vertical, layout.tinyPadding - 2)
        .padding(.horizontal, layout.tinyPadding)
        .background(color, in: Capsule())
        .accessibilityElement(children: .combine)
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

    /// Only a negotiable price can change; a fixed one always stays at the base price.
    private func adjustProposedPrice(by delta: Decimal) {
        guard draft.isNegotiable else { return }
        proposedPrice = max(0, proposedPrice + delta)
    }

    /// Every fixed question needs an answer; text answers are trimmed first.
    private func hire() {
        var questionAnswers: [OrderProvider.QuestionAnswer] = []
        for question in draft.fixedQuestions {
            let answer = Set(
                (answers[question.question] ?? [])
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
            guard !answer.isEmpty else {
                showMessage("Responde todas las preguntas del servicio para contratarlo")
                return
            }
            questionAnswers.append(.init(question: question.question, answer: answer))
        }

        let trimmedRequirements = requirements.trimmingCharacters(in: .whitespacesAndNewlines)
        onHire(HireRequest(
            booking: selectedDate,
            negotiatedPrice: draft.isNegotiable ? proposedPrice : nil,
            answers: questionAnswers,
            requirements: trimmedRequirements.isEmpty ? nil : trimmedRequirements
        ))
    }

    private func showMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
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
        category: FatumCategory(name: "Peluquería", slug: "peluqueria", parentSlug: "belleza", schedulingModel: "APPOINTMENT", isAble: true),
        fixedQuestions: [
            FixedQuestion(question: "¿Tienes alguna alergia?", type: .BOOLEAN),
            FixedQuestion(question: "Largo del cabello", type: .SINGLE_CHOICE, options: ["Corto", "Medio", "Largo"])
        ]
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
