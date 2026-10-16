# Fatum – User Flow & View Composition

Generated from the code on 2026-10-15. Mermaid diagrams: open in Xcode Markdown preview, GitHub, or VS Code (Markdown Preview Mermaid).

Legend used across diagrams:

| Shape / style | Meaning |
|---|---|
| `[[Name]]` | File in `Views/Screens` |
| `[Name]` | File in `Views/CustomViews` |
| `(Name)` | Declared outside those folders (`FatumApp.swift`, `ContentView.swift`) |
| `{{Name}}` | `@Observable` provider in `ViewModels` |
| `-->` | push / state switch |
| `-.->` | `fullScreenCover`, `sheet`, overlay or system picker |

---

## 1. App root: session state decides the tree

`FatumApp` is the only place that decides which tree is on screen, based on `UserProvider`.

```mermaid
flowchart TD
    App(FatumApp) -->|"@State userProvider, .task loadCurrentUser()"| Check{isCheckingSession?}
    Check -- yes --> Splash[[SplashScreen]]
    Check -- no --> LoggedIn{isLoggedIn?}
    LoggedIn -- no --> Content(ContentView<br/>welcome carousel)
    LoggedIn -- yes --> Tabs[MainTabView]

    %% Overlays rendered by FatumApp on top of MainTabView
    Tabs -.->|"username empty or == email"| UsernameDialog[RequiredActionDialog<br/>'define un nombre de usuario'<br/>+ FatumTextField + Button]
    UsernameDialog -->|"userProvider.updateUser(.init(username:))"| Tabs
    Tabs -.->|"!isAuthenticated && !needsUsername"| AuthDialog[RequiredActionDialog<br/>'No estas autentificado' + Button]
    AuthDialog -.->|"fullScreenCover showVerificationFlow"| Verify[[VerificationFlowView]]
    Verify -->|"authenticateUser() ok → loadCurrentUser() → dismiss"| Tabs
    Verify -->|"authenticateUser() fails → signOut() → dismiss"| Content
```

---

## 2. Unauthenticated flow (`ContentView` NavigationStack + `AppRoute`)

`ContentView` owns a `NavigationPath` and resolves `AppRoute` (`.login`, `.register`, `.confirmEmail(email)`). `LoginView` and `RegisterView` are declared in `ContentView.swift`, not in `Views/Screens`.

```mermaid
flowchart TD
    Content(ContentView) -->|"'Regístrarse' → path.append(.register)"| Register(RegisterView)
    Content -->|"'Iniciar Sesión' → path.append(.login)"| Login(LoginView)

    subgraph Login_screen["LoginView"]
        Login -->|"'Crear cuenta nueva'"| Register
        Login -.->|"NavigationLink '¿Olvidaste tu contraseña?'"| Reset[BuildingView<br/>'Password Reset']
    end

    Login -->|"userProvider.signIn() ok → currentUser set"| Tabs[MainTabView<br/>root swaps automatically]

    subgraph Register_steps["RegisterView – internal step enum"]
        direction LR
        S1[basicData<br/>name, phone, gender] --> S2[accountInfo<br/>email, username, password x2] --> S3[identity<br/>birthday, document, docType]
    end
    Register --> S1
    S3 -->|"Amplify.Auth.signUp() → .confirmUser"| Confirm[[ConfirmationView]]
    Register -->|"'Ya tengo una cuenta' → reset path + .login"| Login

    Confirm -->|"Amplify.Auth.confirmSignUp() ok"| Success[RequiredActionDialog<br/>'Usuario creado con exito']
    Success -->|"Amplify.Auth.signOut() → path = []"| Content
    Confirm -->|"'Reenviar código' → Amplify.Auth.resendSignUpCode()"| Confirm
```

Note: after confirming the email the user is sent back to the welcome screen and must log in manually.

---

## 3. Authenticated flow (`MainTabView` and the Profile stack)

```mermaid
flowchart TD
    Tabs[MainTabView] --> Home[[HomeView]]
    Tabs -->|"role == .professional"| Serv[BuildingView 'Mis servicios']
    Tabs -->|"role != .professional"| Fav[BuildingView 'Favoritos']
    Tabs --> Neg[BuildingView 'Negociación']
    Tabs --> Profile[[ProfileScreen]]

    subgraph ProfileStack["ProfileScreen NavigationStack (ProfileDestination + UserFieldType)"]
        Profile -->|".manageProfile"| Manage[[ManageProfileScreen]]
        Profile -->|".addresses"| Addresses[[AddressesScreen]]
        Manage -->|"NavigationLink(value: UserFieldType)<br/>username or phoneNumber"| UpdateUser[[UpdateUserScreen]]
        UpdateUser -->|"updateUser() ok → dismiss"| Manage
        Addresses -.->|"fullScreenCover showAddAddress<br/>.environment(addressProvider)"| AddAddress[[AddAddressScreen]]
        AddAddress -->|"onSaved(message) → dismiss"| Addresses
        Addresses -.->|"confirmationDialog delete"| Addresses
    end

    Manage -.->|"ProfileImagePicker"| Camera[CameraView<br/>fullScreenCover]
    Manage -.->|"ProfileImagePicker"| Photos[(PhotosPicker)]
    Profile -->|"'Cerrar Sesión' → userProvider.signOut()"| Content(ContentView<br/>root swaps automatically)
    Profile -.->|"other options"| Toast[ToastMessageView<br/>'Función en construcción']
```

