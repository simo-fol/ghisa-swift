//
//  IntervalTimer.swift
//  Ghisa
//
//  Created by Simone Folino on 28/10/26.
//

import Foundation
import Observation

/// Counts down prepare → work → rest → work … for the chosen number of rounds.
@Observable
final class IntervalTimer {
    enum Phase {
        case idle, prepare, work, rest, finished

        var title: String {
            switch self {
            case .idle: "Pronto"
            case .prepare: "Preparati"
            case .work: "Lavoro"
            case .rest: "Recupero"
            case .finished: "Finito!"
            }
        }

        /// Beep played when this phase starts (file name in Resources/Sounds, without ".wav").
        var sound: String {
            switch self {
            case .rest: "phase-rest"
            case .finished: "phase-done"
            case .idle, .prepare, .work: "phase-work"
            }
        }
    }

    private(set) var phase = Phase.idle
    private(set) var round = 0
    private(set) var remaining = 0
    private(set) var isPaused = false
    private(set) var phaseLength = 0

    @ObservationIgnored private var settings = IntervalSettings()
    @ObservationIgnored private var endsAt = Date()
    @ObservationIgnored private var pausedLeft = 0.0
    @ObservationIgnored private var tick: Timer?

    var isRunning: Bool { phase != .idle && phase != .finished }
    /// 0 at the start of the phase, 1 at the end: drives the ring.
    var progress: Double {
        phaseLength == 0 ? 0 : 1 - Double(remaining) / Double(phaseLength)
    }

    // MARK: Buttons

    func start(_ settings: IntervalSettings) {
        self.settings = settings
        round = 1
        isPaused = false
        if settings.prepare > 0 {
            enter(.prepare, seconds: settings.prepare)
        } else {
            enter(.work, seconds: settings.work)
        }
        tick?.invalidate()
        tick = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.update()
        }
        Platform.keepScreenOn(true)
        Platform.requestNotificationPermission()
        scheduleAlerts()
    }

    func pause() {
        guard isRunning, !isPaused else { return }
        pausedLeft = endsAt.timeIntervalSinceNow
        isPaused = true
        Platform.cancelIntervalAlerts()
    }

    func resume() {
        guard isPaused else { return }
        endsAt = Date().addingTimeInterval(pausedLeft)
        isPaused = false
        scheduleAlerts()
    }

    func stop() {
        tick?.invalidate()
        tick = nil
        phase = .idle
        isPaused = false
        Platform.cancelIntervalAlerts()
        Platform.keepScreenOn(false)
    }

    // MARK: Counting

    /// Starts a phase. `start` is when the previous one ended, so after the app has been
    /// in the background the phases still line up with the clock.
    private func enter(_ newPhase: Phase, seconds: Int, start: Date = Date()) {
        phaseLength = seconds
        phase = newPhase
        remaining = seconds
        endsAt = start.addingTimeInterval(Double(seconds))
    }

    private func update() {
        guard isRunning, !isPaused else { return }
        // Usually one step; several if the app was in the background meanwhile.
        while isRunning, endsAt <= Date() { nextPhase() }
        if isRunning { remaining = max(0, Int(endsAt.timeIntervalSinceNow.rounded(.up))) }
    }

    private func nextPhase() {
        guard let next = Self.following(phase, round: round, settings: settings) else { return }
        // Phases that ended while the app was in the background already rang as notifications.
        if Date().timeIntervalSince(endsAt) < 1 { Platform.phaseAlert(sound: next.phase.sound) }
        round = next.round
        if next.phase == .finished {
            tick?.invalidate()
            tick = nil
            phase = .finished
            remaining = 0
            Platform.keepScreenOn(false)
        } else {
            enter(next.phase, seconds: next.seconds, start: endsAt)
        }
    }

    /// What comes after a phase: the next phase, its round and how long it lasts.
    private static func following(_ phase: Phase, round: Int, settings: IntervalSettings)
        -> (phase: Phase, round: Int, seconds: Int)? {
        switch phase {
        case .prepare:
            return (.work, round, settings.work)
        case .work where round == settings.rounds:
            return (.finished, round, 0)
        case .work where settings.rest > 0:
            return (.rest, round, settings.rest)
        case .work, .rest:
            return (.work, round + 1, settings.work)
        case .idle, .finished:
            return nil
        }
    }

    // MARK: Alerts

    /// One notification per upcoming phase change, so the timer is heard with the phone locked.
    private func scheduleAlerts() {
        var alerts: [(after: TimeInterval, title: String, body: String, sound: String)] = []
        var at = endsAt.timeIntervalSinceNow
        var current = (phase: phase, round: round)
        while let next = Self.following(current.phase, round: current.round, settings: settings) {
            let body = next.phase == .finished
                ? "\(settings.rounds) giri completati 💪"
                : "Giro \(next.round) di \(settings.rounds) · \(IntervalSettings.format(next.seconds))"
            alerts.append((at, next.phase.title, body, next.phase.sound))
            at += Double(next.seconds)
            current = (next.phase, next.round)
        }
        Platform.scheduleIntervalAlerts(alerts)
    }
}
