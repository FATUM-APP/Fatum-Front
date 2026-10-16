//
//  AddAddressScreen.swift
//  Fatum
//

import SwiftUI

/// Form to create a new address, presented as a full-screen cover from `AddressesScreen`.
///
/// Fields mirror the backend's `NewAddressRequest`: country, state, city and
/// residence are required, alias is optional. The backend stores the alias
/// trimmed and lowercased, defaulting to the residence when none is given.
///
/// Saving is two steps: create the address, then (if the switch is on) mark it
/// as principal. On success `onSaved` receives a message for the parent to show
/// and the screen dismisses; on failure the error is shown in a toast here.
struct AddAddressScreen: View {
    /// Called after the address was created, before dismissing. The message
    /// summarises the result, including a partial failure of the principal step.
    var onSaved: (_ message: String) -> Void

    @Environment(AddressProvider.self) private var addressProvider
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dismiss) private var dismiss

    @State private var country: String = ""
    @State private var state: String = ""
    @State private var city: String = ""
    @State private var residence: String = ""
    @State private var alias: String = ""
    @State private var setAsPrincipal = false

    @State private var isLoading = false
    @State private var showToast = false
    @State private var toastMessage: String = ""

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    private typealias Request = AddressProvider.NewAddressRequest

    /// Every required field has a non-blank value and nothing is in flight.
    private var canSave: Bool {
        !isLoading
            && !trimmed(country).isEmpty
            && !trimmed(state).isEmpty
            && !trimmed(city).isEmpty
            && !trimmed(residence).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: layout.spacingMedium) {
                        // Title + subtitle
                        VStack(spacing: layout.spacingSmall) {
                            Text("Nueva dirección")
                                .fatumStyle(.header)
                                .foregroundStyle(.text)

                            Text("Ingresa tu dirección manualmente")
                                .fatumStyle(.body)
                                .foregroundStyle(.text)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)

                        // Fields
                        LabeledTextField(
                            label: "País",
                            placeholder: "Ej. Colombia",
                            text: $country,
                            icon: "globe.americas",
                            maxLength: Request.countryMaxLength,
                            textContentType: .countryName
                        )

                        LabeledTextField(
                            label: "Departamento",
                            placeholder: "Ej. Antioquia",
                            text: $state,
                            icon: "map",
                            maxLength: Request.stateMaxLength,
                            textContentType: .addressState
                        )

                        LabeledTextField(
                            label: "Ciudad",
                            placeholder: "Ej. Envigado",
                            text: $city,
                            icon: "building.2",
                            maxLength: Request.cityMaxLength,
                            textContentType: .addressCity
                        )

                        LabeledTextField(
                            label: "Dirección",
                            placeholder: "Ej. Calle 45 #12-34, Apto 502",
                            text: $residence,
                            icon: "house",
                            maxLength: Request.residenceMaxLength,
                            textContentType: .fullStreetAddress
                        )

                        LabeledTextField(
                            label: "Alias",
                            placeholder: "Ej. Casa de mamá",
                            text: $alias,
                            icon: "tag",
                            isOptional: true,
                            maxLength: Request.aliasMaxLength,
                            submitLabel: .done
                        )

                        LabeledToggle(
                            title: "Establecer como dirección principal",
                            message: "Se usará por defecto al solicitar servicios",
                            isOn: $setAsPrincipal
                        )
                    }
                    .screenPadding()
                }

                // Save + cancel
                VStack(spacing: layout.internalSpacing) {
                    Button {
                        save()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.brandSecondary)
                        } else {
                            Text("Guardar dirección")
                        }
                    }
                    .buttonStyle(.fatumButton(variant: .third))
                    .disabled(!canSave)

                    Button("Cancelar") {
                        dismiss()
                    }
                    .buttonStyle(.fatumButton(variant: .outlined, foregroundColor: .text))
                    .disabled(isLoading)
                }
                .screenPadding([.horizontal, .bottom])
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
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.text)
                    }
                    .disabled(isLoading)
                }
            }
        }
    }

    // MARK: - Actions

    private func save() {
        isLoading = true
        let trimmedAlias = trimmed(alias)
        let body = Request(
            residence: trimmed(residence),
            alias: trimmedAlias.isEmpty ? nil : trimmedAlias,
            city: trimmed(city),
            state: trimmed(state),
            country: trimmed(country)
        )

        Task {
            // Step 1: create the address. Stop here if it fails.
            guard await addressProvider.createAddress(body) else {
                isLoading = false
                showMessage(addressProvider.error ?? "Error al guardar la dirección")
                return
            }

            // Step 2: mark it as principal, now that it exists in the list.
            // Use the alias exactly as the backend stored it: trimmed and
            // lowercased, or the residence when none was typed.
            var resultMessage = "Dirección guardada"
            if setAsPrincipal {
                let storedAlias = body.alias?.lowercased() ?? body.residence
                let madePrincipal = await addressProvider.makePrincipal(alias: storedAlias)
                resultMessage = madePrincipal
                    ? "Dirección guardada como principal"
                    : "Dirección guardada, pero no se pudo establecer como principal"
            }

            isLoading = false
            onSaved(resultMessage)
            dismiss()
        }
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func showMessage(_ message: String) {
        toastMessage = message
        withAnimation {
            showToast = true
        }
    }
}

#Preview {
    let provider = AddressProvider()
    AddAddressScreen(onSaved: { _ in })
        .environment(provider)
}
