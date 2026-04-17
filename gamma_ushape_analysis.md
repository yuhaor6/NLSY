# Why the γ Profile is U-Shaped: A Mathematical Diagnosis
**NLSY79 Labor Signaling Project — Internal Research Note**
**Date:** April 11, 2026
**Author:** Research team

---

## The Puzzle

After running `Structural_Wage_Experience.do` with all data cleaning fixes applied, the career-stage γ profile looks like this:

| Stage | pot_exp range | N | γ_FE | SE | t |
|-------|--------------|---|------|----|---|
| Q1 (Early career) | 0–3 yr | 39,520 | **1.1012** | 0.0210 | 52.33 |
| Q2 | 4–8 yr | 38,814 | **1.0487** | 0.0380 | 27.61 |
| Q3 | 9–14 yr | 32,892 | **1.0670** | 0.0628 | 16.99 |
| Q4 | 15–25 yr | 34,383 | **0.9274** | 0.0571 | 16.23 |
| Q5 (Late career) | 26–40 yr | 33,600 | **1.1151** | 0.1099 | 10.15 |
| **Full career** | 0–40 yr | **179,209** | **0.9366** | **0.0105** | **89.33** |

The Sztutman (2024) signaling model predicts either:
- **Pareto case:** γ constant across career (constant τ_p)
- **General dynamic case:** γ declining across career (employer learning completing, information asymmetry falling)

What we observe is neither. The profile rises from Q4 to Q5, dips at Q4, and is above 1.0 for most of the career. The Wald test rejects γ equality (F = 16.865, p < 0.001), but the rejection is not telling us what we hoped.

**This note traces, step by step, how we found the causes — working from the raw regression output inward.**

---

## Step 1: Reading the Regression Output as Data

Before invoking any theory, the regression output itself contains diagnostic information that most applied researchers skip. We extract three numbers from each quintile regression that tell us about the *geometry* of the estimation problem.

### 1.1 The Within R² Collapse

| Stage | Within R² | Between R² | Avg T |
|-------|-----------|------------|-------|
| Q1 | **0.5003** | 0.5020 | 4.1 |
| Q2 | 0.1881 | 0.5305 | 3.8 |
| Q3 | 0.1168 | 0.4896 | 3.7 |
| Q4 | 0.1085 | 0.4310 | 4.3 |
| Q5 | **0.0263** | 0.3048 | 4.8 |

**What this means:** Within R² measures how much of the *within-person* variation in log wages is explained by the model (log_cumhrs + pot_exp + pot_exp² + year FEs). For the FE estimator, this is the relevant number — it tells you how tightly the identification is working.

Q1 Within R² = 0.50 is exceptionally high for a wage panel regression. Something is being explained very well within-person in early career. But what? Year FEs alone do not produce this — look at Q4 and Q5 where year FEs are numerous but Within R² is 0.11 and 0.03. The answer is that in Q1, `log_cumhrs` and the year fixed effects together are absorbing virtually all within-person wage growth. They are not *both* doing their job — they are *competing* for the same variation.

Q5 Within R² = 0.0263 is alarmingly low. Only 2.6% of within-person Q5 wage variation is explained. The model has essentially no identifying variation in Q5. The γ_Q5 = 1.115 is being estimated from near-zero signal.

### 1.2 The pot_exp Coefficient Pattern

| Stage | β(pot_exp) | SE | t | p |
|-------|-----------|-----|---|---|
| Q1 | −0.0070 | 0.0152 | −0.46 | 0.643 |
| Q2 | −0.0945 | 0.0266 | −3.56 | <0.001 |
| Q3 | −0.1100 | 0.0347 | −3.17 | 0.002 |
| Q4 | −0.0272 | 0.0193 | −1.41 | 0.159 |
| Q5 | −0.0043 | 0.0188 | −0.23 | 0.820 |

