# ============================================================================
# Bankrun-ABM — Analysis of the BehaviorSpace results
# Research question: Effect of node connectedness (avg-connections)
#                     on the probability of a lethal bank run.
#
# Expects two CSVs in the working directory (BehaviorSpace "table" format):
#   bankrun6 degree_vs_lethality-table.csv   (final state, one row per run)
#   bankrun6 event_study-table.csv           (every-step, time series)
#
# BehaviorSpace tables have 6 header rows -> skip = 6.
# ============================================================================

library(tidyverse)   # dplyr, tidyr, ggplot2, readr

setwd("C:/Users/timha/Desktop/NetLogo")   # adjust as needed
theme_set(theme_bw(base_size = 11))

# ---- Helper: Wilson confidence interval for a Bernoulli rate ---------------
# (cleaner than Wald when p is near 0/1; k = number of deaths, n = number of runs)
# Vectorized -> can be used directly inside mutate().
wilson_lo <- function(k, n, z = 1.96) {
  p <- k / n; den <- 1 + z^2 / n
  centre <- (p + z^2 / (2 * n)) / den
  halfw  <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / den
  pmax(0, centre - halfw)
}
wilson_hi <- function(k, n, z = 1.96) {
  p <- k / n; den <- 1 + z^2 / n
  centre <- (p + z^2 / (2 * n)) / den
  halfw  <- z * sqrt(p * (1 - p) / n + z^2 / (4 * n^2)) / den
  pmin(1, centre + halfw)
}

# ============================================================================
# 1) FINAL-STATE DATA  (degree_vs_lethality)
# ============================================================================
deg_raw <- read.csv("bankrun6 degree_vs_lethality-table.csv",
                    skip = 6, check.names = FALSE, stringsAsFactors = FALSE)

deg <- deg_raw |>
  transmute(
    degree  = as.integer(`avg-connections`),
    reserve = as.numeric(`reserve-ratio`),
    fund    = `fundamental-shock?` == "true",
    lolr    = `lolr-active?` == "true",
    dead    = `bank-alive?` == "false",
    ttd     = as.numeric(`ticks-since-shock`),   # for dead runs = time of death, otherwise horizon
    peak    = as.numeric(`peak-withdrawn`)
  ) |>
  mutate(
    fund_lab    = factor(ifelse(fund, "Fundamental Shock", "Perception Shock"),
                         levels = c("Perception Shock", "Fundamental Shock")),
    lolr_lab    = factor(ifelse(lolr, "LoLR on", "LoLR off"),
                         levels = c("LoLR off", "LoLR on")),
    reserve_lab = factor(paste0("Reserve = ", reserve))
  )

# --- Cell aggregate: P(lethal) per parameter cell + Wilson CI --------------
agg <- deg |>
  group_by(degree, reserve, fund, lolr, fund_lab, lolr_lab, reserve_lab) |>
  summarise(k = sum(dead), n = n(), p = k / n, .groups = "drop") |>
  mutate(lo = wilson_lo(k, n), hi = wilson_hi(k, n))

# ----------------------------------------------------------------------------
# FIGURE 1 — Main result: P(lethal) across connectivity
#   x = degree, color = LoLR, facets = shock type (row) x reserve (column)
# ----------------------------------------------------------------------------
g1 <- ggplot(agg, aes(degree, p, color = lolr_lab, fill = lolr_lab)) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.18, color = NA) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 1.1) +
  facet_grid(fund_lab ~ reserve_lab) +
  scale_color_manual(values = c("LoLR off" = "#c0392b", "LoLR on" = "#2471a3")) +
  scale_fill_manual(values  = c("LoLR off" = "#c0392b", "LoLR on" = "#2471a3")) +
  scale_y_continuous(limits = c(0, 1)) +
  labs(x = "Avg. connections per node (avg-connections)",
       y = "P(lethal bank run)",
       color = NULL, fill = NULL,
       title = "Connectivity and Lethality of a Bank Run",
       subtitle = "Bands = 95% Wilson CI across replications") +
  theme(legend.position = "top")
ggsave("fig1_p_lethal_vs_degree.png", g1, width = 9, height = 5.5, dpi = 200)

# ----------------------------------------------------------------------------
# FIGURE 1b — Fundamental shock, zoomed to degree 2-6
#   The fundamental shock only produces a cliff at very low degree and is
#   flat at 0 from degree ~5 onward (the direct liquidity drain gets averaged
#   away at high connectivity). This row looks empty in the main figure;
#   zoomed in separately here, the sharp cliff becomes readable.
# ----------------------------------------------------------------------------
g1b <- agg |>
  filter(fund, degree <= 6) |>
  ggplot(aes(degree, p, color = lolr_lab, fill = lolr_lab)) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.18, color = NA) +
  geom_line(linewidth = 0.7) +
  geom_point(size = 1.4) +
  facet_wrap(~ reserve_lab) +
  scale_color_manual(values = c("LoLR off" = "#c0392b", "LoLR on" = "#2471a3")) +
  scale_fill_manual(values  = c("LoLR off" = "#c0392b", "LoLR on" = "#2471a3")) +
  scale_x_continuous(breaks = 2:6) +
  scale_y_continuous(limits = c(0, 1)) +
  labs(x = "Avg. connections per node (avg-connections)",
       y = "P(lethal bank run)", color = NULL, fill = NULL,
       title = "Fundamental Shock: Sharp Cliff at Low Connectivity",
       subtitle = "Zoom on degree 2-6 (from degree ~5 the shock no longer propagates)") +
  theme(legend.position = "top")
