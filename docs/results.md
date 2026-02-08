# LAN baseline (gateway)
gateway ping showed 0% loss and low average latency indicating local wifi link was stable during the measurement window

# WAN baseline (1.1.1.1)
ping to 1.1.1.1 showed 0% loss with low average latency even while downloading multiple large files, suggesting no consistent WAN-level packet loss

# endpoint testing (powershell netlog)
many cloud endpoints do not respond to ICMP which produced misleading loss in ICMP based logging

switching to TCP connect timing showed stable reachability to multiple remote IP:port endpoints with high success rates and consistent handshake latency during capture window

# interpretation
the combination of
- stable LAN ping
- stable WAN ping
- stable TCP connect timing to game-related endpoints
suggests the in game outlost/inlost spikes are unlikely to be caused by persistent, general packet loss on the local network or to the wider internet

the most plausible explanations are
1. UDP specific issues (game traffic is typically UDP, ICMP/TCP tests may not reflect UDP jitter/loss)
2. server/region/routing conditions (match servers or routes varying by region/provider)
3. micro stalls or client hitches (short stalls that a 1 Hz ping sample may miss but the game netgraph will count as lost/late updates)

# limitations
- ICMP ping does not represent UDP game traffic
- TCP connect timing tests reachability and handshake latency but does not fully capture UDP jitter, packet reordering or server tick behaviour
- windows does not always expose remote UDP endpoints per process cleanly without packet capture

# solutions
## desktop based
- set wifi adapter roaming agressiveness to lowest
- disable unused bands (e.g. 6GHz) and disable MAC randomisation for the home SSID for consistency
- avoid saturating connection with background uploads/downloads

## network based
- enable SQM/QoS on the router to reduce jitter under load*
- Prefer ethernet to elimite wifi micro stalls*