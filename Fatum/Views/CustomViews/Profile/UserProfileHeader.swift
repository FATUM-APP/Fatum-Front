//
//  UserProfileHeader.swift
//  Fatum
//
//  Created by Camilo Castaño on 5/8/26.
//

import SwiftUI

struct UserProfileHeader: View {
    @Environment(UserProvider.self) private var userProvider
    @Environment(ScoreProvider.self) private var scoreProvider
    @Environment(\.horizontalSizeClass) private var sizeClass

    // Profile image (read-only here; it is changed from ManageProfileScreen)
    @State private var existingImageURL: String? = nil
    @State private var isLoadingImage = true

    private let avatarSize: CGFloat = 56
    private let avatarIconSize: CGFloat = 28

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private var user: FatumUser? {
        userProvider.currentUser
    }

    /// The user's average rating, or a dash until it loads.
    private var ratingText: String {
        guard let userId = user?.userId, let average = scoreProvider.userAverages[userId] else { return "—" }
        return average.formatted(.number.precision(.fractionLength(1)))
    }

    var body: some View {
        HStack(spacing: layout.internalSpacing) {
            // First column: username + rating
            VStack(alignment: .leading, spacing: layout.spacingSmall) {
                // Row 1: Username + verified badge
                HStack(spacing: layout.spacingSmall) {
                    Text(user?.username ?? "Usuario")
                        .fatumStyle(.subheader)
                        .foregroundStyle(.text)

                    if user?.isAuthenticated == true {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(.text)
                    }
                }

                // Row 2: Rating + star icon
                HStack(spacing: layout.spacingSmall) {
                    Text(ratingText)
                        .fatumStyle(.caption)
                        .foregroundStyle(.text)

                    Image(systemName: "star.fill")
                        .foregroundStyle(.text)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Calificación \(ratingText) de 5")
            }

            Spacer()

            // Second column: avatar
            avatar
        }
        .padding(layout.internalPadding)
        .background(.clear)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.border),
            alignment: .bottom
        )
        .task {
            await loadExistingProfileImage()
        }
        // Refetched every time the profile shows, so new ratings appear.
        .task(id: user?.userId) {
            guard let userId = user?.userId else { return }
            await scoreProvider.loadUserScore(userId: userId)
        }
    }

    // MARK: - Avatar

    /// Spinner while loading, the remote photo if there is one, otherwise the placeholder.
    @ViewBuilder
    private var avatar: some View {
        if isLoadingImage {
            Circle()
                .fill(Color.primaryContainer)
                .frame(width: avatarSize, height: avatarSize)
                .overlay(ProgressView().tint(.brandPrimary))
        } else if let existingImageURL, let url = URL(string: existingImageURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                        .frame(width: avatarSize, height: avatarSize)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.border, lineWidth: 2))
                default:
                    avatarPlaceholder
                }
            }
        } else {
            avatarPlaceholder
        }
    }

    private var avatarPlaceholder: some View {
        Circle()
            .fill(.primaryContainer)
            .frame(width: avatarSize, height: avatarSize)
            .overlay(
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: avatarIconSize, height: avatarIconSize)
                    .foregroundStyle(.brandPrimary)
            )
    }

    private func loadExistingProfileImage() async {
        isLoadingImage = true
        existingImageURL = await userProvider.fetchProfileImageURL()
        isLoadingImage = false
    }
}

#Preview {
    let provider = UserProvider()
    UserProfileHeader()
        .background(.brandSecondary)
        .environment(provider)
        .environment(ScoreProvider())
}
