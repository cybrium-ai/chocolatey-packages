$ErrorActionPreference = 'Stop'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$exePath  = Join-Path $toolsDir 'cyprobe.exe'

# Download the signed release binary and verify its SHA-256 checksum.
# Chocolatey auto-shims the .exe left in tools/ onto PATH as 'cyprobe'.
Get-ChocolateyWebFile -PackageName 'cyprobe' `
  -FileFullPath $exePath `
  -Url64bit 'https://github.com/cybrium-ai/cyprobe/releases/download/v0.2.4/cyprobe-windows-amd64.exe' `
  -Checksum64 'dee0977ba1a44dde7d89f65753ab076f0ab3fd9431e3cef07d560a2901d0dc8d' `
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
