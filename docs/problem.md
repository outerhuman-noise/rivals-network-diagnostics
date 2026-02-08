# Problem Statement
ingame netgraph shows inlost/outlost spikes (up to 50%) and latency jumps (up to 800ms) while standard pings appear clean

# Possible explanations
- wifi interference/roaming micro stalls
- bufferbloat/jitter under load
- route/region/server side UDP impairment
- pc side hitch misreported as network loss

# Measurement sources
- LAN baseline (local link health)
> ping -n 500 192.168.20.1
- WAN baseline (internet reachability and jitter)
> ping -n 500 1.1.1.1
- ingame telemetry
> built in performance overlay with ping, outlost & inlost