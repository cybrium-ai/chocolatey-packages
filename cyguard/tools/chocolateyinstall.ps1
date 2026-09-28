$ErrorActionPreference = 'Stop'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$exePath  = Join-Path $toolsDir 'cyguard.exe'

# Download the signed release binary and verify its SHA-256 checksum.
# Chocolatey auto-shims the .exe left in tools/ onto PATH as 'cyguard'.
Get-ChocolateyWebFile -PackageName 'cyguard' `
  -FileFullPath $exePath `
  -Url64bit 'https://github.com/cybrium-ai/cyguard/releases/download/v0.1.6/cyguard-windows-amd64.exe' `
  -Checksum64 '59842827983d1fc96fd6a7ec089377f25144eb1ed3ab441266f4440bef645a94' `
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
