# Ghisa

Versione SwiftUI dell'app *Allenamento* (repository `ghisa`, Avalonia/.NET): stesse funzioni, scritta tutta in Swift. Legge la scheda Excel del coach, ti guida nello split del giorno e scrive carichi e ripetizioni nel file.

- Scegli lo split (A/B/C/D): l'app trova da sola microciclo e settimana da fare (la prima colonna SET vuota dopo l'ultima compilata). Con ‹ › puoi spostarti su un'altra settimana.
- Per ogni esercizio vedi note del coach, rep goal, serie e **l'ultima volta** (stesso split, oppure lo stesso esercizio in un protocollo precedente).
- Kg e reps partono dall'ultima volta; li correggi con − / + o scrivendoli. Il ✓ chiude la serie e avvia il **recupero** (letto da `REST 60"` nelle note, altrimenti 1'30"; tocca il pulsante per cambiarlo, viene ricordato per esercizio).
- Notifica a fine recupero anche a telefono bloccato; schermo sempre acceso durante l'allenamento.
- **Le tue note** per esercizio restano salvate e le ritrovi la volta dopo.
- **Termina e salva** scrive nel foglio, nelle celle Carico/Reps della settimana, nel formato `20-22.5-25` / `8-7-6`. Formattazione, colori e celle unite restano intatti.
- Se l'app viene chiusa a metà allenamento, lo riprendi dalla home.

Ha un bundle ID diverso (`com.simone.ghisa`) dall'app Avalonia, quindi possono stare installate insieme.

## Dove sono le cose

| Cartella | Cosa contiene |
|---|---|
| `Ghisa/Core` | Lettura/scrittura xlsx senza dipendenze (zip e XML fatti a mano), interpretazione della scheda, calcolo della prossima seduta. Porting fedele di `WorkoutLog.Core`. |
| `Ghisa/Models` | Stato delle schermate: home, allenamento, esercizi, serie, timer di recupero. |
| `Ghisa/Views` | Le schermate SwiftUI. Aprile in Xcode e usa il Canvas (⌥⌘↩) per l'anteprima. |
| `Ghisa/Services` | Salvataggio dello stato, notifiche, schermo acceso, vibrazione. |

Dove si segna "fatto":
- **serie**: tasto ✓ in `Views/WorkoutView.swift` (`SetRow`), logica in `SetModel.toggleDone()` in `Models/WorkoutModel.swift`;
- **esercizio**: completo quando tutte le serie hanno la ✓ (`ExerciseModel.isComplete`);
- **allenamento**: pulsante *Termina e salva*, logica in `WorkoutModel.finish()`.

## Aprire e provare sul Mac

Apri `Ghisa.xcodeproj` con Xcode, scegli un simulatore iPhone e premi ▶︎.

Il progetto Xcode è generato da `project.yml` con [XcodeGen](https://github.com/yonaskolb/XcodeGen). I file `.swift` nuovi dentro `Ghisa/` vanno aggiunti al progetto: o da Xcode, o rigenerandolo con `xcodegen`.

## Build dell'app iPhone

Ogni push su `main` avvia `.github/workflows/ios.yml` su un runner macOS gratuito di GitHub: produce `Ghisa.ipa` non firmato e lo pubblica nella release **latest** del repository (oltre che come artifact della run).

## Installazione sull'iPhone

Uguale all'app Avalonia: dall'iPhone apri la release *latest*, scarica `Ghisa.ipa` e installalo con SideStore (**My Apps › +**). Con un Apple ID gratuito va rinnovata ogni 7 giorni (*My Apps › Refresh*).

La copia di lavoro dell'Excel è in **File › Sul mio iPhone › Ghisa**; quando iOS lo permette l'app aggiorna anche il file originale scelto.

Il file Excel non va mai nel repository (`*.xlsx` è in `.gitignore`).
