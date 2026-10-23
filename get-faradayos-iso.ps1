# Downloads the FaradayOS test ISO from the iso-test branch and joins it into one verified file (Windows PowerShell).
#   irm https://raw.githubusercontent.com/FaradayMicrosystems/faradayos/iso-test/get-faradayos-iso.ps1 | iex
$ErrorActionPreference = 'Stop'
$base = 'https://raw.githubusercontent.com/FaradayMicrosystems/faradayos/iso-test'
$iso  = 'FaradayOSv0.0.1-test.iso'
$n    = 69
New-Item -ItemType Directory -Force faradayos-iso-parts | Out-Null
$out = [IO.File]::Create((Join-Path $PWD $iso))
for ($i = 0; $i -lt $n; $i++) {
  $p = '{0}.p{1:D2}' -f $iso, $i; $f = Join-Path faradayos-iso-parts $p
  if (-not (Test-Path $f)) { Write-Host "Downloading piece $($i+1) of $n"; Invoke-WebRequest "$base/$p" -OutFile $f -UseBasicParsing }
  $bytes = [IO.File]::OpenRead((Resolve-Path $f)); $bytes.CopyTo($out); $bytes.Close()
}
$out.Close()
$h = (Get-FileHash $iso -Algorithm SHA256).Hash.ToLower()
if ($h -eq '2e9b72ff23ee22ac3724ecfd56b82a911b221e889de119c242c3456b387d1ce8') { Remove-Item -Recurse faradayos-iso-parts; Write-Host "Done: $PWD\$iso" } else { Write-Host 'Checksum FAILED: delete faradayos-iso-parts and run again.' }
