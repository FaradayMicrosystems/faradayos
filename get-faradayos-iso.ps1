# Downloads the FaradayOS test ISO from the iso-test branch and joins it into one verified file.
# In PowerShell:  irm https://raw.githubusercontent.com/FaradayMicrosystems/faradayos/iso-test/get-faradayos-iso.ps1 | iex
$ErrorActionPreference = 'Stop'
$Base = 'https://raw.githubusercontent.com/FaradayMicrosystems/faradayos/iso-test'
$Iso = 'FaradayOSv0.0.1-test.iso'
$N = 69
$Expected = '2e9b72ff23ee22ac3724ecfd56b82a911b221e889de119c242c3456b387d1ce8'
$Parts = Join-Path (Get-Location) 'faradayos-iso-parts'
New-Item -ItemType Directory -Force -Path $Parts | Out-Null
$Out = [IO.File]::Create((Join-Path (Get-Location) $Iso))
try {
  for ($i = 0; $i -lt $N; $i++) {
    $f = '{0}.p{1:D2}' -f $Iso, $i
    $p = Join-Path $Parts $f
    Write-Host "Downloading part $($i+1) of $N"
    Invoke-WebRequest -Uri "$Base/$f" -OutFile $p -UseBasicParsing
    $in = [IO.File]::OpenRead($p); $in.CopyTo($Out); $in.Close()
    Remove-Item $p
  }
} finally { $Out.Close() }
Remove-Item $Parts -Recurse
$h = (Get-FileHash $Iso -Algorithm SHA256).Hash.ToLower()
if ($h -eq $Expected) { Write-Host "Done: checksum OK, $Iso is ready." } else { Write-Host "Checksum FAILED. Run again." ; exit 1 }
