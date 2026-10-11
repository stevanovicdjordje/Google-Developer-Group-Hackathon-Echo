"""Builds the organizer demo upload files in backend/events/demo/ (fictional content):

  devfest-agenda-final-v3.pdf  the programme as a designed flyer (PDF, needs the AI to read)
  speakers.xlsx                speaker list with roles and talks (read with or without the AI)
  devfest-agenda.csv           the agenda as a plain table (works without an AI key)

Content matches the app's demo data (mobile/app/lib/data/demo_data.dart) and the seeded agenda, so
"Build with AI" → review → publish into `devfest` reproduces what the app shows. "Designing for crowded
rooms" has no room in the PDF on purpose (the review flags it, like the app's demo).

Usage: python3 -I backend/events/scripts/demo_files.py   (needs google-chrome for the PDF)
"""
import csv
import html
import io
import pathlib
import shutil
import subprocess
import sys
import tempfile
import zipfile
from xml.sax.saxutils import escape

OUT = pathlib.Path(__file__).resolve().parent.parent / "demo"

EVENT = "DevFest Belgrade 2026"
DATES = "Sunday 11 – Monday 12 October 2026"
VENUE = "Sava Centar, Belgrade"

SPEAKERS = {
    "Mara Ilić": "ML Engineer, Lumen Labs",
    "Petar Vuković": "CTO, Orbita",
    "Jana Kostić": "Product Designer, Kvadrat",
    "Luka Marković": "Staff Engineer, Nebo Cloud",
    "Sara Đorđević": "Founder, Talas AI",
    "Nikola Pavlović": "Android GDE",
}

# title, room, start, end, track, speakers, description
SESSIONS = [
    ("Registration & coffee", "Glavna sala", "09:00", "09:45", "", [], ""),
    ("On-device AI: when the model lives in your pocket", "Glavna sala", "10:00", "10:45", "AI", ["Mara Ilić"],
     "What changes in product design, cost and privacy when inference moves from the cloud to the phone."),
    ("Scaling event-driven backends on a startup budget", "Sala A", "11:00", "11:40", "Backend", ["Luka Marković"],
     "Queues, idempotency and the boring tricks that keep costs flat."),
    ("Designing for crowded rooms", "", "11:00", "12:30", "Design", ["Jana Kostić"],
     "Hands-on workshop: one-handed UX for people standing in a hallway."),
    ("Lunch", "Glavna sala", "12:30", "13:30", "", [], ""),
    ("Compose, Flutter, or both? A pragmatic take", "Sala A", "13:30", "14:10", "Mobile", ["Nikola Pavlović"],
     "Lessons from shipping the same app twice."),
    ("From prototype to paying customers with LLMs", "Glavna sala", "14:30", "15:15", "AI", ["Sara Đorđević", "Petar Vuković"],
     "Panel: pricing, evaluation and what customers actually pay for."),
]


def pdf_html():
    rows = []
    for title, room, start, end, track, speakers, desc in SESSIONS:
        who = "".join(f"<div class=who>{html.escape(n)} <span>· {html.escape(SPEAKERS[n])}</span></div>" for n in speakers)
        tag = f"<span class=track>{html.escape(track)}</span>" if track else ""
        where = html.escape(room) if room else "<i>room to be announced</i>"
        cls = "slot break" if not speakers else "slot"
        rows.append(f"""<div class="{cls}"><div class=time>{start}<br><small>{end}</small></div>
<div class=body><div class=title>{html.escape(title)} {tag}</div>{who}
{f'<div class=desc>{html.escape(desc)}</div>' if desc else ''}<div class=room>{where}</div></div></div>""")
    return f"""<!doctype html><html><head><meta charset=utf-8><style>
@page {{ size: A4; margin: 16mm 14mm; }}
body {{ font-family: 'DejaVu Sans', Arial, sans-serif; color: #1b1f2a; }}
header {{ background: #1f3cff; color: #fff; border-radius: 14px; padding: 18px 22px; margin-bottom: 16px; }}
header h1 {{ margin: 0 0 4px; font-size: 26px; }} header p {{ margin: 0; opacity: .9; }}
h2 {{ font-size: 15px; letter-spacing: .08em; text-transform: uppercase; color: #5a6275; margin: 14px 0 8px; }}
.slot {{ display: flex; gap: 14px; padding: 10px 0; border-bottom: 1px solid #e3e6ee; break-inside: avoid; }}
.time {{ width: 56px; font-weight: 700; font-size: 15px; }} .time small {{ color: #8a90a0; font-weight: 400; }}
.title {{ font-weight: 700; font-size: 15px; }} .track {{ font-size: 10px; background: #eef1ff; color: #1f3cff;
  border-radius: 8px; padding: 1px 7px; margin-left: 6px; vertical-align: middle; }}
.who {{ font-size: 13px; margin-top: 3px; }} .who span {{ color: #5a6275; }}
.desc {{ font-size: 12px; color: #444b5c; margin-top: 4px; }} .room {{ font-size: 12px; color: #1f3cff; margin-top: 4px; }}
.break .title {{ color: #5a6275; font-weight: 600; }}
footer {{ margin-top: 18px; font-size: 11px; color: #8a90a0; }}
</style></head><body>
<header><h1>{EVENT}</h1><p>{DATES} · {VENUE}</p></header>
<h2>Programme · Day 1 · Sunday 11 October</h2>
{''.join(rows)}
<footer>Day 2 (Monday 12 October) is the community day: workshops by local groups, schedule on the website.
Final version v3. All names are fictional.</footer>
</body></html>"""


