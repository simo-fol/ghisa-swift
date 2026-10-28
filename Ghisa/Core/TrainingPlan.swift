import Foundation

/// One sheet of the workbook: a training protocol lasting one or two months.
final class TrainingProtocol {
    let sheetName: String
    let startLabel: String?
    let coach: String?
    var microcycles: [Microcycle] = []

    init(sheetName: String, startLabel: String?, coach: String?) {
        self.sheetName = sheetName
        self.startLabel = startLabel
        self.coach = coach
    }

    var splitLetters: [String] {
        var seen: [String] = []
        for letter in microcycles.flatMap(\.splits).map(\.letter) where !seen.contains(letter) {
            seen.append(letter)
        }
        return seen
    }
}

/// A block of the sheet ("MICROCICLO n") holding the 4 weeks of every split.
final class Microcycle {
    let number: Int
    var splits: [SplitBlock] = []

    init(number: Int) { self.number = number }

    func split(_ letter: String) -> SplitBlock? { splits.first { $0.letter == letter } }
}

/// A training day (SPLIT A/B/C/D) inside a microcycle.
final class SplitBlock {
    let letter: String
    let weekLabels: [String]
    var exercises: [ExerciseRow] = []

    init(letter: String, weekLabels: [String]) {
        self.letter = letter
        self.weekLabels = weekLabels
    }

    func isWeekFilled(_ week: Int) -> Bool { exercises.contains { !$0.weeks[week].isEmpty } }
}

final class ExerciseRow {
    let row: Int
    let name: String
    let note: String
    let repGoal: String
    let sets: String
    let weeks: [WeekCell]

    init(row: Int, name: String, note: String, repGoal: String, sets: String, weeks: [WeekCell]) {
        self.row = row
        self.name = name
        self.note = note
        self.repGoal = repGoal
        self.sets = sets
        self.weeks = weeks
    }
}

/// Load and reps cells of one week ("SET I".."SET IV") of an exercise.
final class WeekCell {
    let loadRef: String
    let repsRef: String
    var load: String
    var reps: String

    init(loadRef: String, repsRef: String, load: String, reps: String) {
        self.loadRef = loadRef
        self.repsRef = repsRef
        self.load = load
        self.reps = reps
    }

    var isEmpty: Bool { load.isEmpty && reps.isEmpty }
}

/// Position of a workout: microcycle index and week index (both 0-based).
struct Slot: Equatable, Hashable {
    var micro: Int
    var week: Int

    static let roman = ["I", "II", "III", "IV", "V", "VI"]

    var weekLabel: String { week < Self.roman.count ? Self.roman[week] : String(week + 1) }
}
