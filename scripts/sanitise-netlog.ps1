<#
.SYNOPSIS
  Sanitises a netlog CSV by hashing IP addresses and optionally rounding timestamps.

.DESCRIPTION
  - Hashes IPv4 addresses consistently using SHA256(salt + ip) and replaces them with tokens.
  - Optionally rounds timestamps to reduce traceability.
  - Writes a new CSV intended to be safe to commit.

.NOTES
  Before running:
    $env:NETLOG_SALT = "a-long-random-string"
  Do not commit your salt.

.EXAMPLE
  .\sanitise-netlog.ps1 -InPath ".\data\raw\netlog.csv" -OutPath ".\data\sample\netlog_sanitised.csv" -RoundMinutes 10
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)][string]$InPath,
  [Parameter(Mandatory=$true)][string]$OutPath,
  [int]$RoundMinutes = 10
)

$salt = $env:NETLOG_SALT
if ([string]::IsNullOrWhiteSpace($salt)) {
  throw "Set `$env:NETLOG_SALT` to a random string before running (do not commit it)."
}

function Get-HashToken([string]$value, [string]$salt) {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($salt + "|" + $value)
  $hash  = [System.Security.Cryptography.SHA256]::Create().ComputeHash($bytes)
  ($hash | ForEach-Object { $_.ToString("x2") }) -join "" | ForEach-Object { $_.Substring(0, 10) }
}

function Is-IPv4([string]$ip) {
  $ip -match "^\d{1,3}(\.\d{1,3}){3}$"
}

function Round-Timestamp([DateTime]$dt, [int]$minutes) {
  if ($minutes -le 0) { return $dt }
  $ticks = [TimeSpan]::FromMinutes($minutes).Ticks
  $roundedTicks = [Math]::Floor($dt.Ticks / $ticks) * $ticks
  New-Object DateTime($roundedTicks, $dt.Kind)
}

New-Item -ItemType Directory -Force -Path (Split-Path $OutPath) | Out-Null

$rows = Import-Csv $InPath

$sanitised = foreach ($r in $rows) {
  $dt = [DateTime]::Parse($r.timestamp)
  $dt2 = Round-Timestamp $dt $RoundMinutes

  $ip = $r.remote_ip

  if ($ip -eq "127.0.0.1") {
    $ipToken = "LOOPBACK"
  }
  elseif ($ip -eq "0.0.0.0" -or $ip -eq "::") {
    $ipToken = "UNSPECIFIED"
  }
  elseif (Is-IPv4 $ip) {
    $ipToken = "IP_" + (Get-HashToken $ip $salt)
  }
  else {
    $ipToken = "NON_IPV4"
  }

  [PSCustomObject]@{
    timestamp   = $dt2.ToString("s")
    process     = $r.process
    remote_ip   = $ipToken
    remote_port = $r.remote_port
    protocol    = $r.protocol
    tests       = $r.tests
    success     = $r.success
    fail        = $r.fail
    avg_ms      = $r.avg_ms
    min_ms      = $r.min_ms
    max_ms      = $r.max_ms
    status      = $r.status
  }
}

$sanitised | Export-Csv -NoTypeInformation -Encoding utf8 $OutPath
Write-Host "Sanitised file written to: $OutPath"
