import Foundation

struct AppState: Codable {
    /// File name of the working copy in the Documents folder.
    var workbookFile: String?

    /// Bookmark of the file originally picked, to write results back to it.
    var sourceBookmark: Data?

    var selectedSheet: String?

    /// Personal notes per exercise name.
    var notes: [String: String] = [:]

    /// Rest seconds chosen per exercise name.
    var rest: [String: Int] = [:]

    var draft: WorkoutDraft?
}

/// A workout in progress, kept so nothing is lost if iOS closes the app.
struct WorkoutDraft: Codable {
    var sheet = ""
    var split = ""
    var micro = 0
    var week = 0
    var startedAt = Date()
    var exercises: [DraftExercise] = []
}

struct DraftExercise: Codable {
    var row = 0
    var sets: [WorkoutSet] = []
}

enum StateStore {
    static var fileURL: URL { Platform.stateDirectory.appendingPathComponent("state.json") }

    static func load() -> AppState {
        // A corrupt state file must not stop the app from starting.
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? JSONDecoder().decode(AppState.self, from: data) else { return AppState() }
        return state
    }

    static func save(_ state: AppState) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