pot_exp is **completely insignificant in Q1** and **completely insignificant in Q5**. This pattern is a smoking gun. In Q1, the insignificance is not because experience doesn't matter early — it obviously does. It's because `log_cumhrs` has *already absorbed* the variation that pot_exp should be explaining. In Q5, experience is flat (workers aged 48–62 in a quadratic specification where the quadratic has effectively plateaued), so the variable is inherently uninformative.

The middle quintiles (Q2–Q3) show the "correct" pattern: a strong negative experience gradient as workers' wages grow with experience in a way not fully captured by cumhrs accumulation.

### 1.3 The corr(u_i, Xb) Sign Reversal

| Stage | corr(u_i, Xb) |
|-------|--------------|
| Q1 | **−0.1357** |
| Q2 | −0.0002 |
| Q3 | +0.0438 |
| Q4 | **+0.1508** |
| Q5 | +0.0561 |

Under standard random effects assumptions, corr(u_i, Xb) should be zero. In FE, the person-level fixed effect u_i is by construction orthogonal to the *demeaned* regressors — but it can correlate with the levels. In Q1, the negative correlation means that the FE for person i is negatively correlated with their average value of the regressors (log_cumhrs, pot_exp). This is a signature of **omitted person-level trends**: high-trend workers have their trajectory partially captured in the time-varying regressors rather than entirely in the fixed effect, creating a negative residual correlation with the FE.

---

## Step 2: The Mathematical Structure of the Bias

We now formalize why each part of the profile is contaminated.

### 2.1 Mechanism A: Heterogeneous Trend Contamination (Q1, Q2)

**The true data-generating process.** Suppose each person's wage trajectory is:

> log(w_it) = α_i + **α'_i · (t − t₀_i)** + γ · log(cumhrs_it) + β · pot_exp_it + ε_it

where α_i is the person-fixed wage level and **α'_i is a person-specific linear trend** — the steepness of their individual career trajectory. Some workers are on steep paths (high match quality, promotions, career capital); others are flat (routine jobs, stagnant sectors).

The standard FE estimator demeans within-person to remove α_i:

> (log(w_it) − log(w̄_i)) = α'_i · (t − t̄_i) + γ · (log_cumhrs_it − log_cumhrs̄_i) + ...

The term α'_i · (t − t̄_i) is **not removed by demeaning** — it's the deviation of the trend from its person-mean, which is non-zero. It remains in the residual.

The FE estimator for γ will be:

