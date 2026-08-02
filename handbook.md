# bankrun8 — Handbuch

Kurzreferenz zu `bankrun8.nlogox`: alle Regler, alle Kennzahlen, alle Experimente.

---

## 1. Was das Modell macht

200 Einleger sind Knoten in einem Netzwerk. Jeder ist in einem von drei Zuständen:

`calm` → `concerned` → `withdraw`

Wer abhebt, entzieht der Bank Liquidität. Fällt die Liquidität unter null, ist die Bank tot.
Ein Agent eskaliert, wenn sein **wahrgenommenes Signal** seine persönliche Schwelle übersteigt.

**Hauptfrage:** Führen mehr Verbindungen zu einem höheren Bankrun-Risiko?

**Zusatzfrage:** Ändert sich die Antwort, je nachdem ob Signale gemittelt (`average`) oder
als Ansteckung aufaddiert (`sir`) werden?

---

## 0. Welches Experiment beantwortet welchen Feedback-Punkt?

| Feedback Vanberg | Experiment | Was gezeigt wird |
|---|---|---|
| **Übergeordnet:** beruht die Intuition auf impliziten Annahmen? Zeigen, dass ein geänderter Mechanismus sie wahr macht | **2** | Aggregationsregel umschalten kehrt das Ergebnis um |
| **1** credibility spielt keine prominente Rolle | **8** | credibility an/aus bei gleicher mittlerer Übertragungsstärke: Heterogenität senkt die kritische Netzdichte um ~4 Verbindungen |
| **2** Geschwindigkeit vs. Anzahl verarbeiteter Signale trennen | **4** (Trennung), **6** (Tempo messen), **5** (Tempo wird kausal) | Bei konstanter Signalmenge verschwindet der Effekt → er läuft über die Menge, nicht über kürzere Wege |
| **3** nicht alle Verbindungen haben Einfluss; nur ein Teil wird angeschaut | **4** | `normalize-exposure?` ist genau das: Dichte steigt, verarbeitete Signalmenge bleibt konstant |
| **4** Negativity Bias: negative Signale wirken stärker | **3** | `negativity-bias` wertet ruhige Kontakte ab — Vanbergs "äquivalente" Formulierung |
| **Nebenkommentar:** wozu `forgetting`, woher der monotone `concern` | **7** | `baseline-noise` ist eine Einbahn-Ratsche; ohne `forgetfulness` steigt `frac-concerned` monoton |

Experiment **1** ist reine Vorarbeit (Kalibrierung) und beantwortet keine inhaltliche Frage.

---

## 2. Regler im Interface

10 Regler, 4 Monitore, 2 Plots.

### Der wichtigste: `signal-aggregation`

Bestimmt, **wie** ein Agent die Signale seiner Nachbarn zu einem Gesamteindruck verrechnet.

| Wert | Regel | Folge |
|---|---|---|
| `average` | Mittelwert über **alle** Nachbarn (wie bankrun7) | Ruhige Nachbarn stehen im Nenner und verdünnen die Panik. Mehr Verbindungen = stärkere Verdünnung → **weniger Bankruns** |
| `sir` | Ansteckung addiert sich über die **Anzahl** alarmierter Nachbarn | Ruhige Nachbarn verdünnen nichts. Mehr Verbindungen = mehr Alarmquellen → **mehr Bankruns** |

Beispiel bei 20 Verbindungen und einem abhebenden Nachbarn: `average` liefert 0.9/20 = 0.045,
praktisch nichts. `sir` liefert die volle Ansteckungschance dieses einen Kontakts — egal wie
viele andere ruhig sind.

### Netzwerk und Übertragung

| Regler | Bereich | Bedeutung |
|---|---|---|
| `avg-connections` | 2–20 | Verbindungen pro Knoten. **Die Hauptvariable.** |
| `transmissibility` | 0–1 | Wahrscheinlichkeit, dass *ein* alarmierter Kontakt dich ansteckt — pro Tick, pro Verbindung. Nur bei `sir` wirksam. Kalibriert auf **0.10**. |
| `negativity-bias` | 1–4 | Wie viel **weniger Aufmerksamkeit ein ruhiger Nachbar** bekommt als ein alarmierter. |

**`negativity-bias` genau:** Beide negativen Zustände übertragen voll — `concerned` halb so
stark wie `withdraw`. Abgewertet wird nur die **Ruhe**:

```
wahrgenommenes Signal = Alarm × (1 − Anteil ruhiger Nachbarn / negativity-bias)
```

