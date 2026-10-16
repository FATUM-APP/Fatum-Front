import SwiftUI

struct AppGradient {
    static let mainBackground = LinearGradient(
        stops: [
            .init(color: .brandSecondary,           location: 0.0),
            .init(color: .secondaryGradient, location: 0.25),
            .init(color: .thirdGradient,     location: 0.5),
            .init(color: .fourthGradient,    location: 0.75),
            .init(color: .brandPrimary,         location: 1.0),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}
