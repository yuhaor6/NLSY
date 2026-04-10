# Research Proceeding Plan
## Adapting Sztutman's Dynamic Job Market Signaling Framework to NLSY79

**Project:** Labor Signaling — NLSY79 Empirical Adaptation
**Advisor:** Prof. André Sztutman
**Reference:** Sztutman (2024), "Dynamic Job Market Signaling and Optimal Taxation"
**Last updated:** 2026-04-10

---

## Strategic Framing

This is **not a replication** — it is an extension with genuinely novel empirical content. NLSY79 enables things Sztutman's HRS-based paper cannot do:

| Dimension | HRS (Sztutman) | NLSY79 (This project) | Advantage |
|---|---|---|---|
| Age coverage | 50–70+ (late career only) | 14–65 (full career arc) | **NLSY**: Estimate dynamic χ(h) over full career |
| Ability proxy | Cognitive battery, mid/late career | AFQT (1980), pre-market | **NLSY**: Exogeneity cleaner — no reverse causation |
| Resume proxy | Late-career cumulative hours | `cumhrs` from career start | **NLSY**: Directly maps to model's I = ∫qh̃dã |
| Tax reforms | ERTA, TRA mainly | ERTA, TRA, EGTRRA, JGTRRA, TCJA | **NLSY**: 5 reforms, 40-year panel |
| Sector heterogeneity | Limited | occ×ind (1979–1993) | **NLSY**: Novel sector-specific signaling tests |

**Key original contribution:** NLSY79 allows estimating the *dynamic* labor wedge profile χ(h) from early to late career, directly testing whether the Pigouvian tax correction is history-dependent (general model) or constant (Pareto special case). HRS cannot do this because it only observes workers after their resume is largely fixed.

---

## Core Theoretical Objects to Estimate

### Object 1 — Structural Return to Resume Strength

Under Sztutman's length-of-resume model with Pareto productivity distribution:

```
log(w_it) = α_i + γ · log(cumhrs_it) + β · X_it + ε_it
```

where **γ = δ / (1 − δ + ε)**, with:
- δ = degree of information asymmetry ∈ [0,1]
- ε = labor supply elasticity (proxied by ETI from Two_Period_Analysis.do)
- γ **constant** across career stages ⟺ Pareto case (constant Pigouvian tax)
- γ **declining** with career stage ⟺ general model (history-dependent correction)

**Recovery of δ** (correct formula, rearranging γ = δ/(1−δ+ε)):

```
δ = γ(1 + ε) / (1 + γ)
```

Note: NOT γ(1+ε)/(1+γ(1+ε)) — that is a common misstatement of this formula.

### Object 2 — Labor Wedge

Core Sztutman sufficient statistic:

```
χ(y) = 1 + ε^w_r / η^P_r
```

where:
- ε^w_r = wage elasticity w.r.t. net-of-tax rate r = 1−τ (intensive margin)
- η^P_r = participation semi-elasticity w.r.t. r (extensive margin)
- χ < 1 ⟺ workers paid more than marginal product ⟺ positive signaling externality

**Optimal Pigouvian correction:**

```
τ_p(y) = 1 − χ(y)
```

**Pareto special case (constant, history-independent):**

```
τ_p = δ / α    where α = Pareto tail parameter of income distribution
```

### Object 3 — Advantageous Selection (Empirical Signature)

```
E[AFQT | ΔParticipation > 0, tax-cut reform] > E[AFQT | ΔP = 0]
E[AFQT | ΔParticipation < 0, tax-hike reform] < E[AFQT | ΔP = 0]
```

Workers who enter the labor market when taxes fall should be higher-ability than the existing pool. This is the direct empirical test that information asymmetry — not just standard labor supply response — drives the wedge.

---

## Do Files: Execution Order and Deliverables

Run in this order: **Phase 1 → Phase 3 → Phase 2 → Phase 4 → Phase 5**

### Phase 1 — `Structural_Wage_Experience.do`