| Wert | Ein ruhiger Nachbar zählt |
|---|---|
| 1 | voll — kein Bias (Kontrollbedingung) |
| 2 | zur Hälfte |
| 4 | zu einem Viertel |

Wer alarmiert ist, wird also eher beobachtet als wer ruhig ist. Ruhe dämpft den Alarm, kann ihn
aber nicht mehr wegmitteln — sie skaliert mit dem *Anteil* ruhiger Nachbarn und sättigt dadurch,
während der Alarm mit ihrer *Anzahl* wächst.

### Verhalten der Agenten

| Regler | Bereich | Bedeutung |
|---|---|---|
| `risk-threshold` | 0.05–1 | Skaliert die Schwellen aller Agenten. **Hoch = stabiler.** Jeder Agent bekommt daraus zwei individuelle Schwellen: eine für `concerned`, eine höhere für `withdraw`. |
| `forgetfulness` | 0–0.5 | Wahrscheinlichkeit pro Tick, einen Zustand **zurückzufallen** (`withdraw` → `concerned` → `calm`). Beim Verlassen von `withdraw` wird das Geld wieder eingezahlt. |

**Wozu `forgetfulness`?** Das Grundrauschen macht ruhige Agenten von selbst besorgt, aber es
gibt keinen automatischen Rückweg. Ohne `forgetfulness` steigt der Anteil besorgter Agenten
deshalb monoton — nicht weil sich etwas ausbreitet, sondern weil sich Zufall aufstaut.
`forgetfulness` ist die Gegenkraft. Experiment 7 prüft, wie stark das Ergebnis daran hängt.

### Bank

| Regler | Bereich | Bedeutung |
|---|---|---|
| `reserve-ratio` | 0.01–0.5 | Reservequote: Anteil der Einlagen, den die Bank liquide hält. Bestimmt auch das Signal — `signal = (reserve-ratio − tatsächliche Quote) / reserve-ratio` |
| `lolr-cap` | 0–0.1 | **Nachschubrate der Zentralbank pro Tick**, als Anteil der Anfangseinlagen. Nur wirksam bei `lolr-active? = on`. |
| `lolr-active?` | on/off | **Lender of Last Resort.** Wenn an, füllt die Zentralbank die Liquidität jeden Tick um höchstens `lolr-cap` auf — **bevor** geprüft wird, ob die Bank tot ist. Daraus entsteht ein Rennen: Abflussrate gegen Nachschubrate. |
| `fundamental-shock?` | on/off | Art des Schocks. `off` = Panik-Schock (ein Gerücht trifft einige Watcher, die Bank ist objektiv gesund). `on` = echter Liquiditätsverlust. |

---

## 3. Monitore und Plots

| Monitor | Bedeutung |
|---|---|
| `bank-alive?` | Lebt die Bank noch? **Das Ergebnis.** |
| `liquidity-ratio` | Liquidität geteilt durch Einlagen. Fällt sie unter `reserve-ratio`, steigt das Signal. |
| `frac-withdrawn` | Anteil der Agenten, die gerade abgehoben haben. |
| `peak-withdrawn` | Höchststand von `frac-withdrawn` im Lauf. Bleibt stehen, auch wenn sich Agenten wieder beruhigen. |

Plot **States** zeigt die drei Zustandsanteile, Plot **Bank** Liquidität und Signal.

---

## 4. Kennzahlen in den CSV-Dateien

| Kennzahl | Bedeutung |
|---|---|
| `bank-alive?` | Primäres Ergebnis. Auswerten als **Anteil `false`** je Parameterzelle. |
| `clean-run?` | **Immer prüfen.** Wahr, wenn der Schock wirklich der Auslöser war. Falsch, wenn das Grundrauschen die Kaskade schon vor dem Schock gezündet hat — dann ist `transmissibility` zu hoch und der Lauf ist wertlos. |
| `withdrawn-at-shock` | Anteil Abhebungen unmittelbar vor dem Schock. Rohwert hinter `clean-run?`. |
| `peak-withdrawn` | Höchststand im Lauf. |
| `ticks-since-shock` | Beim Abbruch die Überlebensdauer nach dem Schock. **`-1` heißt: der Schock hat nie gefeuert**, die Bank starb schon im Warmup. |
| `frac-withdrawn`, `frac-concerned`, `liquidity-ratio` | Endzustand |
| `eff-transmissibility` | Nur in Experiment 4. Die tatsächlich verwendete Übertragungs-WSK — Kontrolle, dass die Normalisierung greift. |

---

## 5. Fest verdrahtete Werte

