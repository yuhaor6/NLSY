"""
Clean AI-style comments from all .do files.
Transforms: bordered headers, verbose theory blocks, SCRUTINY sections, etc.
"""
import re, os, glob

DO_DIR = r"D:\Stata Data\labor_signaling_project\do file"

# Files to skip (auto-generated label files)
SKIP = {"demo_x_hour-value-labels.do", "NLSY_All_Data-value-labels.do",
        "Occupation_Industry-value-labels.do", "early_small_data_process.do"}

# ── New concise headers for each file ──
HEADERS = {
    "BSX_Wage_Elasticity.do": """\
* BSX_Wage_Elasticity.do
* Estimates wage-change elasticity of taxable income using LOO industry instrument
* Adapted from Becko, Sztutman & Xia (2024) Eq. 30-31 to NLSY79
* Hourly wage = pwages/hrs; instrument = leave-one-out industry avg wage change
* Stage 1 only: hourly wage construction + diagnostics
* Date: March 2026
""",
    "Structural_Wage_Experience.do": """\
* Structural_Wage_Experience.do
* Estimates structural gamma (return to cumulative hours) across career stages
* and recovers implied information asymmetry parameter delta.
* Model: log(w) = alpha_i + gamma*log(cumhrs) + beta*X + u  (Sztutman 2024)
* Tests: gamma constancy across stages, OLS vs FE gap, delta in (0,1)
* Input:  data/nlsy_long_pre_taxsim.dta
* Output: Phase1 tables + figures in output/
""",
    "Two_Period_Analysis.do": """\
* Two_Period_Analysis.do
* Two-period IV estimation of the elasticity of taxable income (ETI)
* Annual (lag=1yr) and biennial (lag=2yr) specifications
* Instruments: predicted net-of-tax rate changes from TAXSIM counterfactuals
* Includes bootstrap CIs, near-worker robustness, occupation heterogeneity,
* and joint gamma+epsilon bootstrap.
* Input:  data/analysis_annual.dta, data/analysis_biennial.dta
* Output: two_period_analysis_log.txt, Phase2 tables/figures
""",
    "Advantageous_Selection_Test.do": """\
* Advantageous_Selection_Test.do
* Tests for advantageous selection into tax-change bunching (Sztutman 2024)
* Uses AFQT scores as a proxy for ability; compares ability distribution
* between workers who do vs. don't adjust taxable income around reforms.
* Reforms: EGTRRA 2001, JGTRRA 2003, TCJA 2017
* Input:  data/nlsy_long_pre_taxsim.dta
* Output: Phase3 tables/figures
""",
    "Labor_Wedge_Estimation.do": """\
* Labor_Wedge_Estimation.do
* Estimates the labor wedge chi = 1/(1 - tau_L) from combined ETI and
* participation elasticity. Uses reform x income interactions as instruments.
* Input:  data/nlsy_long_pre_taxsim.dta, TAXSIM outputs
* Output: Phase2 labor wedge tables
""",
    "Sector_Heterogeneity_Analysis.do": """\
* Sector_Heterogeneity_Analysis.do
* Estimates gamma and Altonji-Pierret employer-learning coefficients
* separately by occupation and industry groups.
* Tests whether signaling intensity varies by sector (e.g. finance vs mfg).
* Restricted to 1979-1993 (when occ/ind codes are available).
* Input:  data/nlsy_long_pre_taxsim.dta, data/merged_data_with_occind.dta
* Output: Phase4 tables/figures
""",
    "Pigouvian_Tax_Quantification.do": """\
* Pigouvian_Tax_Quantification.do
* Computes the optimal Pigouvian tax on signaling:
*   tau_p = delta / (alpha * (1 + delta))
* Collects gamma, epsilon, delta, alpha from prior phases and propagates
* uncertainty via delta method.
* Input:  Phase 1-4 outputs
* Output: Phase5 summary table + tau profile figure
""",
    "EDA_DeepDive_OccInd.do": """\
* EDA_DeepDive_OccInd.do
* Exploratory analysis of wage distributions by occupation x industry cells
* Wage moments, between/within decomposition, transition matrices
* Restricted to 1979-1993 (occ/ind available)
* Input:  data/nlsy_long_pre_taxsim.dta, data/merged_data_with_occind.dta
* Output: EDA tables in output/
""",
    "EDA_Wage_Analysis.do": """\
* EDA_Wage_Analysis.do
* Exploratory wage analysis: distributions, age profiles, experience returns
* Input:  data/nlsy_long_pre_taxsim.dta
* Output: EDA figures + log file
""",
    "Data_process.do": None,  # Keep existing header, just clean section markers
    "Data_process_integrated.do": None,  # Keep existing header
    "Skill_vs_Signal_Analysis.do": """\
* Skill_vs_Signal_Analysis.do
* Tests human capital vs. signaling/employer learning models
* Key test: does wage growth track cumulative hours (HC) or decrease
* with tenure (signaling/learning)?
* Implements Altonji-Pierret (2001) style regressions.
* Input:  data/nlsy_long_pre_taxsim.dta
* Output: Skill_vs_Signal tables
""",
}


