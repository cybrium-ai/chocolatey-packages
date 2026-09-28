#!/usr/bin/env bash
# Render + pack every Chocolatey package listed in packages.tsv.
# Columns: id  version  sha256(windows-amd64.exe)  title | summary | description
# Rules enforced here (the reason the May 2026 batch was rejected):
#   - install scripts must be pure ASCII (Windows PowerShell 5.1 reads BOM-less
#     files as ANSI; a UTF-8 em-dash decodes to a curly quote and breaks parsing)
#   - every script must parse cleanly under pwsh before packing
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p dist
while IFS=$'\t' read -r id version sha meta; do
  [[ -z "$id" || "$id" == \#* ]] && continue
  IFS='|' read -r title summary description <<<"$meta"
  title=$(echo "$title" | sed 's/^ *//;s/ *$//'); summary=$(echo "$summary" | sed 's/^ *//;s/ *$//'); description=$(echo "$description" | sed 's/^ *//;s/ *$//')
  mkdir -p "$id/tools"
  sed -e "s|__ID__|$id|g" -e "s|__VERSION__|$version|g" -e "s|__SHA256__|$sha|g" \
      templates/chocolateyinstall.ps1 > "$id/tools/chocolateyinstall.ps1"
  sed -e "s|__ID__|$id|g" -e "s|__VERSION__|$version|g" -e "s|__TITLE__|$title|g" \
      -e "s|__SUMMARY__|$summary|g" -e "s|__DESCRIPTION__|$description|g" \
      templates/package.nuspec > "$id/$id.nuspec"
  if perl -ne 'print "$.: $_" if /[^\x00-\x7F]/' "$id/tools/chocolateyinstall.ps1" | grep .; then
    echo "FAIL: non-ASCII bytes in $id/tools/chocolateyinstall.ps1" >&2; exit 1
  fi
  pwsh -NoProfile -Command '
    $t=$null;$e=$null
    [System.Management.Automation.Language.Parser]::ParseFile("'"$PWD/$id/tools/chocolateyinstall.ps1"'",[ref]$t,[ref]$e) | Out-Null
    if ($e.Count) { $e | ForEach-Object { Write-Error $_.Message }; exit 1 }'
  python3 pack.py "$id" dist >/dev/null
  echo "packed $id $version"
done < packages.tsv
ls -la dist/*.nupkg