ggsave("fig1b_fundamental_zoom.png", g1b, width = 8, height = 3.6, dpi = 200)

# ----------------------------------------------------------------------------
# FIGURE 2 — Heatmap: the danger zone
#   x = degree, y = reserve, color = P(lethal); facets = shock type x LoLR
# ----------------------------------------------------------------------------
g2 <- ggplot(agg, aes(factor(degree), factor(reserve), fill = p)) +
  geom_tile() +
  geom_text(aes(label = sprintf("%.2f", p)), size = 2.3, color = "grey15") +
  facet_grid(fund_lab ~ lolr_lab) +
  scale_fill_viridis_c(option = "inferno", limits = c(0, 1), direction = 1) +
  labs(x = "avg-connections", y = "Reserve Ratio", fill = "P(lethal)",
       title = "Danger Zone: Lethality across Connectivity x Reserve") +
  theme(panel.grid = element_blank())
ggsave("fig2_heatmap.png", g2, width = 9, height = 5.5, dpi = 200)

# ----------------------------------------------------------------------------
# FIGURE 3 — Histogram of death times (lethal runs only)
#   Key message: deaths are NOT a slow cascade but an almost instant threshold
#   ignition. The perception shock kills mostly at t=1, the fundamental shock
#   slightly delayed (only takes effect via the bank signal).
#   Hence a histogram rather than a "speed" boxplot.
# ----------------------------------------------------------------------------
ttd_med <- deg |>
  filter(dead) |>
  group_by(fund_lab) |>
  summarise(med = median(ttd), .groups = "drop")

g3 <- deg |>
  filter(dead) |>
  ggplot(aes(ttd, fill = fund_lab)) +
  geom_histogram(binwidth = 1, boundary = 0.5, color = "white", linewidth = 0.2) +
  geom_vline(data = ttd_med, aes(xintercept = med), linetype = 2, color = "grey30") +
  geom_text(data = ttd_med, aes(x = med, y = Inf, label = paste0("Median = ", med)),
            hjust = -0.1, vjust = 1.6, size = 3, color = "grey30", inherit.aes = FALSE) +
  facet_wrap(~ fund_lab, scales = "free_y") +
  scale_fill_manual(values = c("Perception Shock" = "#e67e22",
                               "Fundamental Shock" = "#8e44ad"), guide = "none") +
  coord_cartesian(xlim = c(0, 15)) +
  labs(x = "Ticks until bankruptcy (ticks-since-shock)", y = "Number of lethal runs",
       title = "Time to Death: Threshold Ignition, No Slow Cascade",
       subtitle = "all reserve & LoLR levels pooled; lethal runs only")
ggsave("fig3_death_time_hist.png", g3, width = 9, height = 4, dpi = 200)

# ============================================================================
# 2) EVENT-STUDY DATA  (time series)
# ============================================================================
ev_raw <- read.csv("bankrun6 event_study-table.csv",
                   skip = 6, check.names = FALSE, stringsAsFactors = FALSE)

ev <- ev_raw |>
  transmute(
    run    = `[run number]`,
    degree = as.integer(`avg-connections`),
    t      = as.numeric(`ticks-since-shock`),
    liq    = as.numeric(`liquidity-ratio`),
    fw     = as.numeric(`frac-withdrawn`),
    fc     = as.numeric(`frac-concerned`),
    alive  = `bank-alive?` == "true"
  ) |>
  filter(t >= 0, t <= 60)                # everything before the shock is at t=-1 -> drop; zoom window

deg_levels <- sort(unique(ev$degree))
pal <- setNames(c("#c0392b", "#e67e22", "#2471a3")[seq_along(deg_levels)], deg_levels)

# --- Percentile bands (median + 10/90) per variable x degree x tick --------
# IMPORTANT: median/percentiles instead of mean, because the outcomes are
# bimodal (shock fizzles out OR escalates). Dead runs are already advanced
# in the model (go-event freezes the terminal state -> carry-forward).
var_labels <- c(fw = "frac-withdrawn", fc = "frac-concerned", liq = "liquidity-ratio")

bands <- ev |>
  pivot_longer(c(fw, fc, liq), names_to = "var", values_to = "val") |>
  group_by(var, degree, t) |>
  summarise(med = median(val),
            lo  = quantile(val, 0.10),
            hi  = quantile(val, 0.90), .groups = "drop") |>
  mutate(var = factor(var, levels = c("fw", "fc", "liq"), labels = var_labels[c("fw","fc","liq")]))

