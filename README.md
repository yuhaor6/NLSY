# NLSY79 Labor Economics Research Project

## Overview

This project analyzes wage dynamics, human capital accumulation, and elasticity of taxable income (ETI) using the National Longitudinal Survey of Youth 1979 (NLSY79) panel data. The research examines whether early-career wage growth reflects skill formation (human capital) or signaling/employer learning.

**Principal Investigator:** Professor André Sztutman  
**Research Assistant:** Yuhao  
**Institution:** Carnegie Mellon University  

## Research Questions

1. **Elasticity of Taxable Income (ETI):** How do workers adjust their labor supply and reported income in response to changes in marginal tax rates?
2. **Skill vs. Signaling:** Does wage growth reflect actual skill accumulation (human capital theory) or revelation of pre-existing ability (signaling/employer learning)?
3. **Occupation × Industry Heterogeneity:** How do wage dynamics differ across occupation-industry cells?

---

## Folder Structure

```
📁 Stata Data/
├── 📄 Data_process.do              # Main data processing script
├── 📄 Two_Period_Analysis.do       # ETI analysis (annual & biennial)
├── 📄 Skill_vs_Signal_Analysis.do  # Skill formation vs signaling analysis
├── 📄 EDA_Wage_Analysis.do         # Basic exploratory data analysis
├── 📄 EDA_DeepDive_OccInd.do       # Deep dive EDA by occupation × industry
│
├── 📁 Raw Data/
│   ├── NLSY_All_Data.csv           # Main NLSY79 data extract
│   ├── left_out.csv                # Additional variables
│   ├── Occupation_Industry.csv     # Occupation/industry codes
│   └── demo_x_hour.csv             # Demographics and hours data
│
├── 📁 Intermediate Data/
│   ├── base_data.dta               # Imported main data
│   ├── left_out.dta                # Imported additional variables
│   ├── occupation_industry.dta     # Imported occ/ind data
│   ├── demo_hour_data.dta          # Imported demographics
│   ├── merged_data.dta             # Merged wide-format data
│   └── merged_data_with_occind.dta # Wide data with occ_broad/ind_broad
│
├── 📁 Analysis Data/
│   ├── nlsy_long_pre_taxsim.dta    # Long format, TAXSIM-ready
│   ├── eda_deepdive_data.dta       # EDA analysis dataset
│   ├── occ_ind_wage_moments.dta    # Wage moments by occ×ind
│   └── cumhrs_returns_by_cell.dta  # Cumhrs coefficients by cell
│
├── 📁 TAXSIM Output/
│   ├── taxsim_output_annual.dta    # Annual period tax calculations
│   ├── taxsim_output_biennial.dta  # Biennial period tax calculations
│   └── [counterfactual outputs]    # Counterfactual tax scenarios
│
├── 📁 Results/
│   ├── *.png                       # Generated graphs
│   └── *_log.txt                   # Analysis logs
│
└── 📁 Documentation/
    ├── README.md                   # This file
    └── CLAUDE.md                   # AI assistant instructions
```

---

## Data Pipeline

### Stage 1: Data Import and Merge (`Data_process.do` lines 1-62)

```
NLSY_All_Data.csv ──┐
left_out.csv ──────┼──> merged_data.dta (wide format)
Occupation_Industry.csv ──┤
demo_x_hour.csv ───┘
```

### Stage 2: Variable Creation (`Data_process.do` lines 63-1048)

- Rename raw variable codes to meaningful names (e.g., `r0046400` → `cpsocc70_1979`)
- Create cumulative hours with interpolation for biennial years
- Create broad occupation categories (1-9) from 3-digit codes
- Create broad industry categories (1-12) from 3-digit codes
- **IMPORTANT:** Save `merged_data_with_occind.dta` after line 1048

### Stage 3: Reshape to Long Format (`Data_process.do` lines 1700-1720)

```
merged_data.dta (wide) ──> nlsy_long_pre_taxsim.dta (long)
   12,686 obs × 911 vars      583,556 obs × 322 vars
   (one row per person)       (one row per person-year)
```

### Stage 4: TAXSIM Processing (`Data_process.do` lines 1720-2200)

- Calculate spouse and child ages
- Map NLSY marital status to TAXSIM codes
- Validate all TAXSIM input variables
- Create tax calculation inputs

### Stage 5: Analysis

```
nlsy_long_pre_taxsim.dta
         │
         ├──> Two_Period_Analysis.do ──> ETI estimates
         │
         ├──> Skill_vs_Signal_Analysis.do ──> Human capital vs signaling
         │
         └──> EDA_DeepDive_OccInd.do ──> Descriptive analysis
```

---

## Key Variables

### Identifiers
| Variable | Description |
|----------|-------------|
| `taxsimid` | Unique person identifier (NLSY case ID) |
| `year` | Calendar year (1978-2023) |

### Demographics
| Variable | Description |
|----------|-------------|
| `page` | Age at midpoint of income year |
| `sex` | 1=Male, 2=Female |
| `race_ethnicity` | 1=Hispanic, 2=Black, 3=Non-Black Non-Hispanic |
| `hgc` | Highest grade completed (year-specific) |
| `educ_years` | Years of education |
| `afqt_pct_2006` | AFQT percentile score (2006 norming) |

