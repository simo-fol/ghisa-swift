import SwiftUI

/// Login to the online database, and who you are once signed in.
struct AccountView: View {
    let app: AppModel
    @Bindable var cloud: Cloud

    @State private var email = ""
    @State private var password = ""
    @FocusState private var focus: Field?

    private enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    RoundButton(label: "‹", fontSize: 26, background: .clear, action: app.showHome)
                    Text("Account").font(.system(size: 22, weight: .bold))
                }

                if !cloud.isConfigured {
                    Text("L'app non è collegata al database: manca il file Config/Secrets.xcconfig con progetto e chiave di Supabase.")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                } else if cloud.isSignedIn {
                    signedIn
                } else {
                    signInForm
                }

                if let error = cloud.error {
                    Text(error)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.warm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(padding: 14)
                }
            }
            .padding(EdgeInsets(top: 10, leading: 18, bottom: 32, trailing: 18))
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .animation(.easeOut(duration: 0.2), value: cloud.isSignedIn)
    }

    // MARK: Signed out

    private var signInForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accedi con l'account che ti ha creato la palestra: le tue schede e i tuoi allenamenti saranno salvati online.")
                .font(.system(size: 15))
                .foregroundStyle(Theme.muted)

            field {
                TextField("Email", text: $email)
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focus, equals: .email)
                    .submitLabel(.next)
                    .onSubmit { focus = .password }
            }
            field {
                SecureField("Password", text: $password)
                    .textContentType(.password)
                    .focused($focus, equals: .password)
                    .submitLabel(.go)
                    .onSubmit(signIn)
            }

            Button(action: signIn) {
                if cloud.isBusy { ProgressView().tint(Theme.onAccent) } else { Text("Accedi") }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(email.isEmpty || password.isEmpty || cloud.isBusy)
            .opacity(email.isEmpty || password.isEmpty ? 0.5 : 1)
            .padding(.top, 4)
        }
    }

    private func field(@ViewBuilder _ content: () -> some View) -> some View {
        content()
            .font(.system(size: 17))
            .padding(.horizontal, 16)
            .frame(height: 52)
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func signIn() {
        guard !email.isEmpty, !password.isEmpty else { return }
        focus = nil
        Task {
            await cloud.signIn(email: email, password: password)
            if cloud.isSignedIn { password = "" }
        }
    }

    // MARK: Signed in

    private var signedIn: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 14) {
                Image(systemName: "person.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.onAccent)
                    .frame(width: 56, height: 56)
                    .background(Theme.accent, in: Circle())
                VStack(alignment: .leading, spacing: 3) {
                    SectionLabel("COLLEGATO", color: Theme.accent)
                    Text(displayName).font(.system(size: 20, weight: .bold)).lineLimit(1)
                    if let email = cloud.email, email != displayName {
                        Text(email).font(.system(size: 13)).foregroundStyle(Theme.muted).lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .card()

            if cloud.user?.superAdmin == true {
                Label("Super admin: vedi e gestisci tutte le palestre", systemImage: "star.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.warm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 14)
            }

            SectionLabel("LE TUE PALESTRE").padding(.leading, 2).padding(.top, 4)
            if cloud.memberships.isEmpty {
                Text(cloud.isBusy ? "Caricamento…" : "Non fai ancora parte di nessuna palestra.")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card(padding: 14)
            } else {
                VStack(spacing: 8) {
                    ForEach(cloud.memberships) { m in
                        HStack {
                            Text(m.gym).font(.system(size: 16, weight: .semibold))
                            Spacer()
                            Text(m.active ? m.roleName : m.roleName + " (sospeso)")
                                .font(.system(size: 13, weight: .semibold))
                                .chip()
                        }
                        .card(padding: 14)
                    }
                }
            }

            HStack(spacing: 10) {
                Button("Aggiorna") { Task { await cloud.refresh() } }
                    .buttonStyle(PillButtonStyle())
                Spacer()
                Button("Esci") { Task { await cloud.signOut() } }
                    .buttonStyle(PillButtonStyle(foreground: Color(hex: 0xFF5A5F)))
            }
            .padding(.top, 4)
        }
    }

    private var displayName: String {
        let name = cloud.user?.nome.trimmingCharacters(in: .whitespaces) ?? ""
        return name.isEmpty ? (cloud.email ?? "") : name
    }
}

#Preview {
    let app = PreviewData.app()
    return AccountView(app: app, cloud: app.cloud)
        .background(Theme.bg)
        .preferredColorScheme(.dark)
}
