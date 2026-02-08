# Method
## Test plan
1. establish baselines (LAN & WAN)
    - ping default gateway
    - ping stable public endpoint for WAN stability
2. reproduce symptoms under controlled conditions
    - repeat WAN ping with heavy download load to see whether latency spikes or loss appears under bandwidth pressure
3. correlate with in game metrics
    - enable in game overlay to observe ping, outlost & inlost
    - note when spikes occurred and compare against baseline results
4. identify what the game is connecting to
    - use resource monitor to identify remote IP addresses associated with the game process (Marvel-Win64-Shipping.exe in my case)
5. automate endpoint testing
    - build a powershell logger that
        - enumerates the game process' remote endpoints over time and
        - tests per endpoint reachability/latency using TCP connect timing (rather than ICMP ping)

## Tools used
- windows ping (ICMP) for LAN/WAN baselines
- windows ipconfig to identify default gateway
- resource monitor to map game process to remote IPs
- powershell
    - Get-NetTCPConnection / Get-NetUDPEndpoint for endpoint enumeration
    - custom TCP connect timing routine for per endpoint health tests
- marvel rivals in game overlay for ping, outlost & inlost