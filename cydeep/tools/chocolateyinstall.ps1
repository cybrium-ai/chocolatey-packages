$ErrorActionPreference = 'Stop'
$toolsDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$exePath  = Join-Path $toolsDir 'cydeep.exe'

# Download the signed release binary and verify its SHA-256 checksum.
# Chocolatey auto-shims the .exe left in tools/ onto PATH as 'cydeep'.
Get-ChocolateyWebFile -PackageName 'cydeep' `
  -FileFullPath $exePath `
  -Url64bit 'https://github.com/cybrium-ai/cydeep/releases/download/v0.1.6/cydeep-windows-amd64.exe' `
  -Checksum64 '81a0510cfb6adde38d6a7bbd81e2e03bfddfe6cd0f962fd3a40dcb369dfa64d8' `
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