**Status:** Code complete, not yet run
**Input:** `data/nlsy_long_pre_taxsim.dta`
**Outputs:**
- `output/Phase1_Table1_GammaByStage.rtf` — γ by career quintile (FE)
- `output/Phase1_Table2_OLSvsFE.rtf` — selection decomposition
- `output/Phase1_Table3_Structural.csv` — δ and structural parameters
- `output/Phase1_Fig1_GammaProfile.png` — γ profile with 95% CIs
- `output/Phase1_Fig2_SelectionDecomp.png` — OLS vs FE by career stage
- `output/Structural_Wage_Experience_log.txt`

**What it does:**

1. **γ by career quintile (FE):** Divides workers into 5 experience quintiles and estimates the within-person elasticity of wages to cumulative hours at each career stage. The Wald test of equality (γ_Q1 = ... = γ_Q5) is the key test of the Pareto case.

2. **OLS vs FE decomposition:** The gap γ_OLS − γ_FE identifies between-person selection (high-ability workers work more) vs. within-person accumulation. Large gap → signaling selection dominates. Also splits the OLS-FE gap into observable (absorbed by AFQT) and unobservable components.

3. **Structural δ recovery:** Computes δ = γ_FE(1+ε)/(1+γ_FE) for the range of ETI estimates from Two_Period_Analysis.do. Outputs a sensitivity table over ε ∈ [0.2, 0.8].

4. **Recent vs. cumulative hours horse race by career stage:** Tests whether "face time" (recent hours) matters more early in career (signaling) vs. cumulative accumulation (learning-by-doing).

5. **Built-in scrutiny:** Flags if γ_FE ≤ 0, γ_OLS < γ_FE, δ ∉ (0,1), or γ is non-monotone across stages. The closing section gives a direct steering recommendation for Phase 2 (Pareto vs. dynamic model).

**Key test:**
- Wald test p < 0.05 → reject constant γ → use history-dependent χ(h) in Phase 2
- Wald test p ≥ 0.10 → fail to reject → Pareto constant τ_p = δ/α is appropriate

---

### Phase 3 — `Advantageous_Selection_Test.do`

**Status:** Code complete, not yet run
**Input:** `data/nlsy_long_pre_taxsim.dta`, `data/analysis_annual.dta`, `data/BLS_CPI.dta`
**Outputs:**
- `output/Phase3_Fig1_AFQTbyGroup.png` — AFQT densities by participation type (ERTA exhibit)
- `output/Advantageous_Selection_log.txt`

**Reform event windows used:**

| Reform | Pre year | Post year | Type |
|---|---|---|---|
| ERTA 1981 | 1980 | 1982 | Tax cut (all brackets) |
| TRA 1986 | 1985 | 1987 | Mixed (top cut, bottom raise) |
| EGTRRA 2001 | 2000 | 2002 | Tax cut |
| JGTRRA 2003 | 2002 | 2004 | Tax cut (dividends/cap gains) |
| TCJA 2017 | 2016 | 2018 | Tax cut |

**What it does:**

1. **Participation classification:** For each reform pair, classifies each person as Entrant / Stayer / Exiter / Non-participant using real wages ≥ $1,000 (1984 dollars) as the participation threshold.

2. **AFQT comparison:** t-test and OLS regression of AFQT on participation-type dummies. Primary test: Entrant mean AFQT > Stayer mean AFQT at tax-cut reforms.

3. **Age/cohort controls (critical for NLSY):** NLSY respondents are only 17–25 at ERTA 1982. Many "entrants" are natural first-time labor market participants, not reform-induced entrants. The regression controls for pre-reform age to isolate reform-driven selection.

4. **Placebo test:** Runs the identical classification for non-reform years (1983, 1988, 2006, 2012). Should find no systematic AFQT-participation correlation. If placebo effects are as large as main effects, identification is confounded.

5. **AFQT × NTR interaction (most demanding test):** Merges `analysis_annual.dta` and tests whether high-AFQT workers respond more on the intensive margin to tax changes (β(AFQT × ΔlogNTR) > 0). Also estimates ETI separately by AFQT quartile.