### Labor Market
| Variable | Description |
|----------|-------------|
| `pwages` | Primary wages and salary |
| `hrs` | Hours worked in year |
| `cumhrs` | Cumulative hours worked (interpolated) |
| `pot_exp` | Potential experience (age - education - 6) |
| `occ_broad` | Broad occupation (1-9), 1979-1993 only |
| `ind_broad` | Broad industry (1-12), 1979-1993 only |

### TAXSIM Inputs
| Variable | Description |
|----------|-------------|
| `mstat` | Marital status: 1=Single, 2=MFJ |
| `depx` | Number of dependents |
| `sage` | Spouse age (0 if single) |
| `swages` | Spouse wages (0 if single) |
| `psemp` | Primary self-employment income |
| `pui` | Primary unemployment insurance |

---

## Critical Fixes Implemented

### Fix #1: Marital Status Mapping
**Problem:** NLSY codes (0-4) were incorrectly mapped to TAXSIM codes (1-2).  
**Solution:** Only NLSY=1 (married, spouse present) → TAXSIM=2 (MFJ). All others → TAXSIM=1 (Single).

### Fix #2: Cumulative Hours Interpolation
**Problem:** Biennial surveys (1994+) miss even-year hours, causing cumulative hours to plateau.  
**Solution:** Interpolate missing years using average of adjacent observed years.

### Fix #3: Education Realignment
**Problem:** For biennial surveys, education is measured at interview but income is from prior year.  
**Solution:** Realign HGC variables (e.g., `hgc_1996` → `hgc_1995`).

### Fix #4: Demographic Realignment
**Problem:** Age and other demographics misaligned with income year.  
**Solution:** Subtract 1 from biennial year ages.

### Fix #5: Potential Experience
**Problem:** Calculated using final education, not year-specific education.  
**Solution:** Use `pot_exp = page - hgc - 6` with year-specific HGC.

### Fix #6: Spouse Age Validation
**Problem:** TAXSIM crashes on spouse age = 118 (corrupted DOB data).  
**Solution:** Validate sage ∈ [0, 100], use respondent age as proxy if invalid.

---

## Running the Analysis

### Prerequisites
- Stata 17 or later
- TAXSIM35 installed (`net install taxsim35, from("https://taxsim.nber.org/stata")`)
- Raw CSV files in working directory

### Execution Order

```stata
* Step 1: Process raw data
do "Data_process.do"

* Step 2: Run ETI analysis
do "Two_Period_Analysis.do"

* Step 3: Run skill vs signal analysis
do "Skill_vs_Signal_Analysis.do"

* Step 4: Run EDA (requires merged_data_with_occind.dta)
do "EDA_DeepDive_OccInd.do"
```

### Important Notes

1. **Before running EDA:** Add this line to Data_process.do after line 1048:
   ```stata
   save "merged_data_with_occind.dta", replace
   ```

2. **TAXSIM requires internet:** The `taxsim35` command sends data to NBER servers.

3. **Memory:** The long-format dataset has 583,556 observations. Ensure sufficient RAM.

---

## Occupation and Industry Codes

### Broad Occupation Categories (1970 Census)
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

### Broad Industry Categories (1970 Census)
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

**Note:** Occupation and industry data with consistent 1970 Census codes are only available for 1979-1993.

---

## Sample Characteristics

| Characteristic | Value |
|----------------|-------|
| Total person-years | 583,556 |
| Unique individuals | 12,686 |
| Years covered | 1978-2023 (46 years) |
| Married person-years | 109,856 (18.8%) |
| Single person-years | 473,700 (81.2%) |
| Mean potential experience | 14.0 years |
| AFQT available | 11,914 individuals |

---

## Output Files

### Data Files
- `nlsy_long_pre_taxsim.dta` - Main analysis dataset
- `eda_deepdive_data.dta` - EDA dataset with occ/ind merged
- `occ_ind_wage_moments.dta` - Wage distribution by cell
- `cumhrs_returns_by_cell.dta` - Returns to cumulative hours by cell

### Graphs (from EDA)
- `hist_obs_per_cell.png` - Distribution of observations per occ×ind cell
- `hist_individuals_per_cell.png` - Distribution of individuals per cell
- `boxplot_wages_top_cells.png` - Wage distribution for top cells
- `wage_exp_profile_pooled.png` - Wage-experience profile
- `wage_exp_by_occupation.png` - Profiles by occupation
- `wage_exp_by_industry.png` - Profiles by industry
- `hist_cumhrs_coef.png` - Distribution of cumhrs returns
- `forest_cumhrs_returns.png` - Forest plot of returns by cell
- `scatter_age_exp.png` - Age vs experience scatter
- `scatter_age_cumhrs.png` - Age vs cumulative hours scatter
- `hist_person_mean_wage.png` - Person-level mean wages
- `avg_wage_age_profile.png` - Average wage-age profile
- `event_study_cell_switch.png` - Wages around occ/ind switch
- `density_overlay_cells.png` - Wage densities by cell

---

## Contact

For questions about this project, contact the research team at Carnegie Mellon University.

---

## Version History

| Date | Version | Changes |
|------|---------|---------|
| Feb 2026 | 1.0 | Initial data processing pipeline |
| Feb 2026 | 1.1 | Fixes #1-6 implemented |
| Feb 2026 | 1.2 | EDA deep dive added |
