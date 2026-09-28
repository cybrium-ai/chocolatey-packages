$ErrorActionPreference = 'Stop'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$exePath  = Join-Path $toolsDir 'cywave.exe'

# Download the signed release binary and verify its SHA-256 checksum.
# Chocolatey auto-shims the .exe left in tools/ onto PATH as 'cywave'.
Get-ChocolateyWebFile -PackageName 'cywave' `
  -FileFullPath $exePath `
  -Url64bit 'https://github.com/cybrium-ai/cywave/releases/download/v0.2.1/cywave-windows-amd64.exe' `
  -Checksum64 'aeb03cec897383b72fdf18cfaef78eb3df53e069e7eb2fbcf9b3362edab3094d' `
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