**Scrutiny checkpoints:**
- ERTA 1982 should have the largest entrant cell (prime entry-age cohort)
- Biennial reform cells (2002, 2004, 2018) will be smaller — pool if needed
- Placebo F-stats should be near zero; main reform t-stats should be positive and significant
- A gap of ≥ 3 AFQT percentile points between entrants and stayers is economically meaningful

---

### Phase 2 — `Labor_Wedge_Estimation.do`

**Status:** Code complete — PRELIMINARY until TAXSIM expansion (see Critical Path)
**Input:** `data/analysis_annual.dta`, `data/analysis_biennial.dta`, `data/nlsy_long_pre_taxsim.dta`, `data/BLS_CPI.dta`
**Outputs:**
- `output/Phase2_Table3_Elasticities.rtf` — ε^w_r by period
- `output/Phase2_Table4_Pigouvian.csv` — preliminary τ_p by decile
- `output/Phase2_Fig1_EpsWProfile.png` — ε^w_r by income decile
- `output/Phase2_Fig2_DynamicEps.png` — ε^w_r by career stage, both periods
- `output/Labor_Wedge_log.txt`

**What it does:**

1. **ε^w_r by income decile (annual period, 1978–1993):** 2SLS of log income change on log NTR change, using Gruber-Saez simulated MTR instrument. Estimated for each of 10 income deciles and each of 4 age quartiles. First-stage F-stat reported and checked (must exceed 10).

2. **ε^w_r biennial period (1995–2019):** Same procedure on `analysis_biennial.dta`. The comparison of annual vs. biennial ε^w_r by career stage is the NLSY's unique contribution: full dynamic elasticity profile from ages ~17 to ~62.

3. **η^P_r (reduced-form, preliminary):** Estimates the participation response to ERTA/TRA reforms using the full long panel. Classifies participation change around reform years and regresses on reform dummies by income group. Note: this is a reduced-form approximation — the full IV requires TAXSIM on near-workers (see Critical Path).

4. **χ = 1 + ε^w_r / η^P_r:** Combines the intensive wage elasticity with the participation elasticity approximation. Reports χ(y) by income decile and flags clearly when the approximation is insufficient.

5. **Dynamic wedge profile:** Plots ε^w_r against career stage for both periods together — the first evidence on the full career-arc dynamic elasticity profile.

**KNOWN LIMITATION:** Full χ(y) requires IV estimation of η^P_r using TAXSIM on near-workers (real income $1K–$10K). This requires expanding the Two_Period_Analysis.do sample and re-running TAXSIM. Until then, χ estimates are directional only.

---

### Phase 4 — `Sector_Heterogeneity_Analysis.do`

**Status:** Code complete, not yet run
**Input:** `data/eda_deepdive_data.dta` (from EDA_DeepDive_OccInd.do)
**Outputs:**
- `output/Phase4_Table1_GammaByOcc.rtf` — γ by occupation (9 categories)
- `output/Phase4_Table2_GammaByInd.rtf` — γ by industry (12 categories)
- `output/Phase4_Table3_AltonjiPierretBySector.rtf` — AP slopes by signal group
- `output/Phase4_Table4_SignalingRanking.csv` — full ranking table
- `output/Phase4_Fig1_GammaRanking.png` — γ ranked by occupation
- `output/Phase4_Fig2_APRanking.png` — employer learning slope ranked by occupation
- `output/Sector_Heterogeneity_log.txt`

**Data restriction:** 1979–1993 only (occ/ind available in NLSY79 for this window only).

**A priori signaling classification:**

| Category | High signaling | Low signaling |
|---|---|---|
| Occupation | Professional (1), Managers (2) | Laborers (7), Farm Workers (8) |
| Industry | Finance (7), Business Svcs (8), Prof Svcs (11) | Agriculture (1), Manufacturing (4) |

**What it does:**

1. **γ by occupation and industry (FE):** Estimates within-person return to cumhrs for each of 9 occupations and 12 industries. Minimum 200 obs threshold before estimating. Checks whether high-signaling sectors have statistically larger γ than low-signaling sectors.

2. **Altonji-Pierret test by sector (OLS, not FE):** AFQT × Experience interaction slope by sector. OLS required because AFQT is time-invariant and would be absorbed by FE. Tests whether employer learning is faster in high-signaling occupations (larger AP slope in Professional/Managerial vs. Laborers/Farm).

