import Foundation
import Observation

enum Page {
    case home
    case workout(WorkoutModel)
    case done(DoneSummary)
    case timer
}

/// Owns the loaded log book and app state, and switches between pages.
@Observable
final class AppModel {
    var state: AppState
    private(set) var book: LogBook?
    var page: Page = .home
    var toast: String?
    var isImporting = false

    @ObservationIgnored private var toastTask: Task<Void, Never>?
    @ObservationIgnored private var persists = true

    #if DEBUG
    /// In-memory app for Xcode previews: nothing is read from or written to disk.
    init(previewBook: LogBook?) {
        persists = false
        state = AppState(workbookFile: previewBook == nil ? nil : "Scheda.xlsx")
        book = previewBook
    }
    #endif

    init() {
        state = StateStore.load()
        tryOpenWorkingCopy()
        if book != nil, let draft = state.draft, let pi = findProtocol(draft.sheet) {
            page = .workout(WorkoutModel(app: self, protocolIndex: pi, split: draft.split,
                                         slot: Slot(micro: draft.micro, week: draft.week), draft: draft))
        }
    }

    var workbookURL: URL? {
        state.workbookFile.map { Platform.documentsDirectory.appendingPathComponent($0) }
    }

    /// The working copy, when it exists: what the share buttons send.
    var shareURL: URL? {
        guard let url = workbookURL, FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
    }

    private func tryOpenWorkingCopy() {
        guard let url = workbookURL, let data = try? Data(contentsOf: url) else { return }
        book = try? LogBook.load(data)
    }

    func findProtocol(_ sheet: String) -> Int? {
        book?.protocols.firstIndex { $0.sheetName == sheet }
    }

    func persistState() {
        if persists { StateStore.save(state) }
    }

    func showHome() { page = .home }

    // MARK: Home

    /// Index of the sheet shown on the home page: the last one chosen, or the newest.
    var selectedProtocol: Int {
        get { state.selectedSheet.flatMap(findProtocol) ?? max((book?.protocols.count ?? 0) - 1, 0) }
        set {
            state.selectedSheet = book?.protocols[newValue].sheetName
            persistState()
        }
    }

    /// "Split A · Microciclo 1 · Settimana III" for the workout left half done.
    var draftLabel: String? {
        guard let d = state.draft, let pi = findProtocol(d.sheet), let book else { return nil }
        return "Split \(d.split) · \(SessionPlanner.label(book.protocols[pi], Slot(micro: d.micro, week: d.week)))"
    }

    func discardDraft() {
        state.draft = nil
        persistState()
    }

    func startWorkout(protocolIndex: Int, split: String, slot: Slot) {
        state.draft = nil
        page = .workout(WorkoutModel(app: self, protocolIndex: protocolIndex, split: split, slot: slot, draft: nil))
    }

    func resumeDraft() {
        guard let d = state.draft, let pi = findProtocol(d.sheet) else { return }
        page = .workout(WorkoutModel(app: self, protocolIndex: pi, split: d.split,
                                     slot: Slot(micro: d.micro, week: d.week), draft: d))
    }

    /// Called with the file chosen in the Files picker.
    func importFile(_ url: URL) {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        guard let bytes = Self.coordinatedRead(url) else {
            showToast("Impossibile leggere il file")
            return
        }
        let loaded: LogBook
        do {
            loaded = try LogBook.load(bytes)
        } catch {
            showToast("Questo file non sembra una scheda valida")
            return
        }
        guard let last = loaded.protocols.last else {
            showToast("Nessun microciclo trovato nel file")
            return
        }

        state.workbookFile = url.lastPathComponent
        try? bytes.write(to: workbookURL!, options: .atomic)
        state.sourceBookmark = try? url.bookmarkData()
        state.selectedSheet = last.sheetName
        state.draft = nil
        persistState()
        book = loaded
        showHome()
        showToast("Scheda caricata: \(loaded.protocols.count) fogli")
    }

    /// Saves the log book to the working copy and, when possible, back to the file that was picked.
    /// Returns true if the original file was updated too.
    func saveWorkbook() -> Bool {
        guard let book, let target = workbookURL else { return false }
        let bytes = book.save()
        try? bytes.write(to: target, options: .atomic)

        guard let bookmark = state.sourceBookmark else { return false }
        var stale = false
        guard let original = try? URL(resolvingBookmarkData: bookmark, bookmarkDataIsStale: &stale) else { return false }
        let scoped = original.startAccessingSecurityScopedResource()
        defer { if scoped { original.stopAccessingSecurityScopedResource() } }

        var ok = false
        var error: NSError?
        NSFileCoordinator().coordinate(writingItemAt: original, options: .forReplacing, error: &error) { url in
            ok = (try? bytes.write(to: url)) != nil
        }
        if stale, ok { state.sourceBookmark = try? original.bookmarkData() }
        return ok && error == nil
    }

    private static func coordinatedRead(_ url: URL) -> Data? {
        var data: Data?
        var error: NSError?
        // Coordination makes iOS download the file first when it lives in iCloud Drive.
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &error) { data = try? Data(contentsOf: $0) }
        return data
    }

    func showToast(_ message: String) {
        toast = message
        toastTask?.cancel()
        toastTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2.5))
            if !Task.isCancelled { self?.toast = nil }
        }
    }
}

struct DoneSummary {
    let title: String
    let slotLabel: String
    let recorded: Int
    let total: Int
    let minutes: Int
    let savedToOriginal: Bool

    var summary: String { "\(recorded) di \(total) esercizi registrati · \(minutes) min" }

    var saveInfo: String {
        savedToOriginal
            ? "Risultati scritti nel tuo file Excel."
            : "Risultati scritti nella copia dell'app (File › Sul mio iPhone › Ghisa). Usa Condividi per mandarla dove vuoi."
    }
}
