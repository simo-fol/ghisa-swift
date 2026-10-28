import Foundation

/// Previous result of an exercise, with where it was found.
struct PastResult {
    let whereLabel: String
    let load: String
    let reps: String
}

enum SessionPlanner {
    /// All slots of a split in chronological order (microcycle by microcycle, week by week).
    static func slots(_ p: TrainingProtocol, _ letter: String) -> [Slot] {
        var result: [Slot] = []
        for (m, micro) in p.microcycles.enumerated() {
            guard let block = micro.split(letter) else { continue }
            for w in block.weekLabels.indices { result.append(Slot(micro: m, week: w)) }
        }
        return result
    }

    static func block(_ p: TrainingProtocol, _ letter: String, _ slot: Slot) -> SplitBlock? {
        slot.micro < p.microcycles.count ? p.microcycles[slot.micro].split(letter) : nil
    }

    static func isFilled(_ p: TrainingProtocol, _ letter: String, _ slot: Slot) -> Bool {
        block(p, letter, slot)?.isWeekFilled(slot.week) == true
    }

    /// The slot right after the last one that has data: the workout to do next.
    static func nextSlot(_ p: TrainingProtocol, _ letter: String) -> Slot {
        let all = slots(p, letter)
        guard !all.isEmpty else { return Slot(micro: 0, week: 0) }
        let last = all.lastIndex { isFilled(p, letter, $0) } ?? -1
        return all[min(last + 1, all.count - 1)]
    }

    static func step(_ p: TrainingProtocol, _ letter: String, from: Slot, by delta: Int) -> Slot? {
        let all = slots(p, letter)
        guard let i = all.firstIndex(of: from) else { return nil }
        let j = i + delta
        return j >= 0 && j < all.count ? all[j] : nil
    }

    static func label(_ p: TrainingProtocol, _ slot: Slot) -> String {
        "Microciclo \(p.microcycles[slot.micro].number) · Settimana \(slot.weekLabel)"
    }

    /// Most recent result of an exercise before the given slot: first in the same split of this
    /// protocol, then anywhere in earlier protocols with the same exercise name.
    static func lastResult(_ protocols: [TrainingProtocol], _ protocolIndex: Int, _ letter: String,
                           before: Slot, _ exercise: ExerciseRow) -> PastResult? {
        let p = protocols[protocolIndex]
        let all = slots(p, letter)
        let start = all.firstIndex(of: before) ?? all.count
        let position = block(p, letter, before)?.exercises.firstIndex { $0 === exercise } ?? -1
        var i = start - 1
        while i >= 0 {
            let b = block(p, letter, all[i])!
            let match = b.exercises.first { sameName($0.name, exercise.name) }
                ?? (position >= 0 && position < b.exercises.count ? b.exercises[position] : nil)
            if let cell = match?.weeks[all[i].week], !cell.isEmpty {
                return PastResult(whereLabel: label(p, all[i]), load: cell.load, reps: cell.reps)
            }
            i -= 1
        }

        var pi = protocolIndex - 1
        while pi >= 0 {
            let old = protocols[pi]
            for m in old.microcycles.indices.reversed() {
                for b in old.microcycles[m].splits {
                    guard let match = b.exercises.first(where: { sameName($0.name, exercise.name) }) else { continue }
                    for w in match.weeks.indices.reversed() where !match.weeks[w].isEmpty {
                        return PastResult(whereLabel: "\(old.sheetName) · \(label(old, Slot(micro: m, week: w)))",
                                          load: match.weeks[w].load, reps: match.weeks[w].reps)
                    }
                }
            }
            pi -= 1
        }
        return nil
    }

    static func sameName(_ a: String, _ b: String) -> Bool { normalize(a) == normalize(b) }

    static func normalize(_ s: String) -> String {
        String(s.filter { $0.isLetter || $0.isNumber }).uppercased()
    }

    /// "LAT MACHINE presa larga" → "Lat Machine Presa Larga".
    static func pretty(_ name: String) -> String {
        var out = ""
        var startOfWord = true
        for ch in name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            out += startOfWord ? ch.uppercased() : String(ch)
            startOfWord = !(ch.isLetter || ch.isNumber || ch == "'" || ch == "’")
        }
        return out
    }
}
