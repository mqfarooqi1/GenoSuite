# Stage the self-contained GenoSuite bundle (portable R + app + launcher + icon).
# Run:  powershell -ExecutionPolicy Bypass -File packaging\build.ps1
param(
  [string]$Root  = "C:\Users\faroo\Desktop\python_code\GenoSuite",
  [string]$RHome = "C:\Program Files\R\R-4.5.2"
)
$ErrorActionPreference = "Stop"
$rscript = Join-Path $RHome "bin\Rscript.exe"
$dist = Join-Path $Root "dist\GenoSuite"
$pkg  = Join-Path $Root "packaging"

Write-Host "==> clean"
if (Test-Path (Join-Path $Root "dist")) { Remove-Item (Join-Path $Root "dist") -Recurse -Force }
New-Item -ItemType Directory -Force $dist | Out-Null

Write-Host "==> copy R from $RHome (robocopy; this is the big step)"
$null = robocopy $RHome (Join-Path $dist "R") /E /NFL /NDL /NJH /NJS /NP
if ($LASTEXITCODE -ge 8) { throw "robocopy R failed ($LASTEXITCODE)" }
$global:LASTEXITCODE = 0

Write-Host "==> copy app"
New-Item -ItemType Directory -Force (Join-Path $dist "app") | Out-Null
Copy-Item (Join-Path $Root "app\app.R") (Join-Path $dist "app\app.R")

Write-Host "==> copy launcher"
Copy-Item (Join-Path $pkg "launcher.R")   $dist
Copy-Item (Join-Path $pkg "GenoSuite.vbs") $dist

Write-Host "==> generate icon"
$png = Join-Path $dist "GenoSuite.png"
& $rscript (Join-Path $pkg "make_icon.R") $png | Write-Host
$bytes = [System.IO.File]::ReadAllBytes($png)
$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($ms)
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]1)        # ICONDIR
$bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0); $bw.Write([byte]0)
$bw.Write([uint16]1); $bw.Write([uint16]32)                              # planes, bpp
$bw.Write([uint32]$bytes.Length); $bw.Write([uint32]22)                  # size, offset
$bw.Write($bytes); $bw.Flush()
[System.IO.File]::WriteAllBytes((Join-Path $dist "GenoSuite.ico"), $ms.ToArray())
Remove-Item $png
Write-Host "icon written"

Write-Host "==> stage package library"
& $rscript (Join-Path $pkg "stage_library.R") $dist | Write-Host

$sz = (Get-ChildItem $dist -Recurse -File | Measure-Object Length -Sum).Sum / 1MB
Write-Host ("==> DONE staging: {0:N0} MB at {1}" -f $sz, $dist)
