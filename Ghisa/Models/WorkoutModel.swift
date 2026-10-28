import Foundation
import Observation

/// Today's workout. The views edit `exercises` directly through bindings;
/// every change is saved as a draft, so nothing is lost if iOS closes the app.
@Observable
final class WorkoutModel {
    let app: AppModel
    let proto: TrainingProtocol
    let split: String
    let slot: Slot
    let startedAt: Date
    let timer = RestTimer()

    var exercises: [Exercise] {
        didSet { save() }
    }

    init(app: AppModel, protocolIndex: Int, split: String, slot: Slot, draft: WorkoutDraft?) {
        let book = app.book!
        self.app = app
        proto = book.protocols[protocolIndex]
        self.split = split
        self.slot = slot
        startedAt = draft?.startedAt ?? Date()

        let rows = SessionPlanner.block(proto, split, slot)!.exercises
        exercises = rows.map { row in
            Exercise(row: row, week: slot.week,
                     last: SessionPlanner.lastResult(book.protocols, protocolIndex, split, before: slot, row),
                     savedSets: draft?.exercises.first { $0.row == row.row }?.sets,
                     state: app.state)
        }
        if let first = exercises.firstIndex(where: { !$0.isComplete }) { exercises[first].isExpanded = true }

        Platform.keepScreenOn(true)
        Platform.requestNotificationPermission()
        save()
    }

    var title: String { "Split \(split)" }
    var slotLabel: String { SessionPlanner.label(proto, slot) }

    var completedCount: Int { exercises.filter(\.isComplete).count }
    var progressText: String { "\(completedCount)/\(exercises.count)" }
    var progress: Double { exercises.isEmpty ? 0 : Double(completedCount) / Double(exercises.count) }

    // MARK: Actions

    /// Opens one exercise card and closes the others.
    func toggle(_ exercise: Exercise) {
        let open = !exercise.isExpanded
        for i in exercises.indices { exercises[i].isExpanded = exercises[i].id == exercise.id && open }
    }

    /// The ✓ of a set: ticks it, starts the rest timer and moves on when the exercise is complete.
    func toggleDone(_ set: WorkoutSet, in exercise: Exercise) {
        guard let e = exercises.firstIndex(where: { $0.id == exercise.id }),
              let s = exercises[e].sets.firstIndex(where: { $0.id == set.id }) else { return }
        exercises[e].sets[s].done.toggle()
        guard exercises[e].sets[s].done else { return }

        Platform.haptic()
        if exercises[e].isComplete {
            exercises[e].isExpanded = false
            let next = exercises.indices.dropFirst(e + 1).first { !exercises[$0].isComplete }
                ?? exercises.indices.first { !exercises[$0].isComplete }
            if let next { exercises[next].isExpanded = true }
        }
        timer.start(seconds: exercises[e].restSeconds, exercise: exercises[e].name)
    }

    func back() {
        save()
        timer.stop()
        Platform.keepScreenOn(false)
        app.showHome()
    }

    func finish() {
        guard let book = app.book else { return }
        var recorded = 0
        for e in exercises {
            let done = e.sets.filter(\.done)
            if done.isEmpty { continue }
            book.record(proto, e.row, week: slot.week,
                        load: SetValues.join(done.map(\.kg)),
                        reps: SetValues.join(done.map(\.reps)))
            recorded += 1
        }
        if recorded == 0 {
            app.showToast("Segna almeno una serie come fatta")
            return
        }

        let original = app.saveWorkbook()
        timer.stop()
        Platform.keepScreenOn(false)
        app.state.draft = nil
        app.persistState()
        let minutes = Int((Date().timeIntervalSince(startedAt) / 60).rounded())
        app.page = .done(DoneSummary(title: "\(title) completato", slotLabel: slotLabel, recorded: recorded,
                                     total: exercises.count, minutes: minutes, savedToOriginal: original))
    }

    // MARK: Saving

    /// Keeps the draft, your notes and your rest times in the app state.
    private func save() {
        for e in exercises {
            let note = e.note.trimmingCharacters(in: .whitespacesAndNewlines)
            app.state.notes[e.key] = note.isEmpty ? nil : e.note
            app.state.rest[e.key] = e.restSeconds == e.coachRest ? nil : e.restSeconds
        }
        app.state.draft = WorkoutDraft(
            sheet: proto.sheetName, split: split, micro: slot.micro, week: slot.week, startedAt: startedAt,
            exercises: exercises.map { DraftExercise(row: $0.row.row, sets: $0.sets) })
        app.persistState()
    }
}