### Verification flow (presented by `FatumApp`, not by a tab)

```mermaid
flowchart LR
    V[[VerificationFlowView]] --> P1[profileImage<br/>ProfileImagePicker]
    P1 -->|"uploadProfileImage() or already has one"| P2[document]
    P2 -.->|"fullScreenCover"| Scanner[DocumentScannerView<br/>VisionKit]
    P2 -.->|"fileImporter .pdf"| Files[(Files)]
    P2 -->|"uploadDocumentPdf()"| P3[authenticate]
    P3 -->|"authenticateUser()"| Done((dismiss))
```

---

## 4. Screen → component composition

Which custom views each screen renders. `FatumTextField` is declared in `LoginTextField.swift`; `CameraView` in `UserProfileHeader.swift`.

```mermaid
flowchart LR
    subgraph Screens
        Content(ContentView)
        Login(LoginView)
        Register(RegisterView)
        Confirm[[ConfirmationView]]
        Splash[[SplashScreen]]
        Home[[HomeView]]
        Profile[[ProfileScreen]]
        Manage[[ManageProfileScreen]]
        UpdateUser[[UpdateUserScreen]]
        Addresses[[AddressesScreen]]
        AddAddress[[AddAddressScreen]]
        Verify[[VerificationFlowView]]
        UpdateDoc[[UpdateDocumentScreen<br/>⚠ not referenced]]
        AppRoot(FatumApp)
    end

    subgraph Components["CustomViews"]
        LoginTab[LoginTab]
        TextField[FatumTextField]
        Dialog[RequiredActionDialog]
        Building[BuildingView]
        Toast[ToastMessageView]
        Header[UserProfileHeader]
        Option[ProfileOptionView]
        ImgPicker[ProfileImagePicker]
        Camera[CameraView]
        Row[UpdateUserField]
        Card[AddressCardView]
        Labeled[LabeledTextField]
        Toggle[LabeledToggle]
        Scanner[DocumentScannerView]
        Notice[ProfileNoticeView<br/>⚠ not referenced]
        MainTab[MainTabView<br/>⚠ acts as a screen]
    end

    Content --> LoginTab
    Login --> TextField
    Login --> Building
    Register --> TextField
    Confirm --> TextField
    Confirm --> Dialog
    AppRoot --> Dialog
    AppRoot --> TextField
    AppRoot --> MainTab
    MainTab --> Building
    Profile --> Header
    Profile --> Option
    Profile --> Toast
    Manage --> ImgPicker
    Manage --> Row
    Manage --> Toast
    ImgPicker --> Camera
    UpdateUser --> TextField
    Addresses --> TextField
    Addresses --> Card
    Addresses --> Toast
    AddAddress --> Labeled
    AddAddress --> Toggle
    AddAddress --> Toast
    Labeled --> TextField
    Verify --> ImgPicker
    Verify --> Scanner
    Verify --> Toast
    UpdateDoc --> TextField
    UpdateDoc --> Scanner
    UpdateDoc --> Toast
```

Same information as a table:

| Screen | Where declared | Components used | Navigation it owns |
|---|---|---|---|
| FatumApp | `FatumApp.swift` | RequiredActionDialog, FatumTextField, MainTabView | Root switch, `fullScreenCover` → VerificationFlowView |
| SplashScreen | Screens | none | – |
| ContentView | `ContentView.swift` | LoginTab ×3 | `NavigationStack(path)` + `AppRoute` |
| LoginView | `ContentView.swift` | FatumTextField ×2, BuildingView | `NavigationLink` (closure) |
| RegisterView | `ContentView.swift` | FatumTextField ×7, inline Picker/DatePicker | internal `RegisterStep` enum |
| ConfirmationView | Screens | FatumTextField, RequiredActionDialog | pops via `navigationPath` |
| MainTabView | CustomViews | HomeView, BuildingView ×2, ProfileScreen | `TabView` |
| HomeView | Screens | none (inline empty state) | own `NavigationStack` |
| ProfileScreen | Screens | UserProfileHeader, ProfileOptionView ×6–7, ToastMessageView | `NavigationStack(path)` + `ProfileDestination` + `UserFieldType` |
| ManageProfileScreen | Screens | ProfileImagePicker, UpdateUserField ×6, ToastMessageView | `NavigationLink(value:)` |
| UpdateUserScreen | Screens | FatumTextField | `dismiss` |
| AddressesScreen | Screens | FatumTextField, AddressCardView, ToastMessageView | `fullScreenCover` → AddAddressScreen, `confirmationDialog` |
| AddAddressScreen | Screens | LabeledTextField ×5, LabeledToggle, ToastMessageView | own `NavigationStack`, `dismiss` |
| VerificationFlowView | Screens | ProfileImagePicker, DocumentScannerView, ToastMessageView | internal `VerificationStep` enum, `fullScreenCover`, `fileImporter` |
| UpdateDocumentScreen | Screens | FatumTextField, DocumentScannerView, ToastMessageView | internal `DocumentStep` enum. **Unused.** |

