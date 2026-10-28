import SwiftUI

struct HomeView: View {
    @Bindable var app: AppModel

    var body: some View {
        if let book = app.book {
            main(book.protocols)
        } else {
            welcome
        }
    }

    // MARK: No file yet

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("🏋")
                .font(.system(size: 40))
                .frame(width: 84, height: 84)
                .background(Theme.accentSoft, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
            Text("La tua scheda,\nsempre in tasca.")
                .font(.system(size: 34, weight: .bold))
            Text("Carica il file Excel del coach: scegli lo split e l'app ti guida esercizio per esercizio, con i carichi della volta scorsa e il timer di recupero.")
                .font(.system(size: 16))
                .foregroundStyle(Theme.muted)
            Button("Carica la scheda Excel") { app.isImporting = true }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 12)
        }
        .padding(28)
        .frame(maxHeight: .infinity)
    }

    // MARK: Main screen

    private func main(_ protocols: [TrainingProtocol]) -> some View {
        let index = app.selectedProtocol
        let proto = protocols[index]

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header(proto)

                if protocols.count > 1 {
                    Menu {
                        Picker("Foglio", selection: $app.selectedProtocol) {
                            ForEach(protocols.indices, id: \.self) { i in
                                Text(protocols[i].sheetName).tag(i)
                            }
                        }
                    } label: {
                        HStack {
                            Text(proto.sheetName).font(.system(size: 15))
                            Spacer()
                            Image(systemName: "chevron.down").font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundStyle(Theme.ink)
                        .padding(.horizontal, 14).padding(.vertical, 12)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }

                if let draftLabel = app.draftLabel { draftCard(draftLabel) }

                SectionLabel("SCEGLI LO SPLIT DI OGGI").padding(.top, 6).padding(.leading, 2)

                VStack(spacing: 12) {
                    ForEach(proto.splitLetters, id: \.self) { letter in
                        SplitCard(proto: proto, letter: letter) { slot in
                            app.startWorkout(protocolIndex: index, split: letter, slot: slot)
                        }
                        // A new sheet starts each card again from its next workout.
                        .id("\(proto.sheetName)-\(letter)")
                    }
                    Button {app.page = .timer} label: {
                        HStack(spacing: 14) {
                            Image(systemName: "timer")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Theme.onAccent)
                                .frame(width: 62, height: 62)
                                .background(Theme.warm, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            VStack(alignment: .leading, spacing:3) {
                                Text("Timer").font(.system(size: 19, weight: .bold))
                                Text("Lavoro · recupero · preparazione")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.muted)
                            }
                            Spacer()
                            Text("›").font(.system(size: 30)).foregroundStyle(Theme.muted)
                        }
                        .padding(16)
                        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Text(app.state.workbookFile ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
    }

    private func header(_ proto: TrainingProtocol) -> some View {
        let subtitle = [proto.startLabel == proto.sheetName ? nil : proto.startLabel, proto.coach.map { "Coach " + $0 }]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · ")

        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                SectionLabel("ALLENAMENTO")
                Text(proto.sheetName).font(.system(size: 28, weight: .bold)).lineLimit(1)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: 13)).foregroundStyle(Theme.muted)
                }
            }
            Spacer()
            if let url = app.shareURL {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 38, height: 38)
                        .background(Theme.surface2, in: Circle())
                }
                .foregroundStyle(Theme.ink)
            }
            RoundButton(label: "↻", fontSize: 18) { app.isImporting = true }
        }
        .padding(.leading, 2)
        .padding(.vertical, 4)
    }

    private func draftCard(_ label: String) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                SectionLabel("IN CORSO", color: Theme.accent)
                Text(label).font(.system(size: 15, weight: .semibold))
            }
            Spacer()
            Button("Scarta", action: app.discardDraft).buttonStyle(PillButtonStyle())
            Button("Riprendi", action: app.resumeDraft)
                .buttonStyle(PillButtonStyle(background: Theme.accent, foreground: Theme.onAccent))
        }
        .card(background: Theme.accentSoft)
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.accent, lineWidth: 1))
    }
}

/// Card of one split: starts on the next workout to do, ‹ › move to other weeks.
private struct SplitCard: View {
    let proto: TrainingProtocol
    let letter: String
    let start: (Slot) -> Void

    @State private var slot: Slot

    init(proto: TrainingProtocol, letter: String, start: @escaping (Slot) -> Void) {
        self.proto = proto
        self.letter = letter
        self.start = start
        _slot = State(initialValue: SessionPlanner.nextSlot(proto, letter))
    }

    private var exercises: [ExerciseRow] { SessionPlanner.block(proto, letter, slot)?.exercises ?? [] }
    private var isFilled: Bool { SessionPlanner.isFilled(proto, letter, slot) }

    var body: some View {
        VStack(spacing: 0) {
            Button { start(slot) } label: {
                HStack(spacing: 14) {
                    Text(letter)
                        .font(.system(size: 32, weight: .black))
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 62, height: 62)
                        .background(Theme.accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Split \(letter)").font(.system(size: 19, weight: .bold))
                        Text(exercises.prefix(3).map { SessionPlanner.pretty($0.name) }.joined(separator: " · "))
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.muted)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 8)
                    Text("›").font(.system(size: 30)).foregroundStyle(Theme.muted)
                }
                .padding(EdgeInsets(top: 16, leading: 16, bottom: 10, trailing: 16))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Rectangle().fill(Theme.line).frame(height: 1)

            HStack {
                RoundButton(label: "‹", background: .clear) { move(-1) }
                Spacer()
                VStack(spacing: 1) {
                    Text(SessionPlanner.label(proto, slot)).font(.system(size: 13, weight: .semibold))
                    Text(isFilled ? "GIÀ REGISTRATA" : "PROSSIMA")
                        .font(.system(size: 10, weight: .bold))
                        .kerning(1)
                        .foregroundStyle(isFilled ? Theme.warm : Theme.accent)
                }
                Spacer()
                RoundButton(label: "›", background: .clear) { move(1) }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
        }
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func move(_ delta: Int) {
        if let s = SessionPlanner.step(proto, letter, from: slot, by: delta) { slot = s }
    }
}

#Preview("Home") {
    RootView(app: PreviewData.app())
}

#Preview("Benvenuto") {
    RootView(app: PreviewData.emptyApp())
}
