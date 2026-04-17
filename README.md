# NLSY79 Labor Economics Research Project

## Overview

This project analyzes wage dynamics, human capital accumulation, and the elasticity of taxable income (ETI) using NLSY79 panel data (1979–2023). The core question is whether early-career wage growth reflects actual skill formation or the gradual revelation of pre-existing ability to employers — the skill vs. signaling debate. A parallel track estimates optimal Pigouvian taxes on human capital externalities following Sztutman (2024).

**Principal Investigator:** Professor André Sztutman  
**Research Assistant:** Yuhao Ren  
**Institution:** Carnegie Mellon University

---

## Research Questions

1. **Skill vs. Signaling:** Does wage growth track cumulative hours (skill accumulation) or does the return to education erode with experience as employers learn worker quality (Altonji & Pierret 1997)?
2. **Elasticity of Taxable Income (ETI):** How do workers adjust labor income in response to marginal tax rate changes, using major tax reforms (ERTA 1981, TRA 1986, EGTRRA 2001, JGTRRA 2003, TCJA 2017) as natural experiments?
3. **Labor Wedge and Optimal Tax:** What fraction of the wage-experience profile reflects human capital externalities, and what does this imply for the optimal labor tax wedge?
4. **Sector Heterogeneity:** Do returns to experience and signaling differ across occupation × industry cells?

---

## File Structure

```
labor_signaling_project/
│
├── do file/
│   ├── Data_process.do                  # Raw CSV → long-format panel (main pipeline)
│   ├── Structural_Wage_Experience.do    # γ (returns to cumhrs) by career stage; δ recovery
│   ├── Two_Period_Analysis.do           # ETI via IV, annual (3-yr) and biennial (2-yr) periods
│   ├── Advantageous_Selection_Test.do   # AFQT selection tests at each major reform
│   ├── Labor_Wedge_Estimation.do        # χ(y) = 1 + ε^w_r / η^P_r
│   ├── Skill_vs_Signal_Analysis.do      # Altonji-Pierret horse race, variance decomposition
│   ├── Sector_Heterogeneity_Analysis.do # γ and AP slopes by occ × ind cell
│   ├── Pigouvian_Tax_Quantification.do  # τ_p = 1 − χ = δ/α; welfare calculation
│   ├── BSX_Wage_Elasticity.do           # Replication of Benzell-Soltas-Xie (LOO instrument)
│   ├── EDA_Wage_Analysis.do             # Basic exploratory analysis
│   └── EDA_DeepDive_OccInd.do          # Descriptive EDA by occupation × industry
│
├── Raw Data/
│   ├── NLSY_All_Data.csv
│   ├── left_out.csv
│   ├── Occupation_Industry.csv
│   └── demo_x_hour.csv
│
├── Intermediate Data/
│   ├── merged_data.dta                  # Wide format (12,686 persons)
│   ├── merged_data_with_occind.dta      # Wide format + occ_broad/ind_broad
│   └── nlsy_long_pre_taxsim.dta        # Long format (583,556 person-years)
│
├── TAXSIM Output/
│   ├── taxsim_output_annual.dta
│   ├── taxsim_output_biennial.dta
│   └── [counterfactual outputs]
│
├── Analysis Data/
│   ├── analysis_annual.dta
│   ├── analysis_biennial.dta
│   └── cumhrs_returns_by_cell.dta
│
└── Results/
    ├── *.png                            # Figures
    └── *_log.txt                        # Stata logs
```

---

## Data Pipeline

### Stage 1 — Import and Merge (`Data_process.do`)

Four raw CSV files are imported and merged into a single wide-format dataset (`merged_data.dta`, one row per person). Occupation and industry variables are then attached to produce `merged_data_with_occind.dta`.

### Stage 2 — Variable Construction

- Year-specific HGC, potential experience, cumulative hours (with biennial interpolation)
- Broad occupation (9 categories) and industry (12 categories) from 1970 Census codes
- TAXSIM-ready variables: marital status, spouse/child ages, income components