---

## 5. Data flow: who talks to the backend

```mermaid
flowchart LR
    subgraph Views
        Login(LoginView)
        Register(RegisterView)
        Confirm[[ConfirmationView]]
        AppRoot(FatumApp)
        Profile[[ProfileScreen]]
        Manage[[ManageProfileScreen]]
        UpdateUser[[UpdateUserScreen]]
        Header[UserProfileHeader]
        Verify[[VerificationFlowView]]
        Addresses[[AddressesScreen]]
        AddAddress[[AddAddressScreen]]
    end

    UP{{UserProvider<br/>injected at root}}
    AP{{AddressProvider<br/>created by AddressesScreen}}
    Cognito[(Amplify.Auth / Cognito)]
    API[(REST API<br/>/users, /profile-image, /documents)]

    Login --> UP
    AppRoot --> UP
    Profile --> UP
    Manage --> UP
    UpdateUser --> UP
    Header --> UP
    Verify --> UP
    Addresses --> UP
    Addresses --> AP
    AddAddress --> AP

    Register ==>|"signUp() directly"| Cognito
    Confirm ==>|"confirmSignUp(), resendSignUpCode(), signOut() directly"| Cognito

    UP --> Cognito
    UP --> API
    AP --> Cognito
    AP --> API
```

Thick arrows are the places where a view bypasses the provider layer.

---

## 6. Observations for the design-pattern review

The intended pattern reads as **MVVM with `@Observable` providers injected through the environment** (`UserProvider`, `AddressProvider`). Points where the code departs from it or from its own conventions:

1. **Providers bypassed in sign-up.** `RegisterView` and `ConfirmationView` call `Amplify.Auth` directly, while `LoginView` goes through `UserProvider.signIn`. Sign-up, confirm, and resend have no provider method.
2. **Business logic in the `App` struct.** `FatumApp` holds form state and `submitUsername()` for the username dialog, plus the "needs authentication" rule. Both are view-model concerns.
3. **Screen placement and naming are mixed.** `LoginView` and `RegisterView` live in `ContentView.swift`; `MainTabView` is a screen container but sits in `CustomViews`; `Screens` mixes `*View` and `*Screen` suffixes; `ContentView` is really a welcome screen.
4. **File/type mismatches.** `FatumTextField` is in `LoginTextField.swift`; `CameraView` is in `UserProfileHeader.swift`; `UserFieldType` is in `ManageProfileScreen.swift`; `AppRoute` is in `ContentView.swift`.
5. **Dead code.** `UpdateDocumentScreen` and `ProfileNoticeView` are not referenced by any other file.
6. **Four navigation styles coexist.** Typed `NavigationPath` + route enum (ContentView, ProfileScreen), `NavigationLink(value:)` (ManageProfileScreen), `NavigationLink { destination }` (LoginView → BuildingView), and in-screen step enums (Register, Verification, UpdateDocument). `ManageProfileScreen` depends on `ProfileScreen` having registered the `UserFieldType` destination.
7. **Duplicated UI logic.** The toast overlay with a 3-second timer is copied in six screens. The capsule step indicator is copied in three. The icon/title/message empty-state block is copied in `HomeView` and `AddressesScreen`. Every view recomputes `ResponsiveLayout` from the size class.
8. **No network layer.** Both providers build `URLRequest`s by hand and duplicate `fetchIdToken`, `authorizedRequest`-style setup, `parseErrorMessage`, and the base URL. `UserProvider.loadCurrentUser` force-casts the response.
9. **Multiple sources of truth for the avatar.** `UserProfileHeader`, `ManageProfileScreen`, and `VerificationFlowView` each fetch the profile-image URL independently instead of reading it from the provider.
10. **Three `NavigationStack`s inside `MainTabView` tabs plus one in `VerificationFlowView` and one in `AddAddressScreen`.** That is normal for tabs, but the covers only need a stack for the toolbar.
