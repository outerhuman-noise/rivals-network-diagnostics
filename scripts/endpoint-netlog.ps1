<#
.SYNOPSIS
  Logs remote endpoints used by a target process and measures TCP connect timing per endpoint.

.DESCRIPTION
  Enumerates remote IP:port targets for the specified process name using Get-NetTCPConnection and Get-NetUDPEndpoint.
  For TCP targets, performs repeated TCP connect attempts (handshake timing) and logs success/fail + min/avg/max ms.
  For UDP targets, logs presence only (Windows often doesn't expose reliable remote UDP for many apps).

.PARAMETER ProcessName
  Part of the process name (without .exe), eg "GameProcess".

.PARAMETER IntervalSec
  Seconds between scans.

.PARAMETER TrialsPerTarget
  TCP connect attempts per endpoint per scan.

.PARAMETER TimeoutSec
  Timeout per TCP connect attempt.

.PARAMETER LogPath
  CSV output path (recommended: repo-local under data/raw).

.EXAMPLE
  .\endpoint-netlog.ps1 -ProcessName "GameProcess" -LogPath ".\data\raw\netlog.csv"
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$false)][string]$ProcessName = "GameProcess",
  [Parameter(Mandatory=$false)][int]$IntervalSec = 5,
  [Parameter(Mandatory=$false)][int]$TrialsPerTarget = 5,
  [Parameter(Mandatory=$false)][int]$TimeoutSec = 2,
  [Parameter(Mandatory=$false)][string]$LogPath = ".\data\raw\netlog.csv"
)

# Ensure log directory exists
New-Item -ItemType Directory -Force -Path (Split-Path $LogPath) | Out-Null

# Init CSV
"timestamp,process,remote_ip,remote_port,protocol,tests,success,fail,avg_ms,min_ms,max_ms,status" |
  Out-File -Encoding utf8 $LogPath

Write-Host "Logging to: $LogPath"
Write-Host "Press Ctrl+C to stop."

function Test-TcpPortStats {
  param(
    [Parameter(Mandatory=$true)][string]$RemoteIP,
    [Parameter(Mandatory=$true)][int]$RemotePort,
    [int]$Trials = 5,
    [int]$TimeoutSeconds = 2
  )

  $times = New-Object System.Collections.Generic.List[double]
  $success = 0
  $fail = 0

  for ($i = 0; $i -lt $Trials; $i++) {
    $client = New-Object System.Net.Sockets.TcpClient
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    try {
      $iar = $client.BeginConnect($RemoteIP, $RemotePort, $null, $null)
      if (-not $iar.AsyncWaitHandle.WaitOne([TimeSpan]::FromSeconds($TimeoutSeconds), $false)) {
        throw [System.TimeoutException]::new("TCP connect timeout")
      }
      $client.EndConnect($iar)
      $sw.Stop()

      $success++
      $times.Add([math]::Round($sw.Elapsed.TotalMilliseconds, 1)) | Out-Null
    }
    catch {
      $sw.Stop()
      $fail++
    }
    finally {
      try { $client.Close() } catch {}
    }

    Start-Sleep -Milliseconds 200
  }

  if ($success -gt 0) {
    $avg = [math]::Round(($times | Measure-Object -Average).Average, 1)
    $min = ($times | Measure-Object -Minimum).Minimum
    $max = ($times | Measure-Object -Maximum).Maximum
    return @{
      success = $success
      fail    = $fail
      avg_ms  = $avg
      min_ms  = $min
      max_ms  = $max
      status  = "OK"
    }
  } else {
    return @{
      success = 0
      fail    = $fail
      avg_ms  = $null
      min_ms  = $null
      max_ms  = $null
      status  = "TCP_CONNECT_FAIL"
    }
  }
}

while ($true) {
  $ts = (Get-Date).ToString("s")

  # Find matching processes (partial match)
  $procs = Get-Process | Where-Object { $_.ProcessName -like "*$ProcessName*" }

  if (-not $procs) {
    Write-Host "[$ts] No process match for '$ProcessName' yet..."
    Start-Sleep -Seconds $IntervalSec
    continue
  }

  foreach ($p in $procs) {
    $tcp = Get-NetTCPConnection -OwningProcess $p.Id -ErrorAction SilentlyContinue |
      Where-Object { $_.RemoteAddress -and $_.RemoteAddress -notin @("0.0.0.0","::") }

    $udp = Get-NetUDPEndpoint -OwningProcess $p.Id -ErrorAction SilentlyContinue |
      Where-Object { $_.RemoteAddress -and $_.RemoteAddress -notin @("0.0.0.0","::") }

    $targets = @()

    foreach ($c in $tcp) {
      if ($c.RemoteAddress -match "^\d{1,3}(\.\d{1,3}){3}$") {
        $targets += [PSCustomObject]@{
          RemoteIP   = $c.RemoteAddress
          RemotePort = [int]$c.RemotePort
          Protocol   = "TCP"
        }
      }
    }

    foreach ($e in $udp) {
      if ($e.RemoteAddress -match "^\d{1,3}(\.\d{1,3}){3}$") {
        $targets += [PSCustomObject]@{
          RemoteIP   = $e.RemoteAddress
          RemotePort = [int]$e.RemotePort
          Protocol   = "UDP"
        }
      }
    }

    $targets = $targets | Sort-Object RemoteIP,RemotePort,Protocol -Unique

    foreach ($t in $targets) {
      if ($t.Protocol -eq "TCP") {
        $r = Test-TcpPortStats -RemoteIP $t.RemoteIP -RemotePort $t.RemotePort -Trials $TrialsPerTarget -TimeoutSeconds $TimeoutSec
        "$ts,$($p.ProcessName),$($t.RemoteIP),$($t.RemotePort),TCP,$TrialsPerTarget,$($r.success),$($r.fail),$($r.avg_ms),$($r.min_ms),$($r.max_ms),$($r.status)" |
          Out-File -Append -Encoding utf8 $LogPath
      } else {
        "$ts,$($p.ProcessName),$($t.RemoteIP),$($t.RemotePort),UDP,0,0,0,,,,UDP_PRESENT_ONLY" |
          Out-File -Append -Encoding utf8 $LogPath
      }
    }
  }

  Start-Sleep -Seconds $IntervalSec
}
