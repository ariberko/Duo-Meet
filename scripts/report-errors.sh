#!/bin/bash
# Prints a build log and turns its error lines into GitHub annotations,
# so they show on the run's summary page (and through the GitHub API).
log="$1"
tail -n 150 "$log"
grep -iE "error|failed|denied|not found|no account|no profile|invalid" "$log" \
  | grep -v "^\s*$" | sort -u | tail -n 20 \
  | while IFS= read -r line; do echo "::error::${line//%/%25}"; done