### Stage 3 — Reshape to Long

```
merged_data.dta  →  nlsy_long_pre_taxsim.dta
12,686 persons       583,556 person-years
```

### Stage 4 — TAXSIM

Marginal and average tax rates calculated via TAXSIM35 for actual income and counterfactual income scenarios (reform-year instruments).

### Stage 5 — Analysis

```
nlsy_long_pre_taxsim.dta
    ├── Structural_Wage_Experience.do  →  γ, δ estimates
    ├── Two_Period_Analysis.do         →  ETI (annual + biennial)
    ├── Advantageous_Selection_Test.do →  AFQT selection balance
    ├── Labor_Wedge_Estimation.do      →  χ(y), labor wedge
    ├── Skill_vs_Signal_Analysis.do    →  signaling tests
    ├── Sector_Heterogeneity_Analysis.do → heterogeneity by cell
    └── Pigouvian_Tax_Quantification.do → τ_p, welfare
```

---

## Running the Code

### Requirements

- Stata 17+
- `taxsim35` (`net install taxsim35, from("https://taxsim.nber.org/stata")`)
- `estout` (`ssc install estout`)
- Raw CSV files in working directory
- Internet access (TAXSIM sends data to NBER servers)

### Execution Order

```stata
do "Data_process.do"               // ~30 min; produces nlsy_long_pre_taxsim.dta

do "Structural_Wage_Experience.do" // Phase 1: γ and δ
do "Two_Period_Analysis.do"        // Phase 2: ETI (runs TAXSIM internally)
do "Advantageous_Selection_Test.do"// Phase 3: selection balance
do "Labor_Wedge_Estimation.do"     // Phase 2b: labor wedge
do "Skill_vs_Signal_Analysis.do"   // Phase 1b: signaling tests
do "Sector_Heterogeneity_Analysis.do" // Phase 4: heterogeneity
do "Pigouvian_Tax_Quantification.do"  // Phase 5: welfare (needs Phases 1-2)

do "EDA_Wage_Analysis.do"          // Optional: descriptive stats
do "EDA_DeepDive_OccInd.do"        // Optional: occ × ind EDA
```

**Note:** `merged_data_with_occind.dta` must be saved at the end of `Data_process.do` before running `EDA_DeepDive_OccInd.do`.

---

## Key Variables

| Variable | Description |
|----------|-------------|
| `taxsimid` | Person identifier (NLSY case ID) |
| `year` | Calendar year (1978–2023) |
| `pwages` | Primary wages and salary |
| `page` | Age at midpoint of income year |
| `hgc` | Highest grade completed (year-specific) |
| `pot_exp` | Potential experience: age − education − 6 |
| `cumhrs` | Cumulative hours worked (interpolated for biennial gaps) |
| `afqt_pct_2006` | AFQT percentile, 2006 norming |
| `occ_broad` | Broad occupation (1–9), 1979–1993 only |
| `ind_broad` | Broad industry (1–12), 1979–1993 only |
| `mstat` | Marital status for TAXSIM: 1=Single, 2=MFJ |

---

## Sample Design

| | Annual period | Biennial period |
|--|--|--|
| Income years | 1978–1993 | 1995–2019 (odd years) |
| Age range | 17–35 | 30–65 |
| Wage window | 3-year differences | 2-year differences |
| Income floor | $5,000 (1984$) | $10,000 (1984$) |
| Purpose | Early-career ETI, signaling | Prime-age ETI, labor wedge |

Total panel: 583,556 person-years, 12,686 individuals, 46 calendar years.

---

## Occupation and Industry Codes (1970 Census)

### Broad Occupation (9 categories)
| Code | Category |
|------|----------|
| 1 | Professional/Technical |
| 2 | Managers/Administrators |
| 3 | Sales Workers |
| 4 | Clerical Workers |
| 5 | Craftsmen |
| 6 | Operatives |
| 7 | Laborers |
| 8 | Farm Workers |
| 9 | Service Workers |