def find_header_end(lines):
    """Find the end of the opening /*==...==*/ block."""
    if not lines or not lines[0].strip().startswith("/*=="):
        return 0
    for i, line in enumerate(lines):
        if i > 0 and line.strip().endswith("*/"):
            return i + 1
    return 0


def clean_section_headers(text):
    """Replace /*====...====*/ and /*----...----*/ section headers with simpler * --- style."""
    def replace_section(m):
        content = m.group(0)
        inner_lines = content.split("\n")
        titles = []
        for ln in inner_lines:
            stripped = ln.strip().strip("/*=- ")
            if stripped and not re.match(r'^[=\-]+$', stripped):
                titles.append(stripped)
        if titles:
            title = " — ".join(titles[:2])
            return f"* --- {title} ---"
        return ""

    # Match /*====...====*/ blocks (multi-line)
    text = re.sub(
        r'/\*={3,}.*?={3,}\*/',
        replace_section,
        text,
        flags=re.DOTALL
    )
    # Match /*----...----*/ blocks (multi-line)
    text = re.sub(
        r'/\*-{3,}.*?-{3,}\*/',
        replace_section,
        text,
        flags=re.DOTALL
    )
    return text


def clean_dashed_headers(text):
    """Replace *------...------ lines with shorter dividers."""
    text = re.sub(r'^\*-{20,}$', '* --------', text, flags=re.MULTILINE)
    text = re.sub(r'^\* -{20,}$', '* --------', text, flags=re.MULTILINE)
    return text


def remove_scrutiny_blocks(text):
    """Remove SCRUTINY CHECKPOINTS, STEERING DECISION, INTERPRETATION GUIDE blocks."""
    # Remove multi-line blocks starting with these headers
    patterns = [
        r'^\* *SCRUTINY CHECKPOINTS:.*?(?=^\*[^*\- ]|\n\n[^*])',
        r'^\* *STEERING DECISION:.*?(?=^\*[^*\- ]|\n\n[^*])',
        r'^\* *INTERPRETATION GUIDE:.*?(?=^\*[^*\- ]|\n\n[^*])',
        r'^\* *SCRUTINY SUMMARY.*?(?=^\*[^*\- ]|\n\n[^*])',
        r'^\* *COMPARISON:.*?(?=^\*[^*\- ]|\n\n[^*])',
    ]
    for pat in patterns:
        text = re.sub(pat, '', text, flags=re.MULTILINE | re.DOTALL)
    return text


