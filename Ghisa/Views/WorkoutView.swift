import SwiftUI

struct WorkoutView: View {
    @Bindable var workout: WorkoutModel

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 50) {
                    ForEach($workout.exercises) { $exercise in
                        ExerciseCard(exercise: $exercise, workout: workout)
                    }
                }
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 20, trailing: 14))
            }
            .scrollDismissesKeyboard(.interactively)

            BottomBar(workout: workout, timer: workout.timer)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                RoundButton(label: "‹", fontSize: 26, background: .clear, action: workout.back)
                VStack(alignment: .leading, spacing: 0) {
                    Text(workout.title).font(.system(size: 22, weight: .bold))
                    Text(workout.slotLabel).font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
                Spacer()
                Text(workout.progressText)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.accent)
                    .chip(background: Theme.accentSoft)
            }
            .padding(EdgeInsets(top: 10, leading: 12, bottom: 0, trailing: 18))

            ProgressBar(value: workout.progress).frame(height: 3).padding(.horizontal, 18)
        }
    }
}

private struct ProgressBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Theme.surface2)
                Capsule().fill(Theme.accent).frame(width: geo.size.width * min(max(value, 0), 1))
            }
        }
        .animation(.easeOut(duration: 0.25), value: value)
    }
}

private struct ExerciseCard: View {
    @Binding var exercise: Exercise
    let workout: WorkoutModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { workout.toggle(exercise) } label: {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(exercise.name)
                            .font(.system(size: 17, weight: .bold))
                            .multilineTextAlignment(.leading)
                        HStack(spacing: 6) {
                            if !exercise.repGoal.isEmpty {
                                Text("🎯 " + exercise.repGoal).font(.system(size: 12, weight: .semibold)).chip()
                            }
                            Text(exercise.setsText).font(.system(size: 12, weight: .semibold)).chip()
                        }
                    }
                    Spacer(minLength: 10)
                    Button("Resetta") { exercise.reset() }
                        .buttonStyle(PillButtonStyle())
                        .padding(.trailing, 8)
                    Text(exercise.progressText)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(exercise.isComplete ? Theme.onAccent : Theme.ink)
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(exercise.isComplete ? Theme.accent : Theme.surface2,
                                    in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(EdgeInsets(top: 14, leading: 16, bottom: 12, trailing: 14))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if exercise.last != nil {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel("ULTIMA VOLTA", size: 10)
                    Text(exercise.lastLoad).font(.system(size: 15, weight: .semibold))
                    Text(exercise.last?.whereLabel ?? "").font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 9)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(EdgeInsets(top: 0, leading: 16, bottom: 12, trailing: 16))
            }

            if exercise.isExpanded { expanded }
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(exercise.isComplete ? Theme.accent.opacity(0.4)
                        : exercise.isExpanded ? Theme.surface3 : .clear, lineWidth: 1))
        .animation(.easeOut(duration: 0.2), value: exercise.isExpanded)
    }

    private var expanded: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !exercise.coachNote.isEmpty {
                (Text("Coach: ").bold().foregroundColor(Theme.warm) + Text(exercise.coachNote))
                    .font(.system(size: 14))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    .background(Theme.warm.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.warm.opacity(0.33)))
            }

            HStack(spacing: 0) {
                SectionLabel("#").frame(width: 26, alignment: .leading)
                SectionLabel("KG").frame(maxWidth: .infinity)
                SectionLabel("REPS").frame(maxWidth: .infinity)
                Color.clear.frame(width: 52, height: 1)
            }
            .padding(.top, 4)

            VStack(spacing: 8) {
                ForEach($exercise.sets) { $set in
                    SetRow(number: (exercise.sets.firstIndex { $0.id == set.id } ?? 0) + 1, set: $set) {
                        workout.toggleDone(set, in: exercise)
                    }
                }
            }

            HStack(spacing: 8) {
                Button("+ Serie") { exercise.addSet() }.buttonStyle(PillButtonStyle())
                Button("− Serie") { exercise.removeSet() }.buttonStyle(PillButtonStyle())
                Spacer()
                HStack(spacing: 5) {
                    Button("−30") { exercise.restSecondsMinus() }
                        .buttonStyle(PillButtonStyle(background: Theme.danger))
                    Button { exercise.cycleRest() } label: {
                        Text("⏱ ") + Text(exercise.restLabel).bold()
                    }
                    .buttonStyle(PillButtonStyle())
                }
            }
            // Every label stays on one line; if space is short, they shrink a little instead of wrapping.
            .lineLimit(1)
            .minimumScaleFactor(0.8)

            TextField("Le tue note (sedile 4, presa larga…)",
                      text: $exercise.note, axis: .vertical)
                .font(.system(size: 15))
                .padding(.horizontal, 12).padding(.vertical, 10)
                .frame(minHeight: 46)
                .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(EdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16))
    }
}

