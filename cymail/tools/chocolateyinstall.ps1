$ErrorActionPreference = 'Stop'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$exePath  = Join-Path $toolsDir 'cymail.exe'

# Download the signed release binary and verify its SHA-256 checksum.
# Chocolatey auto-shims the .exe left in tools/ onto PATH as 'cymail'.
Get-ChocolateyWebFile -PackageName 'cymail' `
  -FileFullPath $exePath `
  -Url64bit 'https://github.com/cybrium-ai/cymail/releases/download/v0.7.1/cymail-windows-amd64.exe' `
  -Checksum64 '748d61e60aa63e5d851d2ef20cf31ba56e99780f61c1e8b45482feb26faa66f8' `
  -ChecksumType64 'sha256'

# Authenticode validation: the binary must carry a valid signature from Cybrium.
$sig = Get-AuthenticodeSignature -FilePath $exePath
if ($sig.Status -ne 'Valid') {
  throw "Authenticode signature status is '$($sig.Status)' - refusing to install."
}
if ($sig.SignerCertificate.Subject -inotmatch 'cybrium') {
  throw "Unexpected signer: $($sig.SignerCertificate.Subject)"
}
Write-Host "Authenticode signature verified: $($sig.SignerCertificate.Subject)"
