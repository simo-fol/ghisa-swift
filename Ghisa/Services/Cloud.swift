import Foundation
import Observation
import Supabase

/// Where the online database lives. The values are not in the code: they come from
/// Config/Secrets.xcconfig (not in git) through Info.plist, so they never end up on GitHub.
/// Only the publishable key goes there: the database rules (RLS) decide what each user may
/// read or write. Never use the secret key in the app.
enum SupabaseConfig {
    private static func value(_ name: String) -> String {
        (Bundle.main.object(forInfoDictionaryKey: name) as? String ?? "").trimmingCharacters(in: .whitespaces)
    }

    /// The id before .supabase.co, e.g. "abcdefghijkl".
    static let project = value("SupabaseProject")
    static let key = value("SupabaseKey")
    static var url: URL? { project.isEmpty ? nil : URL(string: "https://\(project).supabase.co") }

    /// False with the placeholders of Secrets.example.xcconfig, and refuses a secret key by mistake.
    static var isSet: Bool {
        url != nil && project != "your-project-id" && !key.isEmpty
            && !key.hasPrefix("sb_secret_") && key != "sb_publishable_your-key"
    }
}

/// The signed-in account and the online database: login, logout and who you are in each gym.
/// The session is kept in the Keychain by the Supabase library, so you stay signed in.
@Observable
final class Cloud {
    private(set) var email: String?
    private(set) var user: CloudUser?
    private(set) var memberships: [Membership] = []
    private(set) var isBusy = false
    var error: String?

    @ObservationIgnored let client: SupabaseClient?

    var isConfigured: Bool { client != nil }
    var isSignedIn: Bool { email != nil }

    /// `preview: true` never connects (Xcode Canvas).
    init(preview: Bool = false) {
        guard !preview, SupabaseConfig.isSet, let url = SupabaseConfig.url else {
            client = nil
            return
        }
        client = SupabaseClient(supabaseURL: url, supabaseKey: SupabaseConfig.key)
        Task { await watchSession() }
    }

    /// Follows login, logout and the session saved from last time.
    @MainActor private func watchSession() async {
        guard let client else { return }
        for await (event, session) in client.auth.authStateChanges {
            email = session?.user.email
            if session == nil {
                user = nil
                memberships = []
            } else if event == .initialSession {
                await refresh()
            }
        }
    }

    @MainActor func signIn(email: String, password: String) async {
        guard let client else { return }
        isBusy = true
        error = nil
        do {
            try await client.auth.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
            isBusy = false
            await refresh()
        } catch {
            isBusy = false
            self.error = Self.message(error)
        }
    }

    @MainActor func signOut() async {
        try? await client?.auth.signOut()
        email = nil
        user = nil
        memberships = []
        error = nil
    }

    /// Reads your row of "utenti" and your roles from "membri", with the gym names.
    /// The database rules only return rows you are allowed to see.
    @MainActor func refresh() async {
        guard let client, let id = client.auth.currentUser?.id.uuidString else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            let row: CloudUser = try await client.from("utenti").select("id, nome, email, super_admin")
                .eq("id", value: id).single().execute().value
            let roles: [Membership] = try await client.from("membri").select("ruolo, attivo, palestre(nome)")
                .eq("utente_id", value: id).execute().value
            user = row
            memberships = roles
            error = nil
        } catch {
            self.error = Self.message(error)
        }
    }

    /// Supabase errors in plain Italian.
    private static func message(_ error: Error) -> String {
        if let url = error as? URLError {
            return [.cannotFindHost, .badURL, .unsupportedURL].contains(url.code)
                ? "Database non trovato: controlla SUPABASE_PROJECT in Config/Secrets.xcconfig."
                : "Nessuna connessione a internet."
        }
        let text = error.localizedDescription
        if text.localizedCaseInsensitiveContains("invalid login credentials") { return "Email o password sbagliate." }
        if text.localizedCaseInsensitiveContains("email not confirmed") { return "Email non ancora confermata." }
        return text
    }
}

/// A row of the "utenti" table.
struct CloudUser: Decodable, Sendable {
    let id: UUID
    let nome: String
    let email: String?
    let superAdmin: Bool

    enum CodingKeys: String, CodingKey {
        case id, nome, email
        case superAdmin = "super_admin"
    }
}

/// A row of the "membri" table with the name of its gym: "Palestra Ferro · Atleta".
struct Membership: Decodable, Identifiable, Sendable {
    let role: String
    let active: Bool
    let gym: String

    var id: String { gym + role }

    var roleName: String {
        switch role {
        case "admin": "Amministratore"
        case "coach": "Coach"
        default: "Atleta"
        }
    }

    private enum CodingKeys: String, CodingKey { case ruolo, attivo, palestre }
    private struct Gym: Decodable, Sendable { let nome: String }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        role = try c.decode(String.self, forKey: .ruolo)
        active = try c.decode(Bool.self, forKey: .attivo)
        gym = try c.decodeIfPresent(Gym.self, forKey: .palestre)?.nome ?? "Palestra"
    }
}
