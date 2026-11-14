//
//  FavoriteSwipeActions.swift
//  Fatum
//

import SwiftUI

extension View {
    /// Favorite actions on a service card, for clients only (never in "Mis servicios").
    ///
    /// A full swipe to the right adds the service and a full swipe to the left
    /// removes it; a short swipe reveals the button instead. Only the edge that
    /// applies is registered: a favorite can only be removed, the rest only added,
    /// so the card can't be dragged toward an empty side.
    /// The containing `ScrollView` needs `favoriteSwipeContainer()`.
    ///
    /// `removesCard` is `true` only where removing also takes the card out of the
    /// list ("Favoritos"). A destructive full swipe slides the card away expecting
    /// it to leave, so on Home, where it stays, removing isn't destructive.
    ///
    /// Swipe actions outside `List` need iOS 27, so on iOS 26 the same actions
    /// live in a context menu (long press). VoiceOver gets them on both.
    ///
    /// Don't wrap the card in a `Button`: the swipe cancels its touch and leaves
    /// it stuck in the pressed (dimmed) state. Use `onTapGesture` instead.
    func favoriteSwipeActions(
        isFavorite: Bool,
        removesCard: Bool = false,
        onAdd: @escaping () -> Void,
        onRemove: @escaping () -> Void
    ) -> some View {
        modifier(FavoriteSwipeActionsModifier(
            isFavorite: isFavorite,
            removesCard: removesCard,
            onAdd: onAdd,
            onRemove: onRemove
        ))
    }

    /// Lets the `ScrollView` coordinate the cards' swipe actions: one open at a
    /// time, closed when scrolling or tapping elsewhere. Does nothing before iOS 27.
    @ViewBuilder
    func favoriteSwipeContainer() -> some View {
        if #available(iOS 27, *) {
            swipeActionsContainer()
        } else {
            self
        }
    }
}

private struct FavoriteSwipeActionsModifier: ViewModifier {
    let isFavorite: Bool
    let removesCard: Bool
    let onAdd: () -> Void
    let onRemove: () -> Void

    func body(content: Content) -> some View {
        Group {
            if #available(iOS 27, *) {
                if isFavorite {
                    content
                        .swipeActions(edge: .trailing) {
                            removeButton
                        }
                } else {
                    content
                        .swipeActions(edge: .leading) {
                            addButton
                        }
                }
            } else {
                content
                    .contextMenu {
                        if isFavorite {
                            removeButton
                        } else {
                            addButton
                        }
                    }
            }
        }
        .accessibilityAction(named: isFavorite ? "Quitar de favoritos" : "Agregar a favoritos") {
            isFavorite ? onRemove() : onAdd()
        }
    }

    private var addButton: some View {
        Button(action: onAdd) {
            Label("Agregar a favoritos", systemImage: "heart")
        }
        .tint(.fatumAccent)
    }

    @ViewBuilder
    private var removeButton: some View {
        if removesCard {
            Button(role: .destructive, action: onRemove) {
                Label("Quitar de favoritos", systemImage: "heart.slash")
            }
        } else {
            Button(action: onRemove) {
                Label("Quitar de favoritos", systemImage: "heart.slash")
            }
            .tint(.red)
        }
    }
}
