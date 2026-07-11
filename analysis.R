# ==============================================================================
# 0. VORBEREITUNG: Pakete installieren (falls nötig) und laden
# ==============================================================================
# Prüft, ob tidyverse installiert ist, wenn nicht, wird es installiert
if (!requireNamespace("tidyverse", quietly = TRUE)) {
  message("Installiere fehlendes Paket 'tidyverse'...")
  install.packages("tidyverse")
}
library(tidyverse)

# Dateinamen definieren 
# WICHTIG: Die Namen müssen exakt mit deinen Dateien im Ordner übereinstimmen!
file_exp1 <- "bankrun6 degree_vs_lethality-table.csv"
file_exp2 <- "bankrun6 event_study-table.csv"

# ==============================================================================
# EXPERIMENT 1: Final-State (Grafiken 1, 2 und 3)
# ==============================================================================
message("\n--- Lade Daten für Experiment 1 ---")

if (file.exists(file_exp1)) {
  
  # 1. Daten laden und bereinigen
  df_exp1 <- read_csv(file_exp1, skip = 6, show_col_types = FALSE) %>%
    rename(
      run = `[run number]`,
      avg_connections = `avg-connections`,
      reserve_ratio = `reserve-ratio`,
      fund_shock = `fundamental-shock?`,
      lolr_active = `lolr-active?`,
      bank_alive = `bank-alive?`,
      ticks_since_shock = `ticks-since-shock`
    ) %>%
    mutate(
      dead = if_else(bank_alive == "true", 0, 1),
      reserve_ratio_fac = as.factor(reserve_ratio)
    )
  
  # 2. Aggregieren
  df_agg_p <- df_exp1 %>%
    group_by(avg_connections, reserve_ratio_fac, fund_shock, lolr_active) %>%
    summarise(
      n = n(),
      p_lethal = mean(dead),
      se = sd(dead) / sqrt(n),
      ci_low = pmax(0, p_lethal - 1.96 * se), # Deckeln bei 0
      ci_high = pmin(1, p_lethal + 1.96 * se), # Deckeln bei 1
      .groups = "drop"
    )
  
  message("Erstelle Grafiken für Experiment 1...")
  
  # Grafik 1: P(lethal)
  p1 <- ggplot(df_agg_p, aes(x = avg_connections, y = p_lethal, 
                             color = reserve_ratio_fac, fill = reserve_ratio_fac)) +
    geom_line(linewidth = 1) +
    geom_ribbon(aes(ymin = ci_low, ymax = ci_high), alpha = 0.2, color = NA) +
    facet_grid(lolr_active ~ fund_shock, labeller = label_both) +
    scale_y_continuous(labels = scales::percent_format(), limits = c(0, 1)) +
    labs(title = "Grafik 1: P(Lethal) über Konnektivität",
         x = "Konnektivität (avg-connections)", 
         y = "Wahrscheinlichkeit Bankrott",
         color = "Reserve Ratio", fill = "Reserve Ratio") +
    theme_bw()
  print(p1) # Muss in Skripten explizit geprintet werden!
  
  # Grafik 2: Heatmap
  p2 <- ggplot(df_agg_p, aes(x = as.factor(avg_connections), y = reserve_ratio_fac, fill = p_lethal)) +
    geom_tile(color = "white") +
    scale_fill_viridis_c(option = "magma", labels = scales::percent_format()) +
    facet_grid(lolr_active ~ fund_shock, labeller = label_both) +
    labs(title = "Grafik 2: Heatmap der Run-Wahrscheinlichkeit",
         x = "Konnektivität", y = "Reserve Ratio", fill = "P(Lethal)") +
    theme_minimal()
  print(p2)
  
  # Grafik 3: Speed (Zeit-bis-Tod)
  p3 <- df_exp1 %>%
    filter(dead == 1) %>% # Nur die gestorbenen Banken
    ggplot(aes(x = as.factor(avg_connections), y = ticks_since_shock)) +
    geom_boxplot(fill = "steelblue", alpha = 0.5, outlier.shape = 4) +
    facet_grid(lolr_active ~ fund_shock, labeller = label_both) +
    labs(title = "Grafik 3: Ticks bis Insolvenz (nur letale Läufe)",
         x = "Konnektivität", y = "Ticks seit Schock") +
    theme_bw()
  print(p3)
  
} else {
  message("FEHLER: Die Datei '", file_exp1, "' wurde nicht gefunden. Stimmt der Arbeitsordner?")
}

