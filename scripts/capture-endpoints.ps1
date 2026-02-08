<#
.SYNOPSIS
  One-shot snapshot of unique remote endpoints for a process.

.EXAMPLE
  .\capture-endpoints.ps1 -ProcessName "GameProcess" -OutPath ".\results\run-summaries\endpoints.txt"
#>

[CmdletBinding()]
param(
  [string]$ProcessName = "GameProcess",
  [string]$OutPath = ".\results\run-summaries\endpoints.txt"
)

New-Item -ItemType Directory -Force -Path (Split-Path $OutPath) | Out-Null

$procs = Get-Process | Where-Object { $_.ProcessName -like "*$ProcessName*" }
if (-not $procs) { throw "No process match for '$ProcessName'." }

$targets = @()

foreach ($p in $procs) {
  $tcp = Get-NetTCPConnection -OwningProcess $p.Id -ErrorAction SilentlyContinue |
    Where-Object { $_.RemoteAddress -and $_.RemoteAddress -notin @("0.0.0.0","::") }

  foreach ($c in $tcp) {
    if ($c.RemoteAddress -match "^\d{1,3}(\.\d{1,3}){3}$") {
      $targets += [PSCustomObject]@{
        process     = $p.ProcessName
        protocol    = "TCP"
        remote_ip   = $c.RemoteAddress
        remote_port = [int]$c.RemotePort
      }
    }
  }
}

$targets = $targets | Sort-Object process,protocol,remote_ip,remote_port -Unique

"process,protocol,remote_ip,remote_port" | Out-File -Encoding utf8 $OutPath
$targets | ForEach-Object {
  "$($_.process),$($_.protocol),$($_.remote_ip),$($_.remote_port)"
} | Out-File -Append -Encoding utf8 $OutPath

Write-Host "Saved: $OutPath"
