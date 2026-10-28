import Foundation

/// One set of an exercise: what you lifted and whether it is done.
struct WorkoutSet: Identifiable, Codable {
    var id = UUID()
    var kg = ""
    var reps = ""
    var done = false

    // The id only lives in memory: the saved draft keeps the three values.
    enum CodingKeys: String, CodingKey { case kg, reps, done }

    mutating func kgUp() { kg = SetValues.bump(kg, 2.5) }
    mutating func kgDown() { kg = SetValues.bump(kg, -2.5) }
    mutating func repsUp() { reps = SetValues.bump(reps, 1) }
    mutating func repsDown() { reps = SetValues.bump(reps, -1) }
}

/// An exercise of today's workout, as shown in its card.
struct Exercise: Identifiable {
    static let restChoices = [45, 60, 90, 120, 150, 180, 240]

    let row: ExerciseRow
    let last: PastResult?
    var sets: [WorkoutSet]
    var isExpanded = false
    var restSeconds: Int
    var note: String

    var id: Int { row.row }

    /// Key used to remember notes and rest time per exercise name.
    var key: String { Self.key(row) }

    /// Rest written by the coach ("REST 60\""), or 1'30".
    var coachRest: Int { Self.coachRest(row) }

    init(row: ExerciseRow, week: Int, last: PastResult?, savedSets: [WorkoutSet]?, state: AppState) {
        self.row = row
        self.last = last
        restSeconds = state.rest[Self.key(row)] ?? Self.coachRest(row)
        note = state.notes[Self.key(row)] ?? ""
        sets = savedSets ?? Self.startingSets(row: row, week: week, last: last)
    }

    private static func key(_ row: ExerciseRow) -> String {
        row.name.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    private static func coachRest(_ row: ExerciseRow) -> Int { SetValues.restSeconds(row.note) ?? 90 }

    /// Already recorded in this week: show it to edit. Otherwise start from last time.
    private static func startingSets(row: ExerciseRow, week: Int, last: PastResult?) -> [WorkoutSet] {
        let current = row.weeks[week]
        let recorded = !current.isEmpty
        let kgs = SetValues.split(recorded ? current.load : last?.load ?? "")
        var reps = SetValues.split(recorded ? current.reps : last?.reps ?? "")
        if reps.isEmpty { reps = SetValues.targetReps(row.repGoal) }
        let count = recorded ? max(kgs.count, reps.count) : SetValues.setCount(row.sets)

        func pick(_ values: [String], _ i: Int) -> String { values.isEmpty ? "" : values[min(i, values.count - 1)] }
        return (0..<count).map { WorkoutSet(kg: pick(kgs, $0), reps: pick(reps, $0), done: recorded) }
    }

    // MARK: Text for the card

    var name: String { SessionPlanner.pretty(row.name) }
    var coachNote: String { row.note }
    var repGoal: String { row.repGoal.replacingOccurrences(of: "\n", with: "  ·  ") }
    var setsText: String { row.sets.isEmpty ? "\(sets.count) serie" : "\(row.sets) serie" }

    var lastLoad: String {
        guard let last else { return "" }
        let load = last.load.isEmpty ? "" : "\(last.load) kg"
        return load + (!last.load.isEmpty && !last.reps.isEmpty ? "  ×  " : "") + last.reps
    }

    var restLabel: String {
        let min = restSeconds / 60, sec = restSeconds % 60
        return sec == 0 ? "\(min)'" : "\(min)'" + String(format: "%02d\"", sec)
    }

    var doneCount: Int { sets.filter(\.done).count }
    var isComplete: Bool { !sets.isEmpty && sets.allSatisfy(\.done) }
    var progressText: String { "\(doneCount)/\(sets.count)" }

    // MARK: Buttons of the card

    mutating func addSet() {
        let previous = sets.last
        sets.append(WorkoutSet(kg: previous?.kg ?? "", reps: previous?.reps ?? ""))
    }

    mutating func removeSet() {
        if sets.count > 1 { sets.removeLast() }
    }

    /// Clears kg, reps and ticks of every set, keeping the number of sets.
    mutating func reset() {
        sets = sets.map { _ in WorkoutSet() }
    }

    mutating func cycleRest() {
        restSeconds = Self.restChoices.first { $0 > restSeconds } ?? Self.restChoices[0]
    }
    
    mutating func restSecondsPlus() {
        restSeconds += 30
    }
    
    mutating func restSecondsMinus() {
        restSeconds = max(restSeconds - 30, 15)
    }
}