### Broad Industry (12 categories)
| Code | Category |
|------|----------|
| 1 | Agriculture/Forestry/Fisheries |
| 2 | Mining |
| 3 | Construction |
| 4 | Manufacturing |
| 5 | Transport/Communication/Utilities |
| 6 | Wholesale/Retail Trade |
| 7 | Finance/Insurance/Real Estate |
| 8 | Business/Repair Services |
| 9 | Personal Services |
| 10 | Entertainment/Recreation |
| 11 | Professional Services |
| 12 | Public Administration |

Occupation and industry codes with consistent 1970 Census classification are available only for 1979–1993.

---

## Data Cleaning Fixes

### Fix #1 — Marital Status Mapping
NLSY code 1 (married, spouse present) → TAXSIM 2 (MFJ). All other codes → TAXSIM 1 (Single). Previous mapping incorrectly sent separated respondents to MFJ.

### Fix #2 — Cumulative Hours Interpolation
Biennial surveys (1994+) skip even-numbered calendar years, causing cumulative hours to plateau. Missing years are filled by averaging adjacent observed values.

### Fix #3 — Education Realignment (Biennial)
For biennial years, education is measured at the interview but wages cover the prior calendar year. HGC variables are lagged one year to match the income reference period.

### Fix #4 — Demographic Realignment
Age and related demographics share the same timing issue as education. Ages in biennial survey years are decremented by one to align with the income year.

### Fix #5 — Year-Specific Potential Experience
Potential experience was originally computed using final (maximum) education. It now uses year-specific HGC: `pot_exp = page − hgc − 6`.

### Fix #6 — Spouse Age Validation
Corrupted date-of-birth records produced spouse ages above 100, crashing TAXSIM. Spouse age is now capped at [0, 100]; the respondent's own age is used as a proxy when the spouse age is implausible.

### Fix #7 — Industry Variable Correction
1979–1993 industry codes now use CPSIND70 (current-job industry) rather than a mix of current and longest-job codes, improving consistency with the occupation coding.

### Fix #8 — Hours Imputation for Employed-Zero-Hours Observations
Annual-period observations with positive wages but zero recorded hours receive imputed hours equal to the person's own median (or the sample-wide median as fallback), rather than being dropped or entering cumhrs at zero.

### Fix #9 — Lower Income Floor for Annual Period
Young workers early in their careers often fall below the $10,000 biennial floor. Annual-period observations use a $5,000 (1984 dollars) floor to retain part-time and early-career earners.

### Fix #10 — Marital Changers Retained with Controls
Observations where marital status changes between the base and end year are no longer dropped. Instead, indicators for the direction of change (single→married, married→single) are added as controls in the wage-change regression.

### Fix #11 — Lagged Income Change (Robustness)
A Kopczuk (2005)-style lagged income change control (`Δlog z_{t-3,t}`) is constructed but included only in robustness specifications, not the primary IV.

### Fix #12 — Extreme Income Change Trim
Log income changes beyond ±log(5) (~±161%) are trimmed to remove measurement error from employer-reported wage outliers while preserving genuine large changes.

---

## References

- Altonji, J.G. and C.R. Pierret (2001). "Employer Learning and Statistical Discrimination." *QJE* 116(1): 313–350.
- Farber, H. and R. Gibbons (1996). "Learning and Wage Dynamics." *QJE* 111(4): 1007–1047.
- Sztutman, A. (2024). "Dynamic Job Market Signaling and Optimal Taxation." Working paper.
- Chetty, R. (2012). "Bounds on Elasticities with Optimization Frictions." *Econometrica* 80(3): 969–1018.

---

## Version History

| Date | Changes |
|------|---------|
| Feb 2026 | Initial pipeline; Fixes #1–6 |
| Feb 2026 | EDA deep dive by occ × ind added |
| Apr 2026 | Fixes #7–12; five new analysis modules (Phases 1–5); joint bootstrap; paper draft |
