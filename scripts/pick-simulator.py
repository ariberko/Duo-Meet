"""Prints the UDID of an available simulator. Usage: xcrun simctl list devices available -j | python3 scripts/pick-simulator.py iphone|ipad"""
import json
import sys

want = sys.argv[1]
data = json.load(sys.stdin)
devices = [d for runtime, ds in data["devices"].items() if "iOS" in runtime for d in ds]
if want == "iphone":
    best = [d for d in devices if d["name"].startswith("iPhone") and "Pro" in d["name"] and "Max" not in d["name"]] \
        or [d for d in devices if d["name"].startswith("iPhone")]
else:
    # iPad mini is closest in size to the open iPhone Duo's inner display.
    best = [d for d in devices if "iPad mini" in d["name"]] or [d for d in devices if d["name"].startswith("iPad")]
print(best[-1]["udid"])
