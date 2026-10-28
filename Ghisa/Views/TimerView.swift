//
//  TimerView.swift
//  Ghisa
//
//  Created by Simone Folino on 28/10/26.
//

import SwiftUI

struct TimerView: View {
    let app: AppModel
    @State private var settings = IntervalSettings()
    @State private var timer = IntervalTimer()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack() {
                RoundButton(label: "‹", fontSize: 26, background: .clear, action: app.showHome)
                Text("Timer").font(.system(size: 22, weight: .bold))
            }

            if timer.phase == .idle {
                // Stopped: only the settings.
                VStack(spacing: 10) {
                    SettingRow(title: "Preparazione", value: $settings.prepare, step: 5, range: 0...60)
                    SettingRow(title: "Lavoro", value: $settings.work, step: 15, range: 15...1800)
                    SettingRow(title: "Recupero", value: $settings.rest, step: 15, range: 0...600)
                    SettingRow(title: "Giri", value: $settings.rounds, step: 1, range: 1...30, asTime: false)
                }
                Spacer()
                Button("Avvia") { timer.start(settings) }
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                // Running or finished: only the countdown.
                Spacer()
                RunningTimer(timer: timer, rounds: settings.rounds)
                Spacer()
                HStack(spacing: 10) {
                    if timer.phase == .finished {
                        Button("Nuovo timer", action: timer.stop).buttonStyle(PrimaryButtonStyle())
                    } else {
                        Button(timer.isPaused ? "Riprendi" : "Pausa") {
                            timer.isPaused ? timer.resume() : timer.pause()
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        Button(action: timer.stop) {
                            Text("Stop").font(.system(size: 17, weight: .semibold))
                                .frame(maxWidth: .infinity, minHeight: 56)
                        }
                        .buttonStyle(SoftButtonStyle())
                    }
                }
            }
        }
        .padding(EdgeInsets(top: 10, leading: 12, bottom: 0, trailing: 18))
        .padding(.bottom, 16)
        .onDisappear { timer.stop() }
    }
}

private struct SettingRow: View {
    let title: String
    @Binding var value: Int
    let step: Int
    var range: ClosedRange<Int>
    var asTime = true

    var body: some View {
        HStack {
            Text(title).font(.system(size: 17, weight: .semibold))
            Spacer()
            RoundButton(label: "−") { value = max(value - step, range.lowerBound) }
            Text(asTime ? IntervalSettings.format(value) : "\(value)")
                .font(.system(size: 22, weight: .bold).monospacedDigit())
                .frame(minWidth: 70)
            RoundButton(label: "+") { value = min(value + step, range.upperBound) }
        }
        .card(padding: 14)
    }
}

/// Big ring with the countdown in the middle.
private struct RunningTimer: View {
    let timer: IntervalTimer
    let rounds: Int

    var body: some View {
        VStack(spacing: 18) {
            Text(timer.phase.title.uppercased())
                .font(.system(size: 22, weight: .black))
                .kerning(2)
                .foregroundStyle(timer.phase.color)

            ZStack {
                Circle().stroke(Theme.surface2, lineWidth: 14)
                Circle()
                    .trim(from: 0, to: 1 - timer.progress)
                    .stroke(timer.phase.color, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timer.remaining)
                Text(IntervalSettings.format(timer.remaining))
                    .font(.system(size: 64, weight: .black).monospacedDigit())
            }
            .frame(width: 260, height: 260)

            Text("Giro \(timer.round) di \(rounds)")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity)
    }
}

extension IntervalTimer.Phase {
    var color: Color {
        switch self {
        case .prepare: Theme.warm
        case .work: Theme.accent
        case .rest: Color(hex: 0x5AC8FA)
        case .idle, .finished: Theme.muted
        }
    }
}

#Preview {
    TimerView(app: PreviewData.app())
        .background(Theme.bg)
        .foregroundStyle(Theme.ink)
        .preferredColorScheme(.dark)
}
