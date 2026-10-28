import Foundation
import Observation

/// Rest countdown. It works on the end time, not by counting ticks, so it stays right
/// even when iOS suspends the app; the scheduled notification rings meanwhile.
@Observable
final class RestTimer {
    private(set) var isRunning = false
    private(set) var isFinished = false
    private(set) var remaining = "0:00"
    private(set) var progress = 0.0
    private(set) var caption = ""

    @ObservationIgnored private var tick: Timer?
    @ObservationIgnored private var endsAt = Date()
    @ObservationIgnored private var total = 0.0
    @ObservationIgnored private var exercise = ""

    func start(seconds: Int, exercise: String) {
        self.exercise = exercise
        total = Double(seconds)
        endsAt = Date().addingTimeInterval(total)
        caption = "Recupero · \(exercise)"
        isFinished = false
        isRunning = true
        Platform.scheduleRestAlert(after: total, exercise: exercise)
        if tick == nil {
            let timer = Timer(timeInterval: 0.2, repeats: true) { [weak self] _ in self?.update() }
            RunLoop.main.add(timer, forMode: .common)
            tick = timer
        }
        update()
    }

    private func update() {
        var left = endsAt.timeIntervalSinceNow
        if left <= 0 {
            left = 0
            if !isFinished {
                isFinished = true
                caption = "Recupero finito: vai!"
                Platform.haptic()
            }
        }
        let secs = Int(left.rounded(.up))
        remaining = "\(secs / 60):" + String(format: "%02d", secs % 60)
        progress = total == 0 ? 0 : 1 - left / total
    }

    func add15() { shift(15) }
    func remove15() { shift(-15) }

    private func shift(_ seconds: Double) {
        guard isRunning else { return }
        let now = Date()
        if endsAt < now { endsAt = now }
        endsAt += seconds
        total = max(total + seconds, 1)
        let left = endsAt.timeIntervalSince(now)
        if left > 0 {
            isFinished = false
            caption = "Recupero · \(exercise)"
            Platform.scheduleRestAlert(after: left, exercise: exercise)
        }
        update()
    }

    func stop() {
        tick?.invalidate()
        tick = nil
        isRunning = false
        isFinished = false
        Platform.cancelRestAlert()
    }
}
