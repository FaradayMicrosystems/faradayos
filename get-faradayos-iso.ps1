# Downloads the FaradayOS test ISO from the iso-test branch and joins it into one verified file (Windows PowerShell).
#   irm https://raw.githubusercontent.com/FaradayMicrosystems/faradayos/iso-test/get-faradayos-iso.ps1 | iex
# Every piece is checked against its own checksum; damaged pieces are re-downloaded. Safe to run again.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
$base = 'https://raw.githubusercontent.com/FaradayMicrosystems/faradayos/iso-test'
$iso  = 'FaradayOSv0.0.1-test.iso'
$dir  = Join-Path $PWD 'faradayos-iso-parts'
New-Item -ItemType Directory -Force $dir | Out-Null
$list = (Invoke-WebRequest "$base/pieces.sha256" -UseBasicParsing).Content -split "`n" | Where-Object { $_.Trim() }
$n = $list.Count; $i = 0
foreach ($line in $list) {
  $i++; $sum, $p = $line.Trim() -split '\s+', 2; $f = Join-Path $dir $p
  if ((Test-Path $f) -and ((Get-FileHash $f -Algorithm SHA256).Hash.ToLower() -eq $sum)) { continue }
  $ok = $false
  for ($try = 1; $try -le 3 -and -not $ok; $try++) {
    Write-Host "Downloading piece $i of $n (attempt $try)"
    Remove-Item $f -ErrorAction SilentlyContinue
    try { Invoke-WebRequest "$base/$p" -OutFile $f -UseBasicParsing } catch { }
    $ok = (Test-Path $f) -and ((Get-FileHash $f -Algorithm SHA256).Hash.ToLower() -eq $sum)
  }
  if (-not $ok) { Write-Host "Piece $p failed 3 times. Check your connection and run the script again."; return }
}
Write-Host "All $n pieces verified. Joining..."
$out = [IO.File]::Create((Join-Path $PWD $iso))
Get-ChildItem $dir -Filter "$iso.p*" | Sort-Object Name | ForEach-Object { $in = [IO.File]::OpenRead($_.FullName); $in.CopyTo($out); $in.Close() }
$out.Close()
if ((Get-FileHash $iso -Algorithm SHA256).Hash.ToLower() -eq '2e9b72ff23ee22ac3724ecfd56b82a911b221e889de119c242c3456b387d1ce8') {
  Remove-Item -Recurse $dir; Write-Host "Done: $(Join-Path $PWD $iso)"
} else { Write-Host 'ISO checksum FAILED. Run the script again; it will re-check every piece.' }
