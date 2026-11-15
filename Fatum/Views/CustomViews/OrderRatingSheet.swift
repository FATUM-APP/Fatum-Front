//
//  OrderRatingSheet.swift
//  Fatum
//

import SwiftUI

/// Rates the other side of a completed order in three steps, styled like
/// `OrderDetailSheet`:
///
/// 1. Stars (required) for each subject: the client for providers; the
///    professional and the service for clients.
/// 2. What went wrong (below 3 stars) or what they liked most, as tags with
///    icons. Can be skipped.
/// 3. A comment of up to 255 characters. Can be skipped.
///
/// It can't be closed until every rating is sent: there is no close button,
/// swiping down is disabled and errors keep the sheet open to retry. A 409
/// (`RATING_ALREADY_UPDATED`) counts as sent.
struct OrderRatingSheet: View {
    /// Someone or something to rate in this order.
    struct Subject: Identifiable, Hashable {
        let target: RatingTarget
        let targetId: String
        /// Shown in the questions, e.g. the client's name or the service's title.
        let name: String

        var id: RatingTarget { target }
    }

    /// One selectable answer of step 2.
    struct Tag: Hashable {
        let title: String
        let icon: String
    }

    let orderId: String
    let raterId: String
    let subjects: [Subject]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    /// Optional so previews work without it; marks the rated service's score as outdated.
    @Environment(ScoreProvider.self) private var scoreProvider: ScoreProvider?

    private enum Step: Int, CaseIterable {
        case stars
        case details
        case comment
    }

    @State private var ratingProvider = RatingProvider()
    @State private var step: Step = .stars
    @State private var scores: [RatingTarget: Int] = [:]
    @State private var selectedTags: [RatingTarget: Set<String>] = [:]
    @State private var comment = ""
    @State private var isSending = false
    @State private var errorMessage: String? = nil
    /// Targets already accepted by the backend, so a retry only sends the rest.
    @State private var sentTargets: Set<RatingTarget> = []

    private let starSize: CGFloat = 36
    private let tagCornerRadius: CGFloat = 20

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var title: String {
        subjects.contains { $0.target == .CLIENT } ? "Calificar cliente" : "Calificar servicio"
    }

    private var allScored: Bool {
        subjects.allSatisfy { scores[$0.target] != nil }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: layout.spacingMedium) {
                    Text("Paso \(step.rawValue + 1) de \(Step.allCases.count)")
                        .fatumStyle(.footer)
                        .foregroundStyle(.text.opacity(0.7))

                    switch step {
                    case .stars: starsStep
                    case .details: detailsStep
                    case .comment: commentStep
                    }

                    if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle")
                            .fatumStyle(.footer)
                            .foregroundStyle(.text)
                    }

