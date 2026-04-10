import pdfplumber, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')
with pdfplumber.open(r"D:\Stata Data\labor_signaling_project\docs\related_work\Sztutmen_Signaling\jmp_sztutman.pdf") as pdf:
    total = len(pdf.pages)
    print(f"Total pages: {total}")
    # Appendix C empirical tables typically pages 50-75
    target_pages = list(range(49, 75))
    for i in target_pages:
        if i >= total: break
        print(f"\n===PAGE {i+1}===")
        t = pdf.pages[i].extract_text()
        if t:
            print(t[:4000])
