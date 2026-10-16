//
//  ContentView.swift
//  Fatum
//
//  Created by Camilo Castaño on 4/04/26.
//

import SwiftUI

/// Welcome screen and root of the navigation stack used before sign-in.
/// Owns the `Router<AuthRoute>` and shares it with every screen in the stack.
struct ContentView: View {
    
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var currentIndex = 0
    @State private var scrollDirection = 1
    @State private var router = Router<AuthRoute>()
    
    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }
    
    var body: some View {
        NavigationStack(path: $router.path) {
            ZStack {
                AppGradient.mainBackground
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    
                    // Carrusel
                    TabView(selection: $currentIndex) {
                        LoginTab(image: "login", title: "Te damos la bienvenida a FATUM", body: "Donde la confianza vive en cada servicio")
                            .tag(0)
                        
                        LoginTab(image: "login2", title: "Encuentra profesionales de confianza", body: "Servicios personalizados para tus necesidades")
                            .tag(1)
                        
                        LoginTab(image: "login3", title: "Haz crecer tu negocio", body: "Crecce profesionalmente desde la comodidad de tu hogar")
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    
                    Spacer()
                    
                    // Botones
                    VStack(spacing: layout.internalSpacing) {
                        Button("Regístrarse") {
                            router.push(.register)
                        }
                        .buttonStyle(.fatumButton(variant: .primary))
                        
                        Button("Iniciar Sesión") {
                            router.push(.login)
                        }
                        .buttonStyle(.fatumButton(variant: .secondary))
                        
                    }
                }
                .screenPadding()
            }
            .onAppear {
                startAutoScroll()
            }
            .authDestinations()
        }
        .environment(router)
    }
    
    private func startAutoScroll() {
        Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { _ in
            withAnimation(.easeInOut(duration: 0.5)) {
                if currentIndex == 2 {
                    scrollDirection = -1
                } else if currentIndex == 0 {
                    scrollDirection = 1
                }
                currentIndex += scrollDirection
            }
        }
    }
}

struct LoginView: View {
    @Environment(Router<AuthRoute>.self) private var router
    @Environment(UserProvider.self) private var userProvider
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    var body: some View {
        ZStack {
            AppGradient.mainBackground
                .ignoresSafeArea()

            GeometryReader { geometry in
                VStack(spacing: layout.externalSpacing) {

                    // Text Area
                    VStack(spacing: layout.internalSpacing) {
                        Image("FatumLogin")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width * 0.4)

                        Text("Iniciar Sesión")
                            .fatumStyle(.subheader)
                            .foregroundStyle(.loginText)

                        Text("Bienvenido devuelta! Ingresa tu correo y contraseña")
                            .fatumStyle(.body)
                            .foregroundStyle(.loginText)
                            .multilineTextAlignment(.center)
                    }

                    // Form
                    VStack(spacing: layout.spacingMedium) {
                        FatumTextField(
                            placeholder: "Correo electrónico",
                            text: $email,
                            prefixIcon: "envelope",
                            keyboardType: .emailAddress,
                            textContentType: .emailAddress,
                            submitLabel: .next,
                            allowedCharacters: { oldValue, newValue in
                                let noSpaces = newValue.filter { $0 != " " }
                                let atCount = noSpaces.filter { $0 == "@" }.count
                                if atCount > 1 {
                                    return oldValue
                                }
                                return noSpaces
                            }
                        )

                        FatumTextField(
                            placeholder: "Contraseña",
                            text: $password,
                            prefixIcon: "lock",
                            isSecure: true,
                            textContentType: .password,
                            submitLabel: .done,
                            allowedCharacters: { _, newValue in
                                newValue.filter { $0 != " " }
                            }
                        )

                        if let errorMessage {
                            Text(errorMessage)
                                .fatumStyle(.footer)
                                .foregroundStyle(.errorBorderLogin)
                                .multilineTextAlignment(.center)
                        }

                        Button {
                            signIn()
                        } label: {
                            if isLoading {
                                ProgressView()
                                    .tint(.brandPrimary)
                            } else {
                                Text("Iniciar sesión")
                            }
                        }
                        .buttonStyle(.fatumButton(variant: .primary))
                        .disabled(isLoading)

                        Button("¿Olvidaste tu contraseña?") {
                            router.push(.passwordReset)
                        }
                        .fatumStyle(.body)
                        .fontWeight(.bold)
                        .foregroundStyle(.loginText)
                    }

                    Spacer()

                    Button("Crear cuenta nueva") {
                        router.push(.register)
                    }
                    .buttonStyle(.fatumButton(variant: .secondary))
                }
                .screenPadding()
                .frame(maxWidth: .infinity)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    router.popToRoot()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.brandPrimary)
                }
            }
        }
    }

    private func signIn() {
        isLoading = true
        errorMessage = nil

        Task {
            let success = await userProvider.signIn(email: email, password: password)
            isLoading = false
            if !success {
                errorMessage = userProvider.error ?? "Error al iniciar sesión"
            }
        }
    }
}