3. **Aggregated High/Medium/Low comparison:** Pools occupations and industries into three signaling-intensity groups and estimates both γ and AP slopes. Cleaner power than cell-by-cell estimates.

4. **Joint ranking:** Full sector ranking by γ AND AP slope. Sectors with both high γ and high AP slope are the strongest evidence for sector-specific signaling externalities.

**Novel contribution:** This analysis is not in Sztutman's HRS paper. The key prediction for the paper: sectors with high employer uncertainty (professional services, finance) should have both higher returns to cumulative hours AND stronger employer learning patterns.

---

### Phase 5 — `Pigouvian_Tax_Quantification.do`

**Status:** Code complete — PRELIMINARY (depends on clean Phase 1 and Phase 2)
**Input:** `output/Phase1_Table3_Structural.csv`, `output/Phase2_Table4_Pigouvian.csv`, `output/two_period_summary.dta`, `data/analysis_annual.dta`
**Outputs:**
- `output/Phase5_Table3_Summary.csv` — main τ_p estimates table
- `output/Phase5_Fig1_TauProfile.png` — τ_p with uncertainty ranges
- `output/Pigouvian_Tax_log.txt`

**What it does:**

1. **Load cross-phase estimates:** Collects γ_FE and δ from Phase 1, ETI from Two_Period_Analysis, ε^w_r and χ from Phase 2. Validates that all inputs are present before proceeding.

2. **Pareto tail α from income distribution:** Log-rank regression on top 20% of income in `analysis_annual.dta`. Checks R² and whether α ∈ [1, 5] (typical US range). Issues a warning if the Pareto assumption fits poorly.

3. **τ_p computation (Method A — Pareto structural):** τ_p = δ/α. Sensitivity table over δ ∈ [0.05, 0.30] and α ∈ [1.5, 3.0].

4. **τ_p computation (Method B — direct from χ):** τ_p(y) = 1 − χ(y) per income decile. Preliminary until full η^P_r from Phase 2.

5. **Dynamic τ_p by career stage:** Uses career-stage γ values from Phase 1 log to compute τ_p for each career quintile. The g1–g5 scalars at the top of the file must be updated with actual Phase 1 results before this section is meaningful.

6. **Cross-phase consistency check (critical):**
   - δ_1 = γ_FE(1+ε)/(1+γ_FE) from Phase 1
   - δ_2 = τ_p × α from Phase 2 + Pareto
   - If |δ_1 − δ_2| > 0.05: model is internally inconsistent — diagnose before citing
   - Consistency confirms that the structural approach and reduced-form approach tell the same story

7. **Research readiness checklist:** Lists what is needed for submission (see below).

---

## File Roadmap and Dependencies

```
Data_process.do
    └──→ nlsy_long_pre_taxsim.dta
              ├──→ Structural_Wage_Experience.do      [Phase 1]  ← RUN FIRST
              │         ↓ γ(career stage), δ_implied
              │         ↓ Steering: Pareto or general model
              │
              ├──→ Advantageous_Selection_Test.do     [Phase 3]  ← RUN SECOND
              │         ↓ AFQT selection at reform years
              │         ↓ ETI by AFQT quartile
              │
              └──→ Two_Period_Analysis.do
                        ├──→ analysis_annual.dta
                        │         └──→ Labor_Wedge_Estimation.do  [Phase 2]  ← RUN THIRD
                        │                   ↓ ε^w_r by decile and career stage
                        │                   ↓ χ(y) preliminary
                        └──→ analysis_biennial.dta
                                  └──→ (same, Phase 2 biennial section)

merged_data_with_occind.dta
    └──→ EDA_DeepDive_OccInd.do
              └──→ eda_deepdive_data.dta
                        └──→ Sector_Heterogeneity_Analysis.do  [Phase 4]  ← RUN FOURTH
                                  ↓ γ and AP slopes by occ/ind

All Phase 1-4 outputs
    └──→ Pigouvian_Tax_Quantification.do  [Phase 5]  ← RUN LAST
              ↓ τ_p = δ/α profile
              ↓ Cross-phase consistency check
```