# ==============================================================================
# EXPERIMENT 2: Event-Study (Grafiken 4 und 5)
# ==============================================================================
message("\n--- Lade Daten für Experiment 2 ---")

if (file.exists(file_exp2)) {
  
  max_ticks <- 200 # Fensterende
  
  # 1. Daten laden und bereinigen
  df_exp2 <- read_csv(file_exp2, skip = 6, show_col_types = FALSE) %>%
    rename(
      run = `[run number]`,
      avg_connections = `avg-connections`,
      ticks_since_shock = `ticks-since-shock`,
      liquidity_ratio = `liquidity-ratio`,
      frac_withdrawn = `frac-withdrawn`,
      frac_concerned = `frac-concerned`
    )
  
  # 2. Carry-Forward (Auffüllen der fehlenden Ticks bis max_ticks)
  df_event_complete <- df_exp2 %>%
    group_by(run) %>%
    complete(ticks_since_shock = seq(-1, max_ticks)) %>%
    fill(avg_connections, liquidity_ratio, frac_withdrawn, frac_concerned, .direction = "down") %>%
    ungroup() %>%
    mutate(avg_connections_fac = as.factor(avg_connections))
  
  # 3. Aggregieren (Median und Perzentile)
  df_event_agg <- df_event_complete %>%
    filter(ticks_since_shock >= -1) %>%
    group_by(ticks_since_shock, avg_connections_fac) %>%
    summarise(
      w_med = median(frac_withdrawn, na.rm = TRUE),
      w_p10 = quantile(frac_withdrawn, 0.1, na.rm = TRUE),
      w_p90 = quantile(frac_withdrawn, 0.9, na.rm = TRUE),
      .groups = "drop"
    )
  
  message("Erstelle Grafiken für Experiment 2...")
  
  # Grafik 5: Event Study
  p5 <- ggplot(df_event_agg, aes(x = ticks_since_shock, color = avg_connections_fac, fill = avg_connections_fac)) +
    geom_line(aes(y = w_med), linewidth = 1) +
    geom_ribbon(aes(ymin = w_p10, ymax = w_p90), alpha = 0.2, color = NA) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "black") +
    labs(title = "Grafik 5: Event-Study (Abgehobene Einlagen)",
         subtitle = "Linie = Median, Band = 10.-90. Perzentil",
         x = "Ticks seit Schock", y = "Anteil abgehobener Einlagen",
         color = "Konnektivität", fill = "Konnektivität") +
    theme_bw() +
    theme(legend.position = "bottom")
  print(p5)
  
  # Grafik 4: Mechanismus-Illustration (Nimmt Lauf Nr. 4 als Beispiel)
  p4 <- df_event_complete %>%
    filter(run == 4) %>%
    select(ticks_since_shock, liquidity_ratio, frac_withdrawn, frac_concerned) %>%
    pivot_longer(cols = -ticks_since_shock, names_to = "Variable", values_to = "Wert") %>%
    ggplot(aes(x = ticks_since_shock, y = Wert, color = Variable)) +
    geom_line(linewidth = 1) +
    geom_vline(xintercept = 0, linetype = "dashed", color = "black") +
    labs(title = "Grafik 4: Mechanismus-Illustration (Exemplarischer Lauf Nr. 4)",
         x = "Ticks seit Schock", y = "Wert") +
    theme_bw()
  print(p4)
  
  message("\nErfolg! Alle Plots wurden generiert.")
  message("Tipp: Klicke in RStudio unten rechts im 'Plots'-Reiter auf den blauen Zurück-Pfeil, um durch alle 5 Grafiken zu scrollen.")
  
} else {
  message("FEHLER: Die Datei '", file_exp2, "' wurde nicht gefunden. Stimmt der Arbeitsordner?")
}