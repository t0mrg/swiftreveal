#!/usr/bin/env python3
"""Validate files produced by SwiftReveal --powerpoint-test, using the Python stdlib."""
import json
import posixpath
import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from zipfile import ZipFile

NS = {"a": "http://schemas.openxmlformats.org/drawingml/2006/main",
      "p": "http://schemas.openxmlformats.org/presentationml/2006/main",
      "r": "http://schemas.openxmlformats.org/package/2006/relationships"}
root = Path(sys.argv[1] if len(sys.argv) > 1 else "/tmp/SwiftReveal-PowerPoint-QA")
checks = []


def check(condition, message):
    if not condition:
        raise AssertionError(message)
    checks.append(message)


for filename, count, size in [("Sample.pptx", 8, (12192000, 6858000)),
                              ("All-Layouts-Six-by-Four.pptx", 9, (12344400, 8229600))]:
    with ZipFile(root / filename) as archive:
        check(archive.testzip() is None, filename + ": ZIP integrity")
        names = archive.namelist()
        docs = {n: ET.fromstring(archive.read(n)) for n in names if n.endswith((".xml", ".rels"))}
        for name, doc in docs.items():
            if name.endswith(".rels"):
                folder = posixpath.dirname(posixpath.dirname(name))
                for rel in doc:
                    if rel.get("TargetMode") == "External":
                        continue
                    target = rel.get("Target", "")
                    resolved = posixpath.normpath(posixpath.join(folder, target)) if not target.startswith("/") else target.lstrip("/")
                    check(resolved in names, filename + ": relationship " + resolved)
            for paragraph in doc.findall(".//a:p", NS):
                check(len(paragraph.findall("a:pPr", NS)) <= 1, filename + ": valid rich-text paragraph")
        presentation = docs["ppt/presentation.xml"]
        dimensions = presentation.find("p:sldSz", NS)
        check((int(dimensions.get("cx")), int(dimensions.get("cy"))) == size, filename + ": canvas dimensions")
        slides = [docs[f"ppt/slides/slide{i}.xml"] for i in range(1, count + 1)]
        check(len(presentation.findall("p:sldIdLst/p:sldId", NS)) == count, filename + ": slide count")
        layouts = [d for n, d in docs.items() if n.startswith("ppt/slideLayouts/slideLayout") and n.endswith(".xml")]
        named = [d for d in layouts if d.find("p:cSld", NS).get("name", "").startswith("SwiftReveal")]
        check(len(named) == 8, filename + ": eight named layouts")
        check(all(d.findall(".//p:ph", NS) for d in named), filename + ": editable layout placeholders")
        check(any(d.findall('.//p:ph[@type="pic"]', NS) for d in named), filename + ": native picture placeholder")
        statement = next(d for d in named if d.find('p:cSld', NS).get('name') == 'SwiftReveal · Statement')
        centered = [s for s in statement.findall('.//p:sp', NS) if s.find('.//p:ph[@type="body"]', NS) is not None]
        check(centered[0].find('.//a:bodyPr', NS).get('anchor') == 'ctr', filename + ": statement placeholder is vertically centered")
        check(all(d.findall(".//p:sp/p:txBody", NS) for d in slides), filename + ": native editable slide text")
        check(any(d.findall(".//a:tbl", NS) for d in slides), filename + ": editable native table")
        check(bool(slides[0].findall(".//a:gradFill", NS)), filename + ": native cover gradient")
        check(slides[0].find('.//a:latin', NS).get('typeface') == 'Helvetica Neue', filename + ": explicit export font")
        accent = docs['ppt/theme/theme1.xml'].find('.//a:clrScheme/a:accent1/a:srgbClr', NS)
        check(accent.get('val') == ('2A78D6' if count == 8 else '087F8C'), filename + ": reusable theme palette")
        check(not any(d.findall(".//p:ph", NS) for d in slides), filename + ": no inherited empty placeholder artifacts")
        if count == 9:
            check(len(slides[1].findall(".//a:buChar", NS)) == 2, "Rich text keeps both native bullets")
            overlay = next(s for s in slides[2].findall(".//p:sp", NS) if s.find("p:nvSpPr/p:cNvPr", NS).get("name") == "Translucent background overlay")
            check(overlay.find("p:spPr/a:solidFill/a:srgbClr/a:alpha", NS).get("val") == "45000", "Background overlay has 45% native opacity")
            check(bool(slides[2].findall(".//p:pic", NS)), "Overlay has a separate background picture")
            check(any(n.endswith(".svg") for n in names), "Mermaid is embedded as SVG")
            check(bool(slides[8].findall(".//{http://schemas.microsoft.com/office/drawing/2016/SVG/main}svgBlip")), "Diagram has native SVG plus PNG fallback")
            check("Speaker notes survive PowerPoint export." in archive.read("ppt/notesSlides/notesSlide1.xml").decode(), "Speaker notes survive")
            table = slides[6].find(".//a:tbl", NS)
            measured = json.loads((root / "PowerPoint-Slide-7.json").read_text())
            source = next(o for o in measured["objects"] if o["kind"] == "table")
            widths = [int(c.get("w")) for c in table.findall("a:tblGrid/a:gridCol", NS)]
            check(all(abs(a - b * 914400) <= 1 for a, b in zip(widths, source["colW"])), "Table column widths match WebKit measurements")

(root / "powerpoint-structure-results.json").write_text(json.dumps({"passed": True, "checks": checks}, indent=2))
print(f"PowerPoint structure passed: {len(checks)} assertions")