private struct SetRow: View {
    let number: Int
    @Binding var set: WorkoutSet
    let onDone: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text("\(number)")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.muted)
                .frame(width: 22)
            Stepper(value: $set.kg, keyboard: .decimalPad, down: { set.kgDown() }, up: { set.kgUp() })
            Stepper(value: $set.reps, keyboard: .numberPad, down: { set.repsDown() }, up: { set.repsUp() })
            Button(action: onDone) {
                Text("✓")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(set.done ? Theme.onAccent : Theme.muted)
                    .frame(width: 46, height: 46)
                    .background(set.done ? Theme.accent : .clear, in: Circle())
                    .overlay(Circle().stroke(set.done ? Theme.accent : Theme.surface3, lineWidth: 2))
            }
            .buttonStyle(.plain)
        }
        .padding(6)
        .background(set.done ? Theme.accentSoft : Theme.surface2, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// "−  value  +" with an editable value in the middle.
    private struct Stepper: View {
        @Binding var value: String
        let keyboard: UIKeyboardType
        let down: () -> Void
        let up: () -> Void

        var body: some View {
            HStack(spacing: 0) {
                RoundButton(label: "−", action: down)
                TextField("–", text: $value)
                    .keyboardType(keyboard)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 20, weight: .bold))
                    .minimumScaleFactor(0.6)
                    .frame(minHeight: 38)
                RoundButton(label: "+", action: up)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct BottomBar: View {
    let workout: WorkoutModel
    let timer: RestTimer

    var body: some View {
        VStack(spacing: 12) {
            if timer.isRunning {
                HStack {
                    RoundButton(label: "−15", size: 50, fontSize: 13, action: timer.remove15)
                    Spacer()
                    VStack(spacing: 2) {
                        Text(timer.remaining)
                            .font(.system(size: 40, weight: .black).monospacedDigit())
                            .foregroundStyle(timer.isFinished ? Theme.accent : Theme.ink)
                        Text(timer.caption).font(.system(size: 12)).foregroundStyle(Theme.muted).lineLimit(1)
                        ProgressBar(value: timer.progress).frame(width: 180, height: 4).padding(.top, 6)
                    }
                    Spacer()
                    RoundButton(label: "+15", size: 50, fontSize: 13, action: timer.add15)
                }
            }
            HStack(spacing: 10) {
                Button("Termina e salva", action: workout.finish).buttonStyle(PrimaryButtonStyle())
                if timer.isRunning {
                    Button(action: timer.stop) {
                        Text("Salta")
                            .font(.system(size: 17, weight: .semibold))
                            .padding(.horizontal, 18)
                            .frame(minHeight: 56)
                    }
                    .buttonStyle(SoftButtonStyle())
                }
            }
        }
        .padding(EdgeInsets(top: 14, leading: 16, bottom: 16, trailing: 16))
        .background(Theme.surface, in: UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24, style: .continuous))
        .background(Theme.surface.ignoresSafeArea(edges: .bottom))
    }
}

#Preview("Allenamento") {
    WorkoutView(workout: PreviewData.workout())
        .background(Theme.bg)
        .foregroundStyle(Theme.ink)
        .preferredColorScheme(.dark)
}