                    buttons
                }
                .screenPadding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(.brandSecondary)
            .animation(.easeInOut, value: step)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .fatumStyle(.subheader)
                        .foregroundStyle(.text)
                }

                if step != .stars {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button {
                            goBack()
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundStyle(.text)
                        }
                        .disabled(isSending)
                        .accessibilityLabel("Atrás")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(.brandSecondary)
        // The rating is required: the sheet only closes once it's sent.
        .interactiveDismissDisabled()
    }

    // MARK: - Steps

    private var starsStep: some View {
        VStack(alignment: .leading, spacing: layout.spacingMedium) {
            ForEach(subjects) { subject in
                VStack(alignment: .leading, spacing: layout.spacingSmall) {
                    Text(starsQuestion(for: subject))
                        .fatumStyle(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.text)

                    starRow(for: subject.target)
                }
            }
        }
    }

    private var detailsStep: some View {
        VStack(alignment: .leading, spacing: layout.spacingMedium) {
            ForEach(subjects) { subject in
                let isPositive = (scores[subject.target] ?? 0) >= 3
                VStack(alignment: .leading, spacing: layout.spacingSmall) {
                    Text(detailsQuestion(for: subject, isPositive: isPositive))
                        .fatumStyle(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.text)

                    Text("Puedes elegir varias")
                        .fatumStyle(.footer)
                        .foregroundStyle(.text.opacity(0.7))

                    FlowLayout(spacing: layout.tiny) {
                        ForEach(Self.tags(for: subject.target, isPositive: isPositive), id: \.self) { tag in
                            tagChip(tag, for: subject.target)
                        }
                    }
                }
            }
        }
    }

    private var commentStep: some View {
        LabeledTextEditor(
            label: "¿Algo más que quieras agregar?",
            placeholder: "Escribe tu comentario…",
            text: $comment,
            maxLength: RatingProvider.RatingRequest.commentMaxLength,
            isOptional: true
        )
    }

    // MARK: - Parts

    /// Five stars; tapping one fills it and every star before it.
    private func starRow(for target: RatingTarget) -> some View {
        let score = scores[target] ?? 0
        return HStack(spacing: layout.spacingSmall) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    scores[target] = value
                    errorMessage = nil
                } label: {
                    Image(systemName: value <= score ? "star.fill" : "star")
                        .resizable()
                        .scaledToFit()
                        .frame(width: starSize, height: starSize)
                        .foregroundStyle(value <= score ? Color.fatumAccent : Color.text)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(value == 1 ? "1 estrella" : "\(value) estrellas")
                .accessibilityAddTraits(value == score ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: score)
        .frame(maxWidth: .infinity)
    }

    /// Styled like `CategoryChipView`: bordered, or filled when selected.
    private func tagChip(_ tag: Tag, for target: RatingTarget) -> some View {
        let isSelected = selectedTags[target, default: []].contains(tag.title)
        let contentColor: Color = isSelected ? .brandPrimary : .text
        return Button {
            if isSelected {
                selectedTags[target, default: []].remove(tag.title)
            } else {
                selectedTags[target, default: []].insert(tag.title)
            }
        } label: {
            Label(tag.title, systemImage: tag.icon)
                .fatumStyle(.footer)
                .fontWeight(.bold)
                .foregroundStyle(contentColor)
                .lineLimit(1)
                .padding(.horizontal, layout.smallPadding + 1)
                .padding(.vertical, layout.smallPadding)
                .background(
                    RoundedRectangle(cornerRadius: tagCornerRadius)
                        .fill(isSelected ? Color.secondaryContainer : .clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: tagCornerRadius)
                        .stroke(isSelected ? Color.secondaryContainer : .text, lineWidth: 2)
                )
                .contentShape(RoundedRectangle(cornerRadius: tagCornerRadius))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// "Continuar" or "Enviar", plus "Omitir" on the optional steps.
    @ViewBuilder
    private var buttons: some View {
        let canContinue = step != .stars || allScored
        VStack(spacing: layout.spacingSmall) {
            Button {
                advance()
            } label: {
                if isSending {
                    ProgressView()
                } else {
                    Text(step == .comment ? "Enviar" : "Continuar")
                }
            }
            .buttonStyle(.fatumButton(variant: .third))
            .disabled(!canContinue || isSending)
            // `FatumButton` doesn't dim when disabled.
            .opacity(canContinue ? 1 : 0.5)

            if step != .stars {
                Button("Omitir") {
                    skip()
                }
                .buttonStyle(.fatumButton(variant: .outlined))
                .disabled(isSending)
            }
        }
    }

    // MARK: - Texts

    private func starsQuestion(for subject: Subject) -> String {
        switch subject.target {
        case .CLIENT: "¿Cómo fue tu experiencia con \(subject.name)?"
        case .PROFESSIONAL: "¿Cómo calificas a \(subject.name)?"
        case .SERVICE: "¿Cómo calificas el servicio \"\(subject.name)\"?"
        }
    }

    private func detailsQuestion(for subject: Subject, isPositive: Bool) -> String {
        switch (subject.target, isPositive) {
        case (.SERVICE, true): "¿Qué fue lo que más te gustó del servicio?"
        case (.SERVICE, false): "¿Qué salió mal con el servicio?"
        case (_, true): "¿Qué fue lo que más te gustó de \(subject.name)?"
        case (_, false): "¿Qué salió mal con \(subject.name)?"
        }
    }

    /// Options of step 2 for each target, depending on whether the score was 3 or more.
    private static func tags(for target: RatingTarget, isPositive: Bool) -> [Tag] {
        switch (target, isPositive) {
        case (.CLIENT, true):
            [
                Tag(title: "Amable", icon: "face.smiling"),
                Tag(title: "Puntual", icon: "clock.badge.checkmark"),
                Tag(title: "Lugar limpio", icon: "sparkles"),
                Tag(title: "Buena comunicación", icon: "bubble.left.and.bubble.right"),
                Tag(title: "Pagó a tiempo", icon: "creditcard"),
                Tag(title: "Instrucciones claras", icon: "list.bullet.clipboard")
            ]
        case (.CLIENT, false):
            [
                Tag(title: "Muy grosero", icon: "hand.raised.slash"),
                Tag(title: "No estaba a tiempo", icon: "clock.badge.exclamationmark"),
                Tag(title: "Lugar sucio", icon: "trash"),
                Tag(title: "Mala comunicación", icon: "bubble.left.and.exclamationmark.bubble.right"),
                Tag(title: "Problemas con el pago", icon: "creditcard.trianglebadge.exclamationmark"),
                Tag(title: "Pidió más de lo acordado", icon: "plus.circle")
            ]
        case (.PROFESSIONAL, true):
            [
                Tag(title: "Muy amable", icon: "face.smiling"),
                Tag(title: "Puntual", icon: "clock.badge.checkmark"),
                Tag(title: "Limpio y ordenado", icon: "sparkles"),
                Tag(title: "Muy profesional", icon: "medal"),
                Tag(title: "Buena comunicación", icon: "bubble.left.and.bubble.right"),
                Tag(title: "Explica bien", icon: "lightbulb")
            ]
        case (.PROFESSIONAL, false):
            [
                Tag(title: "Muy grosero", icon: "hand.raised.slash"),
                Tag(title: "Llegó tarde", icon: "clock.badge.exclamationmark"),
                Tag(title: "Dejó desorden", icon: "trash"),
                Tag(title: "Poco profesional", icon: "person.crop.circle.badge.exclamationmark"),
                Tag(title: "Mala comunicación", icon: "bubble.left.and.exclamationmark.bubble.right"),
                Tag(title: "Poco higiénico", icon: "hand.raised")
            ]
        case (.SERVICE, true):
            [
                Tag(title: "Excelente calidad", icon: "star.circle"),
                Tag(title: "Como lo esperaba", icon: "checkmark.seal"),
                Tag(title: "Rápido", icon: "bolt"),
                Tag(title: "Buen precio", icon: "tag"),
                Tag(title: "Lo recomendaría", icon: "hand.thumbsup")
            ]
        case (.SERVICE, false):
            [
                Tag(title: "Mala calidad", icon: "hand.thumbsdown"),
                Tag(title: "No fue lo acordado", icon: "xmark.seal"),
                Tag(title: "Tardó demasiado", icon: "hourglass"),
                Tag(title: "Muy costoso", icon: "dollarsign.circle"),
                Tag(title: "Resultado incompleto", icon: "exclamationmark.triangle")
            ]
        }
    }

    // MARK: - Actions

    private func goBack() {
        errorMessage = nil
        if let previous = Step(rawValue: step.rawValue - 1) {
            step = previous
        }
    }

    private func advance() {
        errorMessage = nil
        if let next = Step(rawValue: step.rawValue + 1) {
            step = next
        } else {
            submit()
        }
    }

    /// Skipping clears what was entered in that step.
    private func skip() {
        switch step {
        case .stars:
            return
        case .details:
            selectedTags = [:]
            advance()
        case .comment:
            comment = ""
            submit()
        }
    }

    /// Sends one rating per subject, skipping those already accepted.
    private func submit() {
        guard !isSending else { return }
        isSending = true
        errorMessage = nil

        Task {
            defer { isSending = false }
            let trimmedComment = comment.trimmingCharacters(in: .whitespacesAndNewlines)

            for subject in subjects where !sentTargets.contains(subject.target) {
                guard let score = scores[subject.target] else { return }
                // Kept in the order they're listed, not the order they were tapped.
                let isPositive = score >= 3
                let tags = Self.tags(for: subject.target, isPositive: isPositive)
                    .map(\.title)
                    .filter { selectedTags[subject.target, default: []].contains($0) }

                let request = RatingProvider.RatingRequest(
                    orderId: orderId,
                    raterId: raterId,
                    target: subject.target,
                    targetId: subject.targetId,
                    score: score,
                    gustos: isPositive && !tags.isEmpty ? tags : nil,
                    disgustos: !isPositive && !tags.isEmpty ? tags : nil,
                    comentario: trimmedComment.isEmpty ? nil : trimmedComment
                )

                switch await ratingProvider.rate(request) {
                case .rated, .alreadyRated:
                    sentTargets.insert(subject.target)
                    // Home's card fetches the new average the next time it appears.
                    if subject.target == .SERVICE {
                        scoreProvider?.invalidateServiceScore(serviceId: subject.targetId)
                    }
                case .failed(let message):
                    errorMessage = message
                    return
                }
            }
            dismiss()
        }
    }
}

#Preview {
    Color.brandSecondary
        .sheet(isPresented: .constant(true)) {
            OrderRatingSheet(
                orderId: "order-123",
                raterId: "client-123",
                subjects: [
                    .init(target: .PROFESSIONAL, targetId: "provider-456", name: "Ana Gómez"),
                    .init(target: .SERVICE, targetId: "service-789", name: "Corte y cepillado")
                ]
            )
        }
}
