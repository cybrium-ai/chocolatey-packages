#!/usr/bin/env python3
"""Pack a Chocolatey package directory into a .nupkg (OPC zip) without NuGet.

Mono's nuget.exe rejects the Chocolatey 2015/06 nuspec schema, and choco.exe
is Windows-only, so this mirrors exactly what `choco pack` emits:
  <id>.nuspec, tools/**, [Content_Types].xml, _rels/.rels, core-properties psmdcp
"""
import sys, uuid, zipfile, pathlib, re
from xml.sax.saxutils import escape

pkg_dir = pathlib.Path(sys.argv[1]).resolve()
out_dir = pathlib.Path(sys.argv[2]).resolve()
pkg_id = pkg_dir.name
nuspec = pkg_dir / f"{pkg_id}.nuspec"
text = nuspec.read_text(encoding="utf-8")

def tag(name):
    m = re.search(rf"<{name}>(.*?)</{name}>", text, re.S)
    return m.group(1).strip() if m else ""

version, authors, title, summary, tags = (tag(t) for t in ("version", "authors", "title", "summary", "tags"))
psmdcp_name = uuid.uuid4().hex
rid = lambda: "R" + uuid.uuid4().hex[:14].upper()

content_types = """<?xml version="1.0" encoding="utf-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml" />
  <Default Extension="psmdcp" ContentType="application/vnd.openxmlformats-package.core-properties+xml" />
  <Default Extension="nuspec" ContentType="application/octet" />
  <Default Extension="ps1" ContentType="application/octet" />
</Types>"""
rels = f"""<?xml version="1.0" encoding="utf-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Type="http://schemas.microsoft.com/packaging/2010/07/manifest" Target="/{pkg_id}.nuspec" Id="{rid()}" />
  <Relationship Type="http://schemas.openxmlformats.org/package/2006/relationships/metadata/core-properties" Target="/package/services/metadata/core-properties/{psmdcp_name}.psmdcp" Id="{rid()}" />
</Relationships>"""
core = f"""<?xml version="1.0" encoding="utf-8"?>
<coreProperties xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:dcterms="http://purl.org/dc/terms/" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://schemas.openxmlformats.org/package/2006/metadata/core-properties">
  <dc:creator>{escape(authors)}</dc:creator>
  <dc:description>{escape(summary)}</dc:description>
  <dc:identifier>{pkg_id}</dc:identifier>
  <version>{version}</version>
  <keywords>{escape(tags)}</keywords>
  <dc:title>{escape(title)}</dc:title>
  <lastModifiedBy>Cybrium chocolatey-packages pack.py</lastModifiedBy>
</coreProperties>"""

out_dir.mkdir(parents=True, exist_ok=True)
out = out_dir / f"{pkg_id}.{version}.nupkg"
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    z.write(nuspec, f"{pkg_id}.nuspec")
    z.writestr("[Content_Types].xml", content_types)
    z.writestr("_rels/.rels", rels)
    z.writestr(f"package/services/metadata/core-properties/{psmdcp_name}.psmdcp", core)
    for f in sorted((pkg_dir / "tools").rglob("*")):
        if f.is_file():
            z.write(f, f"tools/{f.relative_to(pkg_dir / 'tools').as_posix()}")
print(out)