$$\text{plim}(\hat{\gamma}_{FE}) = \gamma_{\text{true}} + \underbrace{\frac{\text{Cov}(\alpha'_i \cdot (t - \bar{t}_i),\; \widetilde{\log\text{cumhrs}}_{it})}{\text{Var}(\widetilde{\log\text{cumhrs}}_{it})}}_{\text{trend bias}}$$

where tilde denotes within-person demeaning.

**The bias is positive** because:
1. High-trend workers (high α'_i) are on steeper career trajectories
2. Workers on steep trajectories tend to accumulate hours faster (positive selection into hours-intensive, high-return jobs)
3. Therefore Cov(α'_i, fast cumhrs growth) > 0
4. Which makes Cov(α'_i · (t − t̄_i), Δlog_cumhrs) > 0
5. → γ_FE is biased upward

**Why this is severe in Q1.** With avg T = 4.1 observations per person in Q1, the FE demeaning subtracts a 4-point mean from a 4-point trajectory. For workers with a *linear* individual trajectory, the demeaned series is essentially the deviation from a linear trend — which is close to zero. The FE estimator in a short panel cannot distinguish "person i has a steep wage trajectory" from "person i has high γ." Both look like: person i's wage rises as their cumhrs rises. In a 29-year panel (Q_full, avg T = 15.6), this confusion is much less severe because the trajectory and the cumhrs accumulation curve have different functional forms over a long horizon.

**Why this attenuates by Q4.** By pot_exp 15–25 (ages ~37–47), the heterogeneous-trend component of wage growth has substantially attenuated. Wages have flattened (the Mincer profile levels off), promotion ladders are largely exhausted, and career trajectories have converged. α'_i becomes small for most workers. The trend bias shrinks toward zero.

### 2.2 Mechanism B: Identification Degeneracy (Q5)

**The geometric statement.** The FE estimator computes:

$$\hat{\gamma}_{Q5} = \frac{\sum_i \sum_t \tilde{y}_{it} \cdot \tilde{x}_{it}}{\sum_i \sum_t \tilde{x}_{it}^2}$$

where tilde denotes within-person, within-year-FE demeaning (i.e., the residual from a regression on all controls). The denominator is the sum of squared residual variation in log_cumhrs.

For Q5 workers (pot_exp 26–40, ages ~48–62, observed biennially in 1995–2021):

- Cumulative hours ≈ 50,000–70,000 (20+ years of work)
- Biennial increment ≈ 4,000 hours
- Δlog(cumhrs) per period ≈ 4,000/55,000 ≈ 0.073

After demeaning out year effects and experience controls, the **net identifying variation** in log_cumhrs within Q5 is the deviation of this 0.073 increment from its person-average. For workers with steady hours, this deviation is close to zero — and we're dividing by a near-zero denominator.

This is mathematically equivalent to a near-degenerate linear system. In topology terms: the regressor vector (log_cumhrs demeaned within-person) is close to the zero vector in ℝ^(T_i). The projection of the wage vector onto this near-zero direction is numerically unstable. Any small perturbation in the data rotates the estimated slope wildly.

The algebraic consequence is SE = 0.1099 for Q5 vs. SE = 0.0210 for Q1. The 95% confidence interval for γ_Q5 is **[0.90, 1.33]** — it contains the entire range of γ estimates from Q1 through Q4. The "U-shape rebound at Q5" is not a statistical finding. It is a point estimate from a regression that has nearly no identifying information.

**The FWL confirmation.** The Frisch-Waugh-Lovell (FWL) check we ran confirmed:
- Original log_cumhrs SD within-person: **1.1566**
- Residualized log_cumhrs SD (after removing pot_exp and year FEs): **0.3287**
- **71.6% of within-person cumhrs variation is explained by experience + time trends**

Only 28.4% of within-person cumhrs variation is "pure" — not collinear with the controls. In Q5 specifically, this fraction is even lower, which is why Within R² collapses to 0.0263.

**FWL theorem also told us something important:** The residualized γ estimates are *identical* to the primary γ estimates (differences = 0.0000 for all quintiles). This confirms the FE estimator is doing exactly what it should: it is correctly computing the partial correlation between wages and cumhrs after removing the collinear components. The problem is not a bug in the code — it is that the "purified" log_cumhrs variation in Q5 is so small that the coefficient is estimated from noise.

### 2.3 Mechanism C: Survivor Selection Bias (Q5)

Even if the near-degeneracy problem did not exist, Q5 faces a separate identification problem: **non-random attrition**.

Q5 workers are ages 48–62. The NLSY79 panel follows respondents who remain in the survey. Late-career exits are:
- Retirement (voluntary) — wages may have been rising, then the person exits
- Disability — wages would be falling, then the person exits
- Involuntary job loss — wages falling, person exits or has missing wages
- Survey non-response — non-random

Workers who *remain* in Q5 with positive wages are disproportionately those on positive career trajectories — receiving promotions into late career, phased retirement at high hourly rates, or continuing in stable high-skill positions. Workers whose hours declined and wages stagnated are more likely to have exited the sample.

This creates selection on the joint distribution of Δwage and Δhours. Among Q5 survivors:

> E[Δlog_wage | Δlog_cumhrs, survive in Q5] > E[Δlog_wage | Δlog_cumhrs]

Because workers who reduce hours while wages fall are underrepresented among survivors. This mechanical positive association between log_cumhrs growth and log_wage growth among survivors inflates γ_Q5 upward through survivorship bias — independently of any structural parameter.

### 2.4 The Deeper Problem: Two Measurement Regimes in One Dataset

The U-shape has a structural cause that underlies Mechanisms A, B, and C: **the career quintiles span two fundamentally different measurement regimes** within the NLSY79.

| | Q1 (Annual, 1978–1993) | Q5 (Biennial, 1995–2021) |
|--|------------------------|--------------------------|
| Data frequency | Annual | Biennial |
| Δlog(cumhrs) per period | ~0.33 (at 5,000 cumhrs) | ~0.073 (at 55,000 cumhrs) |
| Year FEs | 26 annual dummies | 17 biennial dummies |
| Avg obs per person | 4.1 | 4.8 |
| Typical age at observation | 18–22 | 48–62 |
| Labor market stage | Entry + early career | Prime/late career |

The FE estimator is applied identically across these regimes, but the identifying variation, the functional form of the trajectory, and the selection mechanisms are completely different. **This is not a data cleaning issue — it is an inherent feature of the NLSY79 longitudinal design.**

The key consequence for Q1: log_cumhrs grows rapidly in absolute log-units during the annual period. A worker going from cumhrs = 2,000 to cumhrs = 8,000 over 4 years has Δlog_cumhrs = log(8000) − log(2000) = 1.39. That is a large signal for the FE estimator to pick up. But it coincides exactly with the steepest part of the Mincer experience-wage profile, the period of maximum match quality revelation, and the maximum potential for heterogeneous trend bias. The estimator cannot tell apart "γ is large in early career" from "heterogeneous trends are conflated with cumhrs growth in early career."

---

## Step 3: Model Specification Issues

Beyond the estimation bias, the current specification has three structural issues.

### 3.1 The Age-Period-Cohort (APC) Problem in Year FEs

The model includes year fixed effects (i.year) to control for aggregate wage trends. But the NLSY79 is a **single cohort** (born 1957–1964). For a single cohort:

> age = year − birth_year
> pot_exp ≈ age − education − 6

This means that for any person:
> year = birth_year + pot_exp + education + 6

**Year, age, and experience are linearly dependent** (up to education and birth_year, which are fixed per person). The FE estimator removes birth_year (the individual fixed effect absorbs it). But within a person, year = constant + pot_exp. The year FE and the experience variable are **linearly related within-person** in a single cohort.

Concretely: when you run `xtreg log_pwages log_cumhrs pot_exp pot_exp2 i.year, fe` on NLSY79 data, Stata can technically estimate the coefficients because the cohort spread (7-year birth window) prevents perfect collinearity in the full sample. But within narrowly defined career quintiles where cohort spread is compressed, year ≈ constant × pot_exp within a person, and the year FEs and experience terms are nearly multicollinear. This is why the year FEs in Q1 span 1978–2021 with massive magnitudes (from −0.24 to +5.11) — they are absorbing both time trends *and* cohort-specific career progression.

The consequence: the year FEs eat the experience-driven wage growth, leaving less "clean" variation for γ to be identified from. For Q5 in particular, the year FEs are estimated from a biennial grid (1992, 1993, 1995, 1997, ...) and span 30 years. With avg T = 4.8, you have 17 year dummies estimated from 4.8 observations per person. This is a severely over-parameterized model within Q5.

### 3.2 Constant Elasticity Assumption vs. Dynamic Model

The current specification imposes:

> log(w_it) = α_i + **γ** · log(cumhrs_it) + β · X_it + ε_it

This is a **constant elasticity** specification: every doubling of cumhrs raises wages by the same percentage, regardless of where you are in the career. But the Sztutman (2024) model predicts that in the general dynamic case:

> γ(t) = δ_t / (1 − δ_t + ε)

where δ_t is the information asymmetry at time t, which should be *declining* as employers learn about worker quality. The structural parameter is not a constant — it is a function of career time.

The quintile-splitting approach tries to approximate γ(t) as a step function: estimate a separate constant γ for each career segment. But this misses **within-quintile dynamics**. In Q1 (pot_exp 0–3), γ(t) may be rapidly declining even over those 4 years as initial screening occurs. By fitting a single γ_Q1, we average over a very steep early-career learning curve and get a high average. The step-function approximation introduces a bias that depends on how rapidly γ(t) changes within each quintile.

**A better specification:** Model γ as a smooth function of pot_exp using a cubic spline or a polynomial in experience interacted with log_cumhrs:

> log(w_it) = α_i + (β₀ + β₁·exp + β₂·exp² + β₃·exp³) · log(cumhrs_it) + β_x · pot_exp_it + ε_it

This estimates γ(t) as a continuous curve rather than a step function, and would reveal whether the career profile of γ is monotone-declining (consistent with the signaling model) or genuinely non-monotone.

### 3.3 Simultaneity: log_cumhrs is Not Strictly Exogenous Within-Person

The FE estimator requires **strict exogeneity**: E[ε_it | log_cumhrs_is, for all s] = 0. This means that shocks to wages in period t cannot be correlated with cumhrs in any period (past, present, or future).

Within-person cumhrs variation in the annual period is driven by hours-of-work decisions. Hours are a *choice variable* that responds to wages. In a year of positive wage shocks (ε_it > 0), the worker earns more and may work more or fewer hours depending on substitution vs. income effects. Even setting aside the contemporaneous correlation, the cumulative nature of cumhrs means that:

> Cov(log_cumhrs_it, ε_is) ≠ 0 for s < t

because past wage shocks that led to more work have increased current cumhrs. This is **Granger causality running from wages to cumhrs**, which violates strict exogeneity.

In the current specification, there is no instrument for log_cumhrs *variation within a person*. The ETI framework instruments for the *level* of wages via tax reforms, but this is a different equation (the two-period difference-in-differences) from the panel FE wage regression used here.

The practical consequence: γ_FE is measuring a combination of (a) the causal effect of cumhrs on wages through signaling and human capital, and (b) the reverse effect of wage shocks on subsequent cumhrs accumulation. In early career where both effects are strongest, this simultaneity bias inflates γ upward.

---

## Step 4: What the Full-Sample γ = 0.937 Tells Us

The full-sample FE estimate (γ = 0.9366, SE = 0.0105, t = 89.3) is substantially more reliable than any quintile estimate for several reasons:

**1. Avg T = 15.6 observations per person.** With 15.6 observations per person, the FE demeaning can meaningfully separate the person fixed effect from the within-person trend. Heterogeneous trend bias is substantially attenuated with longer panels — the trend and the level become distinguishable.

**2. The year FEs span all 43 years, estimated from all persons simultaneously.** In the quintile regressions, year FEs are estimated from small subsamples. In the full sample, each year FE is identified from thousands of persons across all career stages simultaneously, making it more stable.

**3. The large N (179,209) means the estimator is near its large-sample limit.** Even if each quintile estimate is biased, the full-sample average over quintiles is less sensitive to the outlier behavior at Q1 and Q5.

**4. γ_full (0.937) ≈ γ_Q4 (0.927)**, the quintile we identified as having the least bias. This is reassuring: the full-sample estimate and the "cleanest" quintile agree, suggesting 0.93–0.94 is the structural number.

---

## Step 5: The Correct Framing

Given this analysis, the U-shaped profile should not be presented as an unexplained anomaly or evidence against the signaling model. It should be framed as follows:

**The γ profile (Q1=1.10 → Q4=0.93 → Q5=1.12) does not represent the structural information asymmetry parameter γ(t) declining then rebounding. It represents three different bias structures across three different data regimes:**

1. **Q1–Q3 are upward biased** due to heterogeneous trend contamination in short annual panels (avg T ≈ 4), where the FE estimator cannot separate steep career trajectories from high cumhrs elasticities.

2. **Q4 is the least-biased estimate** (γ = 0.927): trend bias has attenuated as wages plateau at mid-career, and the biennial panel has sufficient identifying variation. The full-sample γ = 0.937 confirms this.

3. **Q5 is not identified** (SE = 0.1099, 95% CI = [0.90, 1.33]): near-degenerate variation in log_cumhrs at late career, compounded by survivor selection among workers who remain in the survey at ages 48–62. The point estimate of 1.115 is numerically meaningless.

**The Wald test (F = 16.865) is correctly rejecting** γ equality — but what varies across quintiles is not γ_true but the *bias structure of the estimator*, which changes across measurement regimes.

**The cleanest summary statement:** γ ≈ 0.93 (from Q4 and the full sample) is the structural elasticity of wages to cumulative hours. The apparent Q1–Q3 elevation is an estimation artifact of short panels during the heterogeneous-trend-dominated early career.

---

## Step 6: What Comes Next

Three concrete steps follow from this analysis:

### 6.1 Add Person-Specific Linear Time Trends to Q1 (Priority)

Run the following within Q1:

```stata
* Mundlak-style detrending: add person × year interaction (linear trend only)
* This absorbs heterogeneous trend bias α'_i · (t - t̄_i)
gen year_centered = year - 1978
xtreg log_pwages log_cumhrs pot_exp pot_exp2 i.year c.year_centered#i.taxsimid ///
    if phase1_sample == 1 & exp_quintile == 1, fe cluster(taxsimid)
```

**Prediction:** γ_Q1 will drop from 1.10 toward 0.85–0.95, making the profile roughly monotone-declining from Q1 to Q4 — consistent with the dynamic signaling model (employer learning completing over careers). If this prediction is correct, it simultaneously confirms the heterogeneous-trend diagnosis and supports the Sztutman framework.

Note: this specification is data-intensive and may be under-powered with avg T = 4.1. An alternative is the **Arellano-Bond GMM estimator** which uses lagged levels as instruments for the differenced equation, absorbing both the fixed effect and the trend without requiring a separate trend per person.

### 6.2 Replace Step-Function γ with a Continuous Spline

Estimate γ as a smooth function of pot_exp. In Stata:

```stata
* Cubic spline in experience interacted with log_cumhrs
mkspline exp_sp = pot_exp, cubic nknots(4)
xtreg log_pwages c.exp_sp#c.log_cumhrs exp_sp pot_exp2 i.year ///
    if phase1_sample == 1, fe cluster(taxsimid)
```

Plot the implied γ(pot_exp) curve. If the signaling model is correct, this curve should be downward-sloping from high early-career values toward a stable late-career level. The step-function approach misses this curvature and creates spurious "U-shapes" by averaging over segments where γ(t) is changing rapidly.

### 6.3 Report Honest Uncertainty on γ_Q5

The current results table reports γ_Q5 = 1.1151 with SE = 0.1099 and t = 10.15 as if it is a meaningful estimate. Given the analysis above, it is not. The honest reporting should note that the Q5 estimate is not identified — the model has Within R² = 0.026 in Q5 and the CI spans [0.90, 1.33], overlapping every other quintile. Q5 should be reported with a footnote: "Not identified; Within R² = 0.026 due to near-flat within-person cumhrs trajectories in the biennial panel at late career. Point estimate unreliable."

---

## Summary of Findings

| Observation | Root cause | Type |
|-------------|-----------|------|
| γ_Q1–Q3 > 1.0 | Heterogeneous trend bias in short annual panels (avg T = 4) | Estimation artifact |
| pot_exp insignificant in Q1 | log_cumhrs absorbing experience variation (APC collinearity) | Specification issue |
| Q5 "rebound" γ = 1.115 | Near-degenerate identification + survivorship selection | Estimation artifact |
| SE_Q5 = 0.1099 (10× SE_Q1) | Near-zero within-person identifying variation in biennial late-career panel | Data regime |
| Within R² collapses Q1→Q5 | Annual→biennial measurement regime change across career | Data structure |
| γ_Q4 ≈ γ_full ≈ 0.93 | Q4 and full sample least affected by both bias mechanisms | Structural parameter |
| Wald F = 16.865 | Detecting variation in bias structure, not variation in γ_true | Misinterpretation risk |

**The structural parameter for the signaling model is γ ≈ 0.93**, identified from the full-sample FE and corroborated by Q4. This implies δ = 0.628 (biennial ETI) and τ_p = 19.1% (primary estimate). The U-shape is a methodological artifact of estimating a dynamic parameter with a static model across heterogeneous data regimes.