Diese waren in bankrun7 Regler, wurden aber nie variiert. Sie stehen jetzt in der Prozedur
`set-constants` im Code — dort ändern, falls nötig.

| Konstante | Wert | Bedeutung |
|---|---|---|
| `num-nodes` | 200 | Anzahl Einleger |
| `beta` | 0.1 | Rewiring-Wahrscheinlichkeit (Small-World-Abkürzungen) |
| `watcher-share` | 0.2 | Anteil Agenten, die das Banksignal direkt sehen |
| `spontaneous-concern` | 0.001 | Grundrauschen: WSK pro Tick, ohne Anlass besorgt zu werden |
| `shock-size` | 0.5 | Anteil der Watcher, den der Schock trifft |
| `warmup-ticks` | 25 | Ticks bis zum Schock |
| `normalize-exposure?` | false | Versteckt, siehe Experiment 4 |
| `watcher-credibility` | 0.9 | Versteckt: Untergrenze der Watcher-credibility |
| `credibility-on?` | true | Versteckt, siehe Experiment 8 |

> **`spontaneous-concern` wurde von 0.005 auf 0.001 gesenkt.** Im Mittelungsmodell war der
> Rauschboden harmlos. Im `sir`-Modell ist jeder besorgte Agent eine Zündquelle — mit 0.005
> waren nach 25 Warmup-Ticks schon rund 24 von 200 Agenten besorgt, genug um die Kaskade vor
> dem Schock auszulösen.

### Zwei versteckte Details

**`normalize-exposure?`** hat bewusst kein Widget: es ist ein rein methodischer Schalter, der
nur in Experiment 4 gebraucht wird. BehaviorSpace kann ihn trotzdem setzen, weil `setup` **kein
`clear-all`** benutzt (das würde die Variable löschen) sondern alles einzeln leert.

**Ungerade `avg-connections` haben keinen Effekt.** Das Netz wird über
`floor(avg-connections / 2)` Verbindungen je Richtung aufgebaut — 13 erzeugt also dasselbe Netz
wie 12. Deshalb laufen alle Experimente in **2er-Schritten**.

---

## 6. Die 7 Experimente

| # | Name | Variiert | Beantwortet |
|---|---|---|---|
| 1 | `transmissibility_x_degree` | `transmissibility` 0.05–0.25 × Grad | Welcher Übertragungswert ist brauchbar? |
| 2 | `degree_x_aggregation_MAIN` | Grad × `signal-aggregation` × `lolr-active?` | **Hauptergebnis** |
| 3 | `degree_x_negativity_bias` | Grad × `negativity-bias` 1–4 | Wie viel Bias braucht es? |
| 4 | `degree_x_signalvolume` | Grad × `normalize-exposure?` | Menge der Signale oder Struktur? |
| 5 | `degree_x_lolr_cap` | Grad × `lolr-cap` | Wann überholt die Panik die Zentralbank? |
| 6 | `degree_x_aggregation_timeseries` | Grad × `signal-aggregation` | Wie sieht der Zeitverlauf aus? |
| 7 | `forgetfulness_x_ticks` | Grad × `forgetfulness` 0–0.1, **Zeitreihen** | Woher kommt der monotone `concern`? |
| 8 | `degree_x_credibility_onoff` | Grad × `credibility-on?` | Braucht das Modell credibility überhaupt? |

**Immer plotten:** Anteil toter Banken je Parameterzelle über `avg-connections`. Die Ergebnisse
sind bimodal (ein Lauf verpufft oder läuft ganz durch), ein Mittelwert wäre irreführend.

### 1 — `transmissibility_x_degree` · 880 Läufe

**Zuerst laufen lassen.** Sucht den Bereich, in dem das Modell aussagefähig ist: zu klein →
nichts passiert, zu groß → alles stirbt und das dichte Netz zündet schon vor dem Schock.

Gemessen (10 Wdh., `spontaneous-concern` 0.001):

| transmissibility | k=2 | k=6 | k=12 | k=20 | saubere Läufe |
|---|---|---|---|---|---|
| **0.10** | **0.00** | **0.00** | **0.20** | **1.00** | **alle, bei jedem Bias** |
| 0.15 | 0.00 | 0.00 | 1.00 | 1.00 | ab Bias 2 fallend |
| 0.20 | 0.00 | 0.20 | 1.00 | 1.00 | 0.70 / 0.10 |
| 0.25 | 0.00 | 0.80 | 1.00 | 1.00 | 0.40 / 0.20 |