def simplify_verbose_comments(text):
    """Tone down overly formal/verbose comment patterns."""
    # "PART 0:" → "Part 0:" etc
    text = re.sub(r'^(\* *---? *)PART (\d+[A-Za-z]?):',
                  lambda m: f"{m.group(1)}Part {m.group(2)}:",
                  text, flags=re.MULTILINE)

    # Standalone "PART X:" lines
    text = re.sub(r'^\* *PART (\d+[A-Za-z]?): *(.*)$',
                  lambda m: f"* --- Part {m.group(1)}: {m.group(2).strip()} ---",
                  text, flags=re.MULTILINE)

    # "STAGE X:" → "Stage X:"
    text = re.sub(r'^\* *STAGE (\d+[\.\d]*):',
                  lambda m: f"* Stage {m.group(1)}:",
                  text, flags=re.MULTILINE)

    # "FIX #X: LONG DESC" → "Fix: short desc"
    text = re.sub(r'^\* *FIX #\d+[a-z]?: *(.*)$',
                  lambda m: f"* Fix: {m.group(1).strip()}" if m.group(1).strip() else "",
                  text, flags=re.MULTILINE)

    # "VERIFICATION:" → "Check:"
    text = re.sub(r'^(\* *)VERIFICATION:', r'\1Check:', text, flags=re.MULTILINE)

    # "CRITICAL CHECKS:" → "Key checks:"
    text = re.sub(r'^(\* *)CRITICAL CHECKS:', r'\1Key checks:', text, flags=re.MULTILINE)

    # "THEORETICAL PREDICTION:" → remove or simplify
    text = re.sub(r'^(\* *)THEORETICAL PREDICTION:', r'\1Prediction:', text, flags=re.MULTILINE)

    # "RESEARCH DESIGN:" → "Design:"
    text = re.sub(r'^(\* *)RESEARCH DESIGN:', r'\1Design:', text, flags=re.MULTILINE)

    # "KNOWN DATA LIMITATION:" → "Note:"
    text = re.sub(r'^(\* *)KNOWN DATA LIMITATION:', r'\1Note:', text, flags=re.MULTILINE)

    # "ESTIMATION STRATEGY:" → "Approach:"
    text = re.sub(r'^(\* *)ESTIMATION STRATEGY:', r'\1Approach:', text, flags=re.MULTILINE)

    # "CORRECTIONS APPLIED.*:" → "Prior corrections:"
    text = re.sub(r'^(\* *)CORRECTIONS APPLIED.*:', r'\1Prior corrections:', text, flags=re.MULTILINE)

    # "CROSS-PHASE CONSISTENCY CHECK" → simpler
    text = re.sub(r'CROSS-PHASE CONSISTENCY CHECK', 'Cross-phase check', text)

    # "OUTPUT FILES CREATED:" → "Output:"
    text = re.sub(r'^(\* *)OUTPUT FILES CREATED:', r'\1Output:', text, flags=re.MULTILINE)

    # Remove "Author: Claude Code (Anthropic)..." lines
    text = re.sub(r'^\* *AUTHOR:.*Claude.*$\n?', '', text, flags=re.MULTILINE | re.IGNORECASE)

    # Replace "[Research team]" with author name
    text = re.sub(r'\[Research team\]', 'Yuhao Ren', text)

    # Remove "DO FILE VERSION:" lines
    text = re.sub(r'^\* *DO FILE VERSION:.*$\n?', '', text, flags=re.MULTILINE)

    # Clean up "ANALYSES INCLUDED:" → "Analyses:"
    text = re.sub(r'^(\* *)ANALYSES INCLUDED:', r'\1Analyses:', text, flags=re.MULTILINE)

    # "RESEARCH QUESTION:" → remove the label
    text = re.sub(r'^(\* *)RESEARCH QUESTION:', r'\1Research question:', text, flags=re.MULTILINE)

    # "KEY TESTS:" → "Tests:"
    text = re.sub(r'^(\* *)KEY TESTS:', r'\1Tests:', text, flags=re.MULTILINE)

    # "FINAL DELIVERABLE:" → "Goal:"
    text = re.sub(r'^(\* *)FINAL DELIVERABLE:', r'\1Goal:', text, flags=re.MULTILINE)

    # "THEORETICAL PREDICTIONS" → "Predictions"
    text = re.sub(r'THEORETICAL PREDICTIONS', 'Predictions', text)

    # "SAMPLE RESTRICTIONS:" → "Sample:"
    text = re.sub(r'^(\* *)SAMPLE RESTRICTIONS:', r'\1Sample:', text, flags=re.MULTILINE)

    # Clean up di statements that sound AI-generated
    text = re.sub(r'di "PART \d+: SCRUTINY SUMMARY.*"', 'di "Summary"', text)
    text = re.sub(r'di "SCRUTINY SUMMARY.*"', 'di "Summary"', text)
    text = re.sub(r'di "STEERING DECISION.*"', 'di "Next steps:"', text)
    text = re.sub(r'di "INTERPRETATION GUIDE:?"', 'di "Interpretation:"', text)
    text = re.sub(r'di "SCRUTINY:', 'di "Check:', text)
    text = re.sub(r'di as error "SCRUTINY:', 'di as error "Check:', text)
    text = re.sub(r'di as error "SCRUTINY FAILURE:', 'di as error "Warning:', text)
    text = re.sub(r'"CRITICAL SCRUTINY"', '"Consistency check"', text)
    text = re.sub(r'FINAL SCRUTINY AND RESEARCH READINESS ASSESSMENT',
                  'Final assessment', text)

    # Clean section header comments referencing SCRUTINY
    text = re.sub(r'\* --- Part \d+: SCRUTINY SUMMARY ---',
                  '* --- Summary ---', text)
    text = re.sub(r'\* --- .*SCRUTINY SUMMARY.*---',
                  '* --- Summary ---', text)
    text = re.sub(r'\* --- .*STEERING DECISION.*---',
                  '* --- Next steps ---', text)
    text = re.sub(r'\* --- .*INTERPRETATION GUIDE.*---',
                  '* --- Interpretation ---', text)

    return text