struct RegisterView: View {
    @Environment(Router<AuthRoute>.self) private var router
    @Environment(UserProvider.self) private var userProvider

    // Step tracking
    @State private var currentStep: RegisterStep = .basicData

    // Step 1: Basic Data
    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var selectedGender: Gender = .MALE

    // Step 2: Account Info
    @State private var email: String = ""
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""

    // Step 3: Identity
    @State private var birthday: Date = Date()
    @State private var birthdayError: String? = nil
    @State private var document: String = ""
    @State private var selectedDocumentType: DocumentType = .ID

    // General state
    @State private var isLoading = false
    @State private var errorMessage: String? = nil

    @Environment(\.horizontalSizeClass) private var sizeClass

    private var layout: ResponsiveLayout {
        ResponsiveLayout(isCompact: sizeClass == .compact)
    }

    enum RegisterStep {
        case basicData
        case accountInfo
        case identity
    }

    private var stepIndex: Int {
        switch currentStep {
        case .basicData: return 0
        case .accountInfo: return 1
        case .identity: return 2
        }
    }

    private var isAtLeast18: Bool {
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthday, to: Date())
        return (ageComponents.year ?? 0) >= 18
    }

    // MARK: - Validation

    private func validateCurrentStep() -> Bool {
        errorMessage = nil
        birthdayError = nil

        switch currentStep {
        case .basicData:
            let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedName.isEmpty {
                errorMessage = "El nombre es obligatorio"
                return false
            }
            let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedPhone.isEmpty {
                errorMessage = "El teléfono es obligatorio"
                return false
            }
            return true

        case .accountInfo:
            let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedEmail.isEmpty {
                errorMessage = "El correo electrónico es obligatorio"
                return false
            }
            let trimmedUsername = username.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedUsername.isEmpty {
                errorMessage = "El nombre de usuario es obligatorio"
                return false
            }
            if password.isEmpty {
                errorMessage = "La contraseña es obligatoria"
                return false
            }
            if password != confirmPassword {
                errorMessage = "Las contraseñas no coinciden"
                return false
            }
            return true

        case .identity:
            if !isAtLeast18 {
                birthdayError = "Debes tener al menos 18 años para registrarte"
                return false
            }
            let trimmedDocument = document.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedDocument.isEmpty {
                errorMessage = "El número de documento es obligatorio"
                return false
            }
            return true
        }
    }

    // MARK: - Actions

    private func advanceStep() {
        guard validateCurrentStep() else { return }
        withAnimation {
            switch currentStep {
            case .basicData:
                currentStep = .accountInfo
            case .accountInfo:
                currentStep = .identity
            case .identity:
                signUp()
            }
        }
    }

    private func goBack() {
        withAnimation {
            switch currentStep {
            case .basicData:
                router.popToRoot()
            case .accountInfo:
                currentStep = .basicData
            case .identity:
                currentStep = .accountInfo
            }
        }
    }

    private func signUp() {
        guard validateCurrentStep() else { return }

        isLoading = true
        errorMessage = nil

        let request = UserProvider.SignUpRequest(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone,
            gender: selectedGender,
            email: email,
            username: username.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            birthday: birthday,
            document: document.trimmingCharacters(in: .whitespacesAndNewlines),
            documentType: selectedDocumentType
        )

        Task {
            switch await userProvider.signUp(request) {
            case .needsConfirmation:
                isLoading = false
                router.push(.confirmEmail(email: email, password: password))
            case .completed:
                // No code needed: sign in so FatumApp swaps the root to MainTabView.
                let signedIn = await userProvider.signIn(email: email, password: password)
                isLoading = false
                if !signedIn {
                    errorMessage = userProvider.error ?? "Error al iniciar sesión"
                }
            case nil:
                isLoading = false
                errorMessage = userProvider.error ?? "Error al registrar el usuario"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppGradient.mainBackground
                .ignoresSafeArea()

            GeometryReader { geometry in
                VStack(spacing: 0) {
                    // Step indicator
                    stepIndicator

                    ScrollView {
                        VStack(spacing: layout.externalSpacing) {
                            // Header
                            VStack(spacing: layout.internalSpacing) {
                                Image("FatumLogin")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: geometry.size.width * 0.4)

                                Text(stepTitle)
                                    .fatumStyle(.subheader)
                                    .foregroundStyle(.loginText)

                                Text(stepSubtitle)
                                    .fatumStyle(.body)
                                    .foregroundStyle(.loginText)
                                    .multilineTextAlignment(.center)
                            }

                            // Form fields per step
                            VStack(spacing: layout.spacingMedium) {
                                switch currentStep {
                                case .basicData:
                                    basicDataFields
                                case .accountInfo:
                                    accountInfoFields
                                case .identity:
                                    identityFields
                                }

                                if let errorMessage {
                                    Text(errorMessage)
                                        .fatumStyle(.footer)
                                        .foregroundStyle(.errorBorderLogin)
                                        .multilineTextAlignment(.center)
                                }

                                // Action button
                                Button {
                                    advanceStep()
                                } label: {
                                    if isLoading {
                                        ProgressView()
                                            .tint(.brandPrimary)
                                    } else {
                                        Text(currentStep == .identity ? "Registrar Usuario" : "Siguiente")
                                    }
                                }
                                .buttonStyle(.fatumButton(variant: .primary))
                                .disabled(isLoading)
                            }

                            

                            Button("Ya tengo una cuenta") {
                                router.replaceAll(with: .login)
                            }
                            .buttonStyle(.fatumButton(variant: .secondary))
                        }
                        .screenPadding()
                        .frame(maxWidth: .infinity)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    goBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundStyle(.brandPrimary)
                }
            }
        }
    }

    // MARK: - Step Indicator

    private var stepIndicator: some View {
        HStack(spacing: layout.spacingSmall) {
            ForEach(0..<3) { index in
                Capsule()
                    .fill(index <= stepIndex ? Color.brandPrimary : Color.borderLogin)
                    .frame(height: 4)
            }
        }
        .screenPadding(.horizontal)
        .padding(.vertical, layout.spacingMedium)
    }

    // MARK: - Step Titles

    private var stepTitle: String {
        switch currentStep {
        case .basicData: return "Datos básicos"
        case .accountInfo: return "Información de cuenta"
        case .identity: return "Identidad"
        }
    }

    private var stepSubtitle: String {
        switch currentStep {
        case .basicData: return "Ingresa tu nombre, teléfono y género"
        case .accountInfo: return "Configura tu correo, usuario y contraseña"
        case .identity: return "Fecha de nacimiento y documento de identidad"
        }
    }

    // MARK: - Step 1: Basic Data

    private var basicDataFields: some View {
        Group {
            FatumTextField(
                placeholder: "Nombre completo",
                text: $name,
                prefixIcon: "person",
                textContentType: .name,
                submitLabel: .next,
                maxLength: 142
            )

            FatumTextField(
                placeholder: "Teléfono",
                text: $phone,
                prefixIcon: "phone",
                keyboardType: .numberPad,
                textContentType: .telephoneNumber,
                maxLength: 20,
                allowedCharacters: { _, newValue in
                    newValue.filter { $0.isNumber }
                }
            )

            FatumPicker(
                title: "Género",
                options: Array(Gender.allCases),
                selection: $selectedGender,
                style: .login,
                icon: "person.2"
            ) { $0.displayName }
        }
    }

    // MARK: - Step 2: Account Info

    private var accountInfoFields: some View {
        Group {
            FatumTextField(
                placeholder: "Correo electrónico",
                text: $email,
                prefixIcon: "envelope",
                keyboardType: .emailAddress,
                textContentType: .emailAddress,
                submitLabel: .next,
                allowedCharacters: { oldValue, newValue in
                    let noSpaces = newValue.filter { $0 != " " }
                    let atCount = noSpaces.filter { $0 == "@" }.count
                    if atCount > 1 {
                        return oldValue
                    }
                    return noSpaces
                }
            )

            FatumTextField(
                placeholder: "Nombre de usuario",
                text: $username,
                prefixIcon: "at",
                submitLabel: .next,
                maxLength: 15,
                allowedCharacters: { _, newValue in
                    newValue.filter { $0 != " " }.lowercased()
                }
            )

            FatumTextField(
                placeholder: "Contraseña",
                text: $password,
                prefixIcon: "lock",
                isSecure: true,
                textContentType: .newPassword,
                submitLabel: .next,
                allowedCharacters: { _, newValue in
                    newValue.filter { $0 != " " }
                }
            )

            FatumTextField(
                placeholder: "Confirmar contraseña",
                text: $confirmPassword,
                prefixIcon: "lock",
                isSecure: true,
                textContentType: .newPassword,
                submitLabel: .done,
                allowedCharacters: { _, newValue in
                    newValue.filter { $0 != " " }
                }
            )
        }
    }

    // MARK: - Step 3: Identity

    private var identityFields: some View {
        Group {
            // Birthday DatePicker
            VStack(alignment: .leading, spacing: layout.spacingSmall) {
                DatePicker(
                    "Fecha de nacimiento",
                    selection: $birthday,
                    in: ...Date(),
                    displayedComponents: .date
                )
                .fatumStyle(.body)
                .foregroundStyle(.brandPrimary)
                // Same box as FatumPicker so the identity step lines up.
                .padding(.horizontal, layout.internalPadding)
                .padding(.vertical, layout.smallPadding)
                .background(Color.thirdGradient.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            birthdayError != nil ? Color.errorBorderLogin : Color.borderLogin,
                            lineWidth: birthdayError != nil ? 2 : 1
                        )
                )
                .onChange(of: birthday) {
                    if !isAtLeast18 {
                        birthdayError = "Debes tener al menos 18 años para registrarte"
                    } else {
                        birthdayError = nil
                    }
                }

                if let birthdayError {
                    Text(birthdayError)
                        .fatumStyle(.footer)
                        .foregroundStyle(.errorBorderLogin)
                }
            }

            FatumTextField(
                placeholder: "Número de documento",
                text: $document,
                prefixIcon: "doc.text",
                keyboardType: .numberPad,
                maxLength: 10,
                allowedCharacters: { _, newValue in
                    newValue.filter { $0.isNumber }
                }
            )

            FatumPicker(
                title: "Tipo de documento",
                options: Array(DocumentType.allCases),
                selection: $selectedDocumentType,
                style: .login,
                icon: "doc.badge.ellipsis"
            ) { $0.displayName }
        }
    }
}

#Preview {
    ContentView()
        .environment(UserProvider())
}
