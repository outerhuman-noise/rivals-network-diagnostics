<#
.SYNOPSIS
  Produces a Markdown summary from a netlog CSV.

.EXAMPLE
  .\summarise-netlog.ps1 -InPath ".\data\sample\netlog_sanitised.csv" -OutPath ".\results\run-summaries\summary.md"
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$InPath,
  [Parameter(Mandatory=$true)][string]$OutPath,
  [int]$TopN = 10
)

New-Item -ItemType Directory -Force -Path (Split-Path $OutPath) | Out-Null

$rows = Import-Csv $InPath

$tcpOk = $rows | Where-Object {
  $_.protocol -eq "TCP" -and $_.status -eq "OK" -and $_.avg_ms -match '^\d'
} | ForEach-Object {
  $_.avg_ms = [double]$_.avg_ms
  $_.max_ms = if ($_.max_ms -match '^\d') { [double]$_.max_ms } else { $null }
  $_.success = [int]$_.success
  $_.fail = [int]$_.fail
  $_
}

$start = ($rows | Select-Object -First 1).timestamp
$end   = ($rows | Select-Object -Last 1).timestamp

$uniqueTargets = ($rows | Select-Object protocol,remote_ip,remote_port | Sort-Object protocol,remote_ip,remote_port -Unique).Count

$topByAvg = $tcpOk |
  Group-Object remote_ip,remote_port |
  ForEach-Object {
    $g = $_.Group
    [PSCustomObject]@{
      target = ($g[0].remote_ip + ":" + $g[0].remote_port)
      samples = $g.Count
      avg_ms = [math]::Round(($g | Measure-Object avg_ms -Average).Average, 1)
      max_ms = ($g | Measure-Object max_ms -Maximum).Maximum
      fail_total = ($g | Measure-Object fail -Sum).Sum
      success_total = ($g | Measure-Object success -Sum).Sum
    }
  } | Sort-Object avg_ms -Descending | Select-Object -First $TopN

$md = @()
$md += "# Netlog Summary"
$md += ""
$md += "- Source: `$InPath`"
$md += "- Time window: $start → $end"
$md += "- Unique targets: $uniqueTargets"
$md += ""
$md += "## Top $TopN targets by average TCP connect time"
$md += ""
$md += "| Target | Samples | Avg (ms) | Max (ms) | Success | Fail |"
$md += "|---|---:|---:|---:|---:|---:|"
foreach ($t in $topByAvg) {
  $md += "| $($t.target) | $($t.samples) | $($t.avg_ms) | $($t.max_ms) | $($t.success_total) | $($t.fail_total) |"
}
$md += ""

$md | Out-File -Encoding utf8 $OutPath
Write-Host "Wrote summary: $OutPath"