---

## Critical Path

**The single blocker before Phase 2 is fully estimable:**

> Expand `Two_Period_Analysis.do` to include **near-workers** (real income $1,000–$10,000 in 1984 dollars) and re-run TAXSIM on that sample. This enables full IV estimation of η^P_r = ∂P/∂log(r), which is required for precise χ(y) = 1 + ε^w_r / η^P_r.

Until this is done, Phase 2 reports ε^w_r precisely but χ only approximately. The current near-worker approximation uses ERTA/TRA reform dummies as a reduced-form instrument, which gives the correct sign and rough magnitude but not a valid IV estimate.

**What the expansion requires:**
1. In `Two_Period_Analysis.do`, change the real income floor from `$real_floor = 10000` to `$real_floor = 1000` (or add a separate near-worker sample alongside the main sample)
2. Re-run `taxsimlocal35` on the expanded paired dataset
3. Construct `log_ntr_instrument` for near-workers using the same simulated-MTR approach
4. Merge with the main sample and estimate η^P_r by LPM

This is a medium-run data task (~1–2 hours of compute for TAXSIM re-run).

---

## Variable Reference (NLSY79-specific)

| Concept | Variable name | Notes |
|---|---|---|
| Log wages | `log_pwages` | = ln(pwages) if pwages > 0 |
| AFQT (best available) | `afqt` | 2006-revised, then 1989, then 1980 |
| AFQT standardized | `afqt_std` | Mean 0, SD 1 — used in regressions |
| AFQT percentile 1980 | `afqt_pct_1980` | Pre-market; cleanest for exogeneity |
| AFQT quartile | `afqt_quartile` | 1=lowest, 4=highest |
| Potential experience | `pot_exp` | = page − hgc − 6, floored at 0 |
| Experience squared | `pot_exp2` | = pot_exp^2 |
| Cumulative hours | `cumhrs` | Interpolated for biennial gaps |
| Log cumulative hours | `log_cumhrs` | Created inline: ln(cumhrs) if cumhrs > 0 |
| Net-of-tax rate change | `log_ntr_change` | In analysis_annual/biennial.dta |
| Simulated MTR instrument | `log_ntr_instrument` | In analysis_annual/biennial.dta |

---

## Identification Concerns and Robustness Checks

| Concern | Solution | Where |
|---|---|---|
| Endogenous cumhrs (hours and wages both move with shocks) | FE removes time-invariant selection; use lagged cumhrs as robustness IV | Phase 1 |
| Life-cycle confound (age ≠ experience) | Separate flexible age polynomials from pot_exp; compare AP slope pattern | Phase 1 |
| Weak IV for NTR change | Verify F-stat > 10; restrict to pure reform windows (ERTA, TCJA only) if weak | Phase 2 |
| Extensive/intensive margin conflation in η^P_r | Strict participation threshold ($1,000 real wages); robustness at $500 and $2,000 | Phase 2 |
| NLSY respondents young at ERTA 1982 | Age controls in Phase 3; compare within-cohort | Phase 3 |
| AFQT reverse causation | AFQT taken 1980, before all reforms — use `afqt_pct_1980` as cleaner proxy | Phase 3 |
| NLSY attrition (survey thins post-2000) | Check AFQT/wages of attritors vs. survivors; IPW robustness for Phase 2 biennial | Phase 3 |
| Small cells in occ/ind | Pool to High/Medium/Low signaling groups if cell N < 200 | Phase 4 |
| Pareto tail misfit | Check R² of log-rank regression; use non-parametric τ_p(y) as alternative | Phase 5 |
| ETI ≠ labor supply ε | ETI includes avoidance; use intensive-margin-only ETI as robustness | Phase 5 |

---

## Theoretical Predictions vs. Empirical Findings Matrix

Update this table as each phase is run.