→ Default ist **0.10**: der einzige Wert, bei dem über die ganze Bias-Spanne alle Läufe
sauber bleiben.

### 2 — `degree_x_aggregation_MAIN` · 2.000 Läufe ⭐

Das Kernergebnis. Beide Aggregationsregeln laufen im selben Experiment, `signal-aggregation`
ist eine Spalte in derselben CSV.

Gemessen (25 Wdh., transmissibility 0.10, negativity-bias 2, LoLR an):

| | k=2 | 4 | 6 | 8 | 10 | 12 | 14 | 16 | 18 | 20 |
|---|---|---|---|---|---|---|---|---|---|---|
| `average` | 0.88 | 0.40 | 0.32 | 0.12 | 0.24 | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 |
| `sir` | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.08 | 0.24 | 0.72 | 0.96 | 1.00 |

**Aussage:** Ob mehr Verbindungen zu mehr Bankruns führen, hängt vollständig davon ab, wie
Menschen Signale verarbeiten. Werden sie gemittelt, schützt Vernetzung. Addieren sie sich,
gefährdet sie — und zwar mit einer klaren Schwelle bei etwa 14–18 Verbindungen.

Die ursprüngliche Intuition ist damit nicht falsch, sondern sie setzt stillschweigend voraus,
dass Alarmsignale sich aufaddieren statt sich zu mitteln.

### 3 — `degree_x_negativity_bias` · 1.500 Läufe

Prüft, wie stark das Ergebnis davon abhängt, dass Ruhe weniger Aufmerksamkeit bekommt.
`negativity-bias = 1` ist die Kontrollbedingung ohne Bias.

> **Wichtig für die Interpretation:** Der Effekt kehrt sich auch bei `bias = 1` schon um. Die
> Ursache ist die Aggregationsregel selbst (Alarm addiert sich, Ruhe sättigt), nicht der
> Regler. `negativity-bias` verschärft die Schwelle zusätzlich.

### 4 — `degree_x_signalvolume` · 600 Läufe

Trennt die beiden Wege, auf denen Vernetzung wirken kann.

| `normalize-exposure?` | Was passiert |
|---|---|
| `false` | Normalfall: mehr Verbindungen bedeuten mehr *und* schneller ankommende Signale |
| `true` | `transmissibility` wird durch den Grad geteilt, sodass jeder Knoten im Schnitt **gleich viele wirksame Signale** bekommt. Nur die Netzstruktur variiert noch. |

Erste Messung (25 Wdh.): mit `normalize-exposure? = true` verschwindet der Effekt
**vollständig** — 0.00 bei allen Graden von 2 bis 20, statt der Sigmoide bis 1.00.

**Aussage:** Der Effekt läuft praktisch ganz über die **Menge** der verarbeiteten Signale, nicht
über kürzere Wege im Netz. Mehr Kontakte gefährden, weil man mehr Alarme *sieht* — nicht weil
Information schneller herumkommt.

### 5 — `degree_x_lolr_cap` · 1.200 Läufe

Höheres `lolr-cap` sollte die kritische Dichte nach rechts verschieben. Damit lässt sich
formulieren: *ab welcher Vernetzung überholt die Ansteckung die Politikreaktion?* Das gibt auch
dem Tick eine Bedeutung — ein Tick ist die Zeit, in der die Zentralbank `lolr-cap`
bereitstellen kann.

### 6 — `degree_x_aggregation_timeseries` · 120 Läufe

Liefert **Zeitreihen** statt Endwerte. Läuft mit `go-event`: die tote Bank wird eingefroren und
weitergetickt, damit alle Läufe gleich lang sind und sich mitteln lassen.

Plotten: `frac-withdrawn` über **`ticks-since-shock`**, nicht über `ticks`. Die Steigung direkt
nach t = 0 ist das Geschwindigkeitsmaß. Beim Auswerten `ticks-since-shock >= 0` filtern.

### 7 — `forgetfulness_x_ticks` · 240 Läufe, Zeitreihen

Beantwortet Vanbergs Rückfrage direkt: *woher kommt der monoton steigende `concern`, und wozu
braucht ihr `forgetting`?*

**Die Antwort steht im Code:** `baseline-noise` ist eine **Einbahn-Ratsche**. Ruhige Agenten
werden mit `spontaneous-concern` von selbst besorgt, aber es gibt keinen automatischen Rückweg.
`concerned` ist dadurch quasi-absorbierend und der Anteil staut sich auf — nicht weil sich etwas
ausbreitet, sondern weil sich Zufall akkumuliert. `forgetfulness` ist die einzige Gegenkraft.

