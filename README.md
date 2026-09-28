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
4. Push over IPv4 with curl. push.chocolatey.org sits behind Cloudflare and the IPv6 path from the Mac hangs; both Mono nuget and `dotnet nuget push` pick IPv6 and die with socket errors, while curl `-4` works:

   ```bash
   for p in dist/*.nupkg; do
     curl -4 -sS -o /dev/null -w "$p HTTP %{http_code}\n" -X PUT \
       -H "X-NuGet-ApiKey: $(pbpaste)" \
       -F "package=@$p;type=application/octet-stream" \
       https://push.chocolatey.org/api/v2/package/
   done
   ```
   HTTP 201 means accepted, 403 means bad key, 409 means the version already exists.
5. Watch the package page; respond on the review-comments box within 15 days if the verifier flags anything.

## Hard rules (learned the hard way)

- Install scripts are pure ASCII. Windows PowerShell 5.1 reads BOM-less files as
  the ANSI code page. A UTF-8 em-dash becomes a curly quote, which PowerShell
  treats as a string delimiter, and the script fails to parse. This is what
  got the entire May 2026 batch rejected. `build.sh` refuses to pack if any
  non-ASCII byte is present and runs the PowerShell parser over every script.
- `owners` / `authors` are `Cybrium Inc`, the legal entity.
- Rejected package versions cannot be re-pushed. Bump the version instead.
