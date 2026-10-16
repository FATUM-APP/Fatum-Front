//
//  FatumApp.swift
//  Fatum
//
//  Created by Camilo Castaño on 4/04/26.
//

import SwiftUI
import Amplify
import AWSCognitoAuthPlugin

@main
struct FatumApp: App {
    @State private var userProvider = UserProvider()
    @State private var showVerificationFlow = false

    init() {
        configureAmplify()
    }

    private func configureAmplify() {
        do {
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.configure()
        } catch {
            print("Error configurando Amplify: \(error)")
        }
    }

    private var needsAuthentication: Bool {
        guard let user = userProvider.currentUser else { return false }
        return !user.isAuthenticated
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if userProvider.isCheckingSession {
                        SplashScreen()
                    } else if userProvider.isLoggedIn {
                        MainTabView()
                    } else {
                        ContentView()
                    }
                }
                .environment(userProvider)
                .task {
                    await userProvider.loadCurrentUser()
                }

                // Authentication dialog
                if userProvider.isLoggedIn && needsAuthentication && !showVerificationFlow {
                    RequiredActionDialog(description: "No estas autentificado") {
                        Button {
                            showVerificationFlow = true
                        } label: {
                            Text("Autentificarse")
                        }
                        .buttonStyle(.fatumButton(variant: .third))
                    }
                }
            }
            .fullScreenCover(isPresented: $showVerificationFlow) {
                VerificationFlowView()
                    .environment(userProvider)
                    .interactiveDismissDisabled()
            }
        }
    }
}
