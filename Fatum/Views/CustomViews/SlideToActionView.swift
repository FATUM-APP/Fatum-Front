//
//  SlideToActionView.swift
//  Fatum
//

import SwiftUI

/// Uber-style two-way slider: the knob starts in the center; sliding it to the
/// right runs `onPositive` and to the left `onNegative`. The action only runs
/// when the knob is released near the end, so a short drag springs back.
///
/// Without `negativeTitle` it only slides to the right. A haptic marks the
/// point where releasing runs the action, and another one the action itself.
struct SlideToActionView: View {
    let positiveTitle: String
    /// `nil` for a slider with only the positive action.
    var negativeTitle: String? = nil
    var isEnabled: Bool = true
    let onPositive: () -> Void
    var onNegative: () -> Void = {}

    private enum Direction {
        case positive
        case negative
    }

    @Environment(\.horizontalSizeClass) private var sizeClass

    /// Knob position from the center: positive to the right, negative to the left.
    @State private var offset: CGFloat = 0
    /// The side whose action runs if the knob is released now.
    @State private var armedDirection: Direction? = nil
    /// The action that just ran; drives the completion haptic.
    @State private var completedDirection: Direction? = nil

    private let height: CGFloat = 52
    private let knobInset: CGFloat = 4
    /// Share of the way to the end where releasing runs the action.
    private let threshold: CGFloat = 0.8

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var knobSize: CGFloat {
        height - knobInset * 2
    }

    var body: some View {
        GeometryReader { geometry in
            let maxOffset = max(0, (geometry.size.width - knobSize) / 2 - knobInset)
            let halfWidth = (geometry.size.width - knobSize) / 2
            let progress = maxOffset > 0 ? offset / maxOffset : 0

            ZStack {
                Capsule()
                    .fill(Color.secondaryContainer)

                // Fills from the center to the knob as it moves.
                Rectangle()
                    .fill(Color.brandPrimary.opacity(0.2))
                    .frame(width: abs(offset))
                    .offset(x: offset / 2)

                HStack(spacing: 0) {
                    sideLabel(negativeTitle, icon: "chevron.left", iconFirst: true)
                        .frame(width: halfWidth)
                        .opacity(1 - max(0, progress))

                    Spacer(minLength: knobSize)

                    sideLabel(positiveTitle, icon: "chevron.right", iconFirst: false)
                        .frame(width: halfWidth)
                        .opacity(1 + min(0, progress))
                }

                knob
                    .offset(x: offset)
                    .gesture(dragGesture(maxOffset: maxOffset))
            }
            .clipShape(Capsule())
        }
        .frame(height: height)
        .opacity(isEnabled ? 1 : 0.5)
        .allowsHitTesting(isEnabled)
        .sensoryFeedback(.selection, trigger: armedDirection) { _, new in new != nil }
        .sensoryFeedback(trigger: completedDirection) { _, new in
            switch new {
            case .positive: .success
            case .negative: .warning
            case nil: nil
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityActions {
            if isEnabled {
                Button(positiveTitle, action: onPositive)
                if let negativeTitle {
                    Button(negativeTitle, action: onNegative)
                }
            }
        }
    }

    private var knob: some View {
        Circle()
            .fill(Color.brandPrimary)
            .frame(width: knobSize, height: knobSize)
            .overlay(
                Image(systemName: negativeTitle == nil ? "arrow.right" : "arrow.left.and.right")
                    .fontWeight(.bold)
                    .foregroundStyle(.brandSecondary)
            )
            .contentShape(Circle())
    }

    @ViewBuilder
    private func sideLabel(_ title: String?, icon: String, iconFirst: Bool) -> some View {
        if let title {
            HStack(spacing: layout.tiny) {
                if iconFirst { Image(systemName: icon) }
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if !iconFirst { Image(systemName: icon) }
            }
            .fatumStyle(.footer)
            .fontWeight(.bold)
            .foregroundStyle(.brandPrimary)
            .padding(.horizontal, layout.tinyPadding)
        } else {
            Color.clear
        }
    }

    private func dragGesture(maxOffset: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 5)
            .onChanged { value in
                let lowerBound = negativeTitle == nil ? 0 : -maxOffset
                offset = min(max(value.translation.width, lowerBound), maxOffset)

                if offset >= maxOffset * threshold {
                    armedDirection = .positive
                } else if offset <= -maxOffset * threshold {
                    armedDirection = .negative
                } else {
                    armedDirection = nil
                }
            }
            .onEnded { _ in
                guard let direction = armedDirection else {
                    withAnimation(.spring) { offset = 0 }
                    return
                }

                withAnimation(.snappy) {
                    offset = direction == .positive ? maxOffset : -maxOffset
                }
                completedDirection = direction
                direction == .positive ? onPositive() : onNegative()

                // Back to the center, ready for the order's next step.
                Task {
                    try? await Task.sleep(for: .milliseconds(600))
                    withAnimation(.spring) { offset = 0 }
                    armedDirection = nil
                    completedDirection = nil
                }
            }
    }

    private var accessibilityText: String {
        if let negativeTitle {
            return "Desliza a la derecha para \(positiveTitle) o a la izquierda para \(negativeTitle)"
        }
        return "Desliza a la derecha para \(positiveTitle)"
    }
}

#Preview {
    VStack(spacing: 20) {
        SlideToActionView(positiveTitle: "Aceptar", negativeTitle: "Rechazar", onPositive: {}, onNegative: {})
        SlideToActionView(positiveTitle: "Empieza la entrega", negativeTitle: "No entregado", onPositive: {}, onNegative: {})
        SlideToActionView(positiveTitle: "Iniciar", isEnabled: false, onPositive: {})
    }
    .padding(20)
    .background(.brandSecondary)
}
