# chocolatey-packages

Source for the Cybrium packages on the Chocolatey Community Repository:
cyweb, cymail, cyguard, cyprobe, cysense, cywave, cydeep.

Each package downloads the Authenticode-signed `<tool>-windows-amd64.exe` from
the tool's GitHub release, verifies its SHA-256, checks the signature, and
leaves the binary in `tools/` so Chocolatey shims it onto PATH.

## Layout

| Path | Purpose |
|------|---------|
| `packages.tsv` | One row per package: id, version, sha256 of the Windows exe, title / summary / description |
| `templates/` | nuspec + install script templates rendered by `build.sh` |
| `<id>/` | Rendered package source (committed so Chocolatey's `packageSourceUrl` resolves) |
| `pack.py` | Builds the `.nupkg` (OPC zip) without NuGet; Mono nuget rejects the Chocolatey schema and choco.exe is Windows-only |
| `build.sh` | Render + lint + pack everything into `dist/` |

## Releasing a new version

1. Publish the tool's GitHub release with the signed `<id>-windows-amd64.exe`.
2. `shasum -a 256 <id>-windows-amd64.exe` and update the row in `packages.tsv`.
3. `./build.sh`
4. Copy the API key (a GUID) to the clipboard and push over IPv4 with curl. The key is trimmed and shape-checked first, because Chocolatey answers a malformed key with a bare 400 rather than 403. push.chocolatey.org sits behind Cloudflare and the IPv6 path from the Mac hangs, so Mono nuget and `dotnet nuget push` both fail:

   ```bash
   K="$(pbpaste | tr -d '[:space:]"')"
   [[ "$K" =~ ^[0-9a-fA-F]{8}-([0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$ ]] || { echo "clipboard is not a GUID"; exit 1; }
   for p in dist/*.nupkg; do
     curl -4 --http1.1 -sS -o /dev/null -w "$p %{http_code}\n" -X PUT \
       -H "X-NuGet-ApiKey: $K" -F "package=@$p;type=application/octet-stream" \
       https://push.chocolatey.org/api/v2/package/
   done
   unset K; pbcopy < /dev/null
   ```
   201 accepted. 400 malformed key or non-normalized version. 403 wrong key or version already in moderation. 409 version exists or basic validation failed.
5. Watch the package page; respond on the review-comments box within 15 days if the verifier flags anything.

## Hard rules (learned the hard way)

- Install scripts are pure ASCII. Windows PowerShell 5.1 reads BOM-less files as
  the ANSI code page. A UTF-8 em-dash becomes a curly quote, which PowerShell
  treats as a string delimiter, and the script fails to parse. This is what
  got the entire May 2026 batch rejected. `build.sh` refuses to pack if any
  non-ASCII byte is present and runs the PowerShell parser over every script.
- `owners` / `authors` are `Cybrium Inc`, the legal entity.
- Rejected package versions cannot be re-pushed. Bump the version instead.