| Prediction | Test | Phase | Status | Finding |
|---|---|---|---|---|
| γ > 0 (positive return to cumhrs) | FE on log_cumhrs | 1 | Pending | — |
| γ_OLS > γ_FE (positive selection) | OLS vs FE decomposition | 1 | Pending | — |
| γ constant across career stages (Pareto) | Wald test | 1 | Pending | — |
| γ declining with career stage (dynamic model) | Monotonicity check | 1 | Pending | — |
| δ ∈ (0,1) from structural recovery | δ = γ(1+ε)/(1+γ) | 1 | Pending | — |
| χ < 1 (positive signaling externality) | χ = 1 + ε^w_r/η^P_r | 2 | Pending | — |
| ε^w_r > 0 (wages respond to tax cuts) | 2SLS annual period | 2 | Pending | — |
| F-stat > 10 (valid instrument) | First-stage regression | 2 | Pending | — |
| ε^w_r stable across career stages (Pareto) | ε^w_r by career quartile | 2 | Pending | — |
| Advantageous selection at ERTA 1982 | AFQT entrant > stayer | 3 | Pending | — |
| Advantageous selection at EGTRRA 2002 | AFQT entrant > stayer | 3 | Pending | — |
| Adverse selection at tax hikes (TRA) | AFQT exiter < stayer | 3 | Pending | — |
| Placebo years show no AFQT selection | AFQT test at 1983, 1988, 2006 | 3 | Pending | — |
| High-AFQT workers more tax-responsive | AFQT × ΔlogNTR interaction | 3 | Pending | — |
| Higher γ in Professional/Finance sectors | FE by occ/ind | 4 | Pending | — |
| Stronger AP slope in high-signaling sectors | Altonji-Pierret by sector | 4 | Pending | — |
| Finance γ > Manufacturing γ | Sector comparison | 4 | Pending | — |
| τ_p constant (Pareto case confirmed) | τ_p = δ/α | 5 | Pending | — |
| δ_1 (Phase 1) ≈ δ_2 (Phase 2 + α) | Cross-phase consistency | 5 | Pending | — |

---

## Research Readiness Checklist

### Short-run (can complete without new data work)

- [ ] Run Phase 1 (`Structural_Wage_Experience.do`) and check all scrutiny flags
- [ ] Update Phase 5 `g1–g5` scalars with actual career-stage γ from Phase 1 log
- [ ] Run Phase 3 (`Advantageous_Selection_Test.do`) and verify placebo tests are clean
- [ ] Run Phase 2 (`Labor_Wedge_Estimation.do`) and verify F-stat > 10 in both periods
- [ ] Run Phase 4 (`Sector_Heterogeneity_Analysis.do`) and check cell sizes
- [ ] Run Phase 5 (`Pigouvian_Tax_Quantification.do`) for preliminary τ_p range

### Medium-run (requires data expansion)

- [ ] Expand `Two_Period_Analysis.do` to near-workers (income floor $1K instead of $10K)
- [ ] Re-run TAXSIM on expanded sample
- [ ] Add `log_ntr_instrument` for near-worker sample
- [ ] Estimate full η^P_r by IV in `Labor_Wedge_Estimation.do` Part 3
- [ ] Recompute precise χ(y) and τ_p(y) profiles

### For submission (paper polish)

- [ ] Bootstrap standard errors for τ_p across Phases 1–2
- [ ] Cross-phase consistency check (|δ_1 − δ_2| < 0.05)
- [ ] Comparison table with Sztutman HRS estimates
- [ ] Dynamic τ_p figure comparing young vs. mid vs. late career
- [ ] Sector-specific τ_p if Phase 4 finds significant heterogeneity
- [ ] IPW robustness for NLSY attrition in biennial period

---

## Version Log

| Version | Date | Changes |
|---|---|---|
| 1.0 | 2026-04-10 | Initial plan drafted |
| 1.1 | 2026-04-10 | Full update: correct δ formula (γ(1+ε)/(1+γ)); updated file names and dependencies; added detailed deliverables per phase; added critical path for TAXSIM expansion; added research readiness checklist; corrected Phase 4 file name to Sector_Heterogeneity_Analysis.do; corrected Phase 5 file name to Pigouvian_Tax_Quantification.do; fixed dependency reference from gruber_saez_regression_data.dta → analysis_annual.dta |