def make_pdf(path):
    chrome = shutil.which("google-chrome") or shutil.which("chromium") or shutil.which("chromium-browser")
    if not chrome:
        sys.exit("google-chrome not found (needed for the PDF)")
    with tempfile.TemporaryDirectory() as tmp:
        src = pathlib.Path(tmp) / "agenda.html"
        src.write_text(pdf_html(), encoding="utf-8")
        subprocess.run([chrome, "--headless=new", "--no-pdf-header-footer", f"--user-data-dir={tmp}/profile",
                        f"--print-to-pdf={path}", src.as_uri()], check=True, capture_output=True)


def make_xlsx(path, rows, sheet="Speakers"):
    """A minimal valid XLSX with inline strings (opens in Excel, Sheets, LibreOffice)."""
    def col(i):
        s = ""
        i += 1
        while i:
            i, r = divmod(i - 1, 26)
            s = chr(65 + r) + s
        return s
    xml_rows = []
    for r, row in enumerate(rows, 1):
        cells = "".join(f'<c r="{col(c)}{r}" t="inlineStr"><is><t>{escape(v)}</t></is></c>' for c, v in enumerate(row))
        xml_rows.append(f'<row r="{r}">{cells}</row>')
    files = {
        "[Content_Types].xml": '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
        '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
        '<Default Extension="xml" ContentType="application/xml"/>'
        '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
        '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/></Types>',
        "_rels/.rels": '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>',
        "xl/workbook.xml": '<?xml version="1.0" encoding="UTF-8"?><workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
        'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
        f'<sheets><sheet name="{sheet}" sheetId="1" r:id="rId1"/></sheets></workbook>',
        "xl/_rels/workbook.xml.rels": '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/></Relationships>',
        "xl/worksheets/sheet1.xml": '<?xml version="1.0" encoding="UTF-8"?><worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
        f'<sheetData>{"".join(xml_rows)}</sheetData></worksheet>',
    }
    with zipfile.ZipFile(path, "w", zipfile.ZIP_DEFLATED) as z:
        for name, body in files.items():
            z.writestr(name, body)


def main():
    OUT.mkdir(exist_ok=True)
    make_pdf(OUT / "devfest-agenda-final-v3.pdf")

    talks = {}
    for title, *_, speakers, _desc in SESSIONS:
        for n in speakers:
            talks.setdefault(n, []).append(title)
    make_xlsx(OUT / "speakers.xlsx", [["Name", "Company", "Talk"]] +
              [[n, role, "; ".join(talks.get(n, []))] for n, role in SPEAKERS.items()])

    buf = io.StringIO()
    w = csv.writer(buf, lineterminator="\n")
    w.writerow(["Title", "Stage", "Day", "Start", "End", "Track", "Speaker", "Description"])
    for title, room, start, end, track, speakers, desc in SESSIONS:
        w.writerow([title, room, "11.10.2026.", start, end, track,
                    " & ".join(f"{n} ({SPEAKERS[n]})" for n in speakers), desc])
    (OUT / "devfest-agenda.csv").write_text(buf.getvalue(), encoding="utf-8")
    for p in sorted(OUT.iterdir()):
        print(f"{p.name:32} {p.stat().st_size:>8} bytes")


if __name__ == "__main__":
    main()