def clean_triple_blank_lines(text):
    """Collapse 3+ blank lines to 2."""
    text = re.sub(r'\n{4,}', '\n\n\n', text)
    return text


def truncate_long_section_headers(text):
    """Cap * --- ... --- lines at reasonable length."""
    lines = text.split('\n')
    for i, line in enumerate(lines):
        if line.startswith('* ---') and len(line) > 100:
            # Find a natural break point within first ~90 chars
            header = line[:95]
            # Try to cut at last dash-separator, comma, or paren
            for sep in [' — ', ' - ', ', ', ' (']:
                cut = header.rfind(sep)
                if cut >= 30:
                    lines[i] = header[:cut].rstrip() + ' ---'
                    break
            else:
                # Just hard-truncate
                lines[i] = header.rstrip() + ' ---'
    return '\n'.join(lines)


def clean_file(filepath):
    fname = os.path.basename(filepath)
    if fname in SKIP:
        return False

    with open(filepath, 'r', encoding='utf-8', errors='replace') as f:
        text = f.read()

    original = text
    lines = text.split('\n')

    # Replace header if we have a new one
    if fname in HEADERS and HEADERS[fname] is not None:
        header_end = find_header_end(lines)
        if header_end > 0:
            # Find first non-blank line after header
            rest_start = header_end
            while rest_start < len(lines) and lines[rest_start].strip() == '':
                rest_start += 1
            rest = '\n'.join(lines[rest_start:])
            text = HEADERS[fname] + '\n' + rest

    # Clean section headers
    text = clean_section_headers(text)

    # Clean dashed lines
    text = clean_dashed_headers(text)

    # Remove scrutiny blocks
    text = remove_scrutiny_blocks(text)

    # Simplify verbose comment language
    text = simplify_verbose_comments(text)

    # Clean up excessive blank lines
    text = clean_triple_blank_lines(text)

    # Truncate very long section header comments
    text = truncate_long_section_headers(text)

    if text != original:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(text)
        return True
    return False


if __name__ == '__main__':
    do_files = glob.glob(os.path.join(DO_DIR, '*.do'))
    for fpath in sorted(do_files):
        fname = os.path.basename(fpath)
        if fname in SKIP:
            print(f"  SKIP: {fname}")
            continue
        changed = clean_file(fpath)
        print(f"  {'CLEANED' if changed else 'no change'}: {fname}")
    print("Done.")