Braucht Zeitreihen, sonst ist der Drift nicht sichtbar. Erste Messung (k=6, `frac-concerned`):

| `forgetfulness` | t=50 | t=100 | t=150 | t=200 |
|---|---|---|---|---|
| **0** | 0.380 | 0.415 | 0.450 | **0.472** — steigt monoton |
| 0.02 | 0.323 | 0.232 | 0.155 | 0.103 — klingt ab |
| 0.1 | 0.033 | 0.010 | 0.010 | 0.010 |

Die letzte Zeile jedes Laufs liefert zusätzlich den Endzustand — damit lässt sich prüfen, ob das
Hauptergebnis von `forgetfulness` abhängt.

Plotten: `frac-concerned` über `ticks-since-shock`, eine Linie je `forgetfulness`.

### 8 — `degree_x_credibility_onoff` · 600 Läufe

Beantwortet Vanbergs Punkt 1 — und zugleich die Frage, ob credibility überhaupt bleiben soll.

`credibility` macht im Modell zwei verschiedene Dinge, die man trennen muss:

1. **Streuung innerhalb der Gruppen** — Nicht-Watcher bekommen zufällig 0–0.5. Reines Rauschen.
2. **Unterschied in der Sendestärke** — Watcher übertragen mit ~0.95, Nicht-Watcher mit ~0.25,
   also rund viermal so stark.

> Gemeint ist ausschließlich der Unterschied in den **Zahlenwerten** der credibility, also wie
> stark jemand sendet. Eine räumliche oder topologische Nähe zwischen Watchern und
> Nicht-Watchern gibt es im Modell nicht: Wer Watcher wird, ist ein unabhängiger Münzwurf pro
> Agent, und das Netz wird über den Index (`who`) gebaut, ohne jeden Bezug zu `watcher?` oder zu
> Koordinaten. Die xy-Positionen im View sind reine Darstellung (`layout-spring`) und haben
> keinerlei Einfluss auf das Modell — es zählt allein, **wer mit wem verbunden ist**.

Der Toggle schaltet beides zusammen ab: bei `credibility-on? = false` senden **alle** mit
demselben Wert. Dieser Wert ist so gewählt, dass die **mittlere Übertragungsstärke im Netz
gleich bleibt** (Populationsmittel ≈ 0.39). Ein Unterschied im Ergebnis geht dann allein auf die
**Ungleichverteilung** zurück, nicht auf mehr oder weniger Ansteckung insgesamt.

Gemessen (25 Wdh., P(Bank stirbt)):

| | k=10 | 12 | 14 | 16 | 18 | 20 |
|---|---|---|---|---|---|---|
| credibility **an** | 0.00 | 0.08 | 0.56 | 0.76 | 0.96 | 1.00 |
| credibility **aus** (flach) | 0.00 | 0.00 | 0.00 | 0.00 | 0.48 | 0.92 |

**Aussage:** Credibility hat sehr wohl Erklärungskraft. Bei gleicher durchschnittlicher
Ansteckungsstärke verschiebt die Heterogenität die **kritische Netzdichte um rund 4
Verbindungen nach unten**. Wenige, besonders glaubwürdige Knoten zünden die Kaskade früher als
viele gleich laute. Für die Story: es kommt nicht nur darauf an, *wie viele* Verbindungen
existieren, sondern *wie ungleich* die Einflussstärke verteilt ist.

**Kontrolle `watcher-impact-gap`** (Anteil abhebender Watcher minus Anteil beim Rest):

| | k=14 | 16 | 18 | 20 |
|---|---|---|---|---|
| credibility an | +0.27 | +0.34 | +0.43 | +0.43 |
| credibility aus | 0.00 | 0.00 | +0.22 | +0.39 |

Die Watcher behalten ihren Vorsprung also auch ohne credibility — sie hören das Banksignal
direkt und sind das Ziel des Schocks. Der Vorteil ist bei ausgeschalteter credibility nicht
kleiner, er setzt nur später ein, weil die Kaskade insgesamt später kippt.

---

## 7. Experimente ohne GUI ausführen

Es gibt kein System-Java, die mitgelieferte Laufzeit muss angegeben werden:

```bash
JAVA_HOME="/Applications/NetLogo 7.0.4/runtime/Contents/Home" "/Applications/NetLogo 7.0.4/netlogo-headless.sh" --model ~/Downloads/bankrun8.nlogox --experiment 2_degree_x_aggregation_MAIN --table main.csv --threads 4
```
