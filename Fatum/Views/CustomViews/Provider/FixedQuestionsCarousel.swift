//
//  FixedQuestionsCarousel.swift
//  Fatum
//

import SwiftUI

/// Shows the fixed questions one card at a time. Swipe to the next card to
/// answer the next question, and back to return to the previous one. A
/// "Pregunta X de Y" label and page dots show where the client is.
struct FixedQuestionsCarousel: View {
    let questions: [FixedQuestion]

    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var currentID: FixedQuestion.ID? = nil

    private let dotSize: CGFloat = 6

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var currentIndex: Int {
        questions.firstIndex { $0.id == currentID } ?? 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: layout.internalSpacing) {
            ScrollView(.horizontal, showsIndicators: false) {
                // Not lazy, so every card keeps its answer while swiping and all share the tallest height.
                HStack(alignment: .top, spacing: layout.internalSpacing) {
                    ForEach(questions) { question in
                        FixedQuestionAnswerView(question: question)
                            .containerRelativeFrame(.horizontal)
                            .id(question.id)
                    }
                }
                // Height of the tallest card; the shorter ones stretch to match it.
                .fixedSize(horizontal: false, vertical: true)
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $currentID)

            if questions.count > 1 {
                HStack {
                    Text("Pregunta \(currentIndex + 1) de \(questions.count)")
                        .fatumStyle(.footer)
                        .foregroundStyle(.text)

                    Spacer()

                    HStack(spacing: layout.spacingSmall) {
                        ForEach(questions.indices, id: \.self) { index in
                            Circle()
                                .fill(index == currentIndex ? Color.brandPrimary : Color.border)
                                .frame(width: dotSize, height: dotSize)
                        }
                    }
                    .accessibilityHidden(true)
                }
                .animation(.easeInOut, value: currentIndex)
            }
        }
        // Questions can be added or removed from the edit sheet; stay on a card that still exists.
        .onChange(of: questions) {
            if !questions.contains(where: { $0.id == currentID }) {
                currentID = questions.first?.id
            }
        }
    }
}

#Preview {
    FixedQuestionsCarousel(questions: [
        FixedQuestion(question: "¿Tienes alguna alergia?", type: .TEXT),
        FixedQuestion(question: "¿Primera vez?", type: .BOOLEAN),
        FixedQuestion(question: "Largo del cabello", type: .SINGLE_CHOICE, options: ["Corto", "Medio", "Largo"])
    ])
    .padding(20)
    .background(.brandSecondary)
}