# ----------------------------------------------------------------------------
# FIGURE 4/5 — Event study / impulse response
#   one panel per variable (free y-axis), color = connectivity level
# ----------------------------------------------------------------------------
g5 <- ggplot(bands, aes(t, med, color = factor(degree), fill = factor(degree))) +
  geom_ribbon(aes(ymin = lo, ymax = hi), alpha = 0.15, color = NA) +
  geom_line(linewidth = 0.7) +
  geom_vline(xintercept = 0, linetype = 3, color = "grey40") +
  facet_wrap(~ var, ncol = 1, scales = "free_y") +
  scale_color_manual(values = pal) + scale_fill_manual(values = pal) +
  labs(x = "Ticks since shock (t = 0)", y = NULL,
       color = "avg-connections", fill = "avg-connections",
       title = "Event Study: Shock Propagation by Connectivity",
       subtitle = "Line = median, band = 10th-90th percentile across runs") +
  theme(legend.position = "top")
ggsave("fig5_event_study.png", g5, width = 7.5, height = 8, dpi = 200)

# --- Companion curve n(t): how many runs are still alive (vs. survivorship) -
surv <- ev |>
  group_by(degree, t) |>
  summarise(n_alive = sum(alive), n = n(), .groups = "drop")

g5b <- ggplot(surv, aes(t, n_alive, color = factor(degree))) +
  geom_step(linewidth = 0.7) +
  scale_color_manual(values = pal) +
  labs(x = "Ticks since shock", y = "Surviving runs  n(t)",
       color = "avg-connections",
       title = "Survivor Curve n(t) — Context for the Event Study")
ggsave("fig5b_survivors.png", g5b, width = 7.5, height = 3.2, dpi = 200)

message("Done. PNGs written: fig1..fig5b in the working directory.")

# ============================================================================
# 3) REGRESSION — Formal test of the connectivity effect
# ============================================================================
# NOTE ON SPECIFICATION:
# The aggregated proportion prop_lethal is NOT a good outcome for plain OLS:
#   - it is bounded in [0,1] (linear model can predict outside that range)
#   - it is heteroskedastic by construction (variance depends on n per cell)
#   - the true relationship is non-linear (cf. Fig 1/1b: a sharp cliff for
#     the fundamental shock vs. a smooth gradient for the perception shock)
# We therefore fit a logistic regression (binomial GLM) on the RAW run-level
# binary outcome `dead`, not on the aggregated cell proportions. This uses
# every individual run as one Bernoulli observation instead of throwing away
# information through aggregation.

library(broom)

# --- (a) naive linear probability model, kept only as a comparison point ---
lpm <- lm(dead ~ degree + reserve + fund_lab + lolr_lab, data = deg)
summary(lpm)

# --- (b) logistic regression, main specification ---------------------------
# interaction degree:fund_lab tests whether connectivity's effect differs
# between shock types (expected: much stronger for the fundamental shock,
# consistent with the "cliff vs. gradient" pattern in Fig 1b / Fig 2)
logit_full <- glm(dead ~ degree * fund_lab + reserve + lolr_lab,
                   data = deg, family = binomial(link = "logit"))
summary(logit_full)

# --- (c) does a non-linear (quadratic) term in degree improve the fit? -----
# likelihood-ratio test + AIC comparison; if the quadratic term is not a
# clear improvement, the interaction term alone already captures most of
# the shock-type-specific curvature and a simpler model can be reported.
logit_quad <- glm(dead ~ poly(degree, 2) * fund_lab + reserve + lolr_lab,
                   data = deg, family = binomial(link = "logit"))
anova(logit_full, logit_quad, test = "Chisq")
AIC(logit_full, logit_quad)

# --- (d) tidy coefficient table (odds ratios) for slides / appendix --------
logit_tab <- tidy(logit_full, exponentiate = TRUE, conf.int = TRUE) |>
  mutate(across(where(is.numeric), ~round(.x, 3)))
print(logit_tab)
write.csv(logit_tab, "table_logit_coefficients.csv", row.names = FALSE)

# --- (e) predicted-probability plot: marginal effect of connectivity -------
pred_grid <- expand.grid(
  degree   = seq(2, 20, by = 1),
  reserve  = median(deg$reserve),
  fund_lab = levels(deg$fund_lab),
  lolr_lab = levels(deg$lolr_lab)
)
pred_grid$fit <- predict(logit_full, newdata = pred_grid, type = "response")

g6 <- ggplot(pred_grid, aes(degree, fit, color = lolr_lab)) +
  geom_line(linewidth = 0.8) +
  facet_wrap(~ fund_lab) +
  scale_color_manual(values = c("LoLR off" = "#c0392b", "LoLR on" = "#2471a3")) +
  labs(x = "Avg. connections per node (avg-connections)",
       y = "Predicted P(lethal bank run)",
       color = NULL,
       title = "Logistic Regression: Predicted Effect of Connectivity",
       subtitle = "Reserve held at sample median; shaded by shock type and LoLR status") +
  theme(legend.position = "top")
ggsave("fig6_logit_predicted.png", g6, width = 8, height = 4, dpi = 200)

message("Regression done. Coefficient table: table_logit_coefficients.csv, plot: fig6_logit_predicted.png")
