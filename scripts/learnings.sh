#!/bin/bash
# learnings.sh — Wrapper for agents to log/query learnings
# Usage: source /app/scripts/learnings.sh && learn <command> [args]
#
# Quick shortcuts:
#   learn "algo que descobri"                    → LRN correction (auto)
#   learn-error "API timeout no Kimi"            → ERR api_error
#   learn-feat "Preciso de dashboard de métricas" → FEAT feature
#   learn-list                                    → List recent
#   learn-stats                                   → Statistics
#   learn-search "kimi"                           → Search

LEARNINGS_CMD="node --import /app/server/node_modules/tsx/dist/loader.mjs /app/scripts/learnings.mjs"

learn() {
  if [[ "$1" == log ]] || [[ "$1" == list ]] || [[ "$1" == get ]] || \
     [[ "$1" == resolve ]] || [[ "$1" == promote ]] || [[ "$1" == recurring ]] || \
     [[ "$1" == stats ]] || [[ "$1" == search ]] || [[ "$1" == init ]]; then
    $LEARNINGS_CMD "$@"
  else
    # Quick log: just pass a message → auto-detect type
    $LEARNINGS_CMD log LRN correction "$@"
  fi
}

learn-error() {
  $LEARNINGS_CMD log ERR api_error "$@"
}

learn-feat() {
  $LEARNINGS_CMD log FEAT feature "$@"
}

learn-list() {
  $LEARNINGS_CMD list "$@"
}

learn-stats() {
  $LEARNINGS_CMD stats
}

learn-search() {
  $LEARNINGS_CMD search "$@"
}
