#!/bin/bash
# pcp.sh — Paperclip API helper for Hermes
# Usage: source this file, then use `pcp <command> [args]`

PCP_API="${PAPERCLIP_API_URL:-https://jv-paperclip-production.up.railway.app/api}"
PCP_KEY="${PAPERCLIP_API_KEY:-pcp_board_setup_bc5dce235ce5166620bd3d15061636c87fa1be6a3d4298a6}"
PCP_COMPANY="${PAPERCLIP_COMPANY_ID:-6da87f11-6a27-4627-b101-924d5a161f6e}"

_pcp_curl() {
  curl -s -H "Authorization: Bearer ${PCP_KEY}" -H "Content-Type: application/json" "$@"
}

pcp() {
  local cmd="$1"
  shift

  case "$cmd" in
    health)
      _pcp_curl "${PCP_API}/health" | python3 -m json.tool 2>/dev/null || _pcp_curl "${PCP_API}/health"
      ;;

    agents)
      _pcp_curl "${PCP_API}/companies/${PCP_COMPANY}/agents" | python3 -c "
import sys, json
agents = json.load(sys.stdin)
if isinstance(agents, list):
    print(f'Total: {len(agents)} agentes\n')
    for a in agents:
        status = a.get('status', '?')
        icon = '🟢' if status == 'active' else '🔴' if status == 'paused' else '⚪'
        print(f'{icon} {a[\"name\"]:30s} | {a[\"id\"]} | {a.get(\"role\",\"?\")}')
else:
    print(json.dumps(agents, indent=2))
" 2>/dev/null || _pcp_curl "${PCP_API}/companies/${PCP_COMPANY}/agents"
      ;;

    agent)
      local id="$1"
      _pcp_curl "${PCP_API}/agents/${id}" | python3 -m json.tool 2>/dev/null
      ;;

    status)
      echo "=== AGENTES ==="
      pcp agents
      echo ""
      echo "=== RUNS ATIVOS ==="
      pcp live
      echo ""
      echo "=== ÚLTIMOS 5 RUNS ==="
      pcp runs 5
      ;;

    runs)
      local limit="${1:-10}"
      _pcp_curl "${PCP_API}/companies/${PCP_COMPANY}/heartbeat-runs?limit=${limit}" | python3 -c "
import sys, json
runs = json.load(sys.stdin)
if isinstance(runs, list):
    print(f'Últimos {len(runs)} runs:\n')
    for r in runs:
        status = r.get('status', '?')
        icon = '🟢' if status == 'running' else '✅' if status in ('completed','success') else '❌' if status in ('failed','error') else '⏸️'
        agent = r.get('agentName', r.get('agentId', '?')[:8])
        started = r.get('startedAt', r.get('createdAt', '?'))[:19] if r.get('startedAt') or r.get('createdAt') else '?'
        source = r.get('source', '?')
        print(f'{icon} {status:12s} | {agent:25s} | {started} | {source} | {r[\"id\"][:12]}...')
else:
    print(json.dumps(runs, indent=2))
" 2>/dev/null || _pcp_curl "${PCP_API}/companies/${PCP_COMPANY}/heartbeat-runs?limit=${limit}"
      ;;

    live)
      _pcp_curl "${PCP_API}/companies/${PCP_COMPANY}/live-runs" | python3 -c "
import sys, json
data = json.load(sys.stdin)
runs = data if isinstance(data, list) else data.get('runs', [])
if not runs:
    print('Nenhum run ativo no momento.')
else:
    print(f'{len(runs)} run(s) ativo(s):\n')
    for r in runs:
        agent = r.get('agentName', r.get('agentId', '?')[:8])
        status = r.get('status', '?')
        started = (r.get('startedAt') or r.get('createdAt') or '?')[:19]
        print(f'🟢 {agent:25s} | {status} | {started} | {r[\"id\"][:12]}...')
" 2>/dev/null || _pcp_curl "${PCP_API}/companies/${PCP_COMPANY}/live-runs"
      ;;

    run-log)
      local run_id="$1"
      local offset="${2:-0}"
      _pcp_curl "${PCP_API}/heartbeat-runs/${run_id}/log?offset=${offset}&limitBytes=8000" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if isinstance(data, dict):
    log = data.get('log', data.get('content', ''))
    if log:
        print(log[-3000:] if len(log) > 3000 else log)
    else:
        print(json.dumps(data, indent=2))
else:
    print(data)
" 2>/dev/null || _pcp_curl "${PCP_API}/heartbeat-runs/${run_id}/log?offset=${offset}"
      ;;

    run-detail)
      local run_id="$1"
      _pcp_curl "${PCP_API}/heartbeat-runs/${run_id}" | python3 -m json.tool 2>/dev/null
      ;;

    routines)
      _pcp_curl "${PCP_API}/companies/${PCP_COMPANY}/routines" | python3 -c "
import sys, json
routines = json.load(sys.stdin)
if isinstance(routines, list):
    print(f'Total: {len(routines)} rotinas\n')
    for r in routines:
        status = r.get('status', '?')
        icon = '🟢' if status == 'active' else '⏸️' if status == 'paused' else '📦'
        agent = r.get('assigneeAgentName', r.get('assigneeAgentId', '?')[:8])
        print(f'{icon} {r[\"title\"]:35s} | {status:8s} | {agent:20s} | {r[\"id\"][:12]}...')
else:
    print(json.dumps(routines, indent=2))
" 2>/dev/null || _pcp_curl "${PCP_API}/companies/${PCP_COMPANY}/routines"
      ;;

    routine)
      local id="$1"
      _pcp_curl "${PCP_API}/routines/${id}" | python3 -m json.tool 2>/dev/null
      ;;

    routine-runs)
      local id="$1"
      local limit="${2:-5}"
      _pcp_curl "${PCP_API}/routines/${id}/runs?limit=${limit}" | python3 -c "
import sys, json
runs = json.load(sys.stdin)
if isinstance(runs, list):
    for r in runs:
        status = r.get('status', '?')
        icon = '✅' if status in ('completed','success') else '❌' if status in ('failed','error') else '🟢'
        started = (r.get('startedAt') or r.get('createdAt') or '?')[:19]
        print(f'{icon} {status:12s} | {started} | {r[\"id\"]}')
else:
    print(json.dumps(runs, indent=2))
" 2>/dev/null || _pcp_curl "${PCP_API}/routines/${id}/runs?limit=${limit}"
      ;;

    trigger-routine)
      local id="$1"
      echo "Triggering routine ${id}..."
      _pcp_curl -X POST "${PCP_API}/routines/${id}/run" \
        -d '{"source":"manual"}' | python3 -m json.tool 2>/dev/null
      ;;

    wakeup)
      local agent_id="$1"
      local reason="$2"
      echo "Waking up agent ${agent_id}..."
      _pcp_curl -X POST "${PCP_API}/agents/${agent_id}/wakeup" \
        -d "{\"source\":\"on_demand\",\"reason\":$(python3 -c "import json; print(json.dumps('$reason'))" 2>/dev/null || echo "\"${reason}\""),\"forceFreshSession\":true}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
if 'id' in data or 'runId' in data:
    run_id = data.get('id', data.get('runId', '?'))
    print(f'✅ Task criada! Run ID: {run_id}')
    print(f'   Monitore com: pcp run-log {run_id}')
else:
    print(json.dumps(data, indent=2))
" 2>/dev/null || _pcp_curl -X POST "${PCP_API}/agents/${agent_id}/wakeup" -d "{\"source\":\"on_demand\",\"reason\":\"${reason}\",\"forceFreshSession\":true}"
      ;;

    cancel)
      local run_id="$1"
      echo "Cancelling run ${run_id}..."
      _pcp_curl -X POST "${PCP_API}/heartbeat-runs/${run_id}/cancel" | python3 -m json.tool 2>/dev/null
      ;;

    # ── Learnings (self-improving agent) ──
    learn-log)
      # Log via API: wakeup SRE Monitor to log the learning
      local type="${1:-LRN}"
      local category="${2:-general}"
      shift 2 2>/dev/null
      local summary="$*"
      if [ -z "$summary" ]; then
        echo "Usage: pcp learn-log <LRN|ERR|FEAT> <category> <summary>"
        return 1
      fi
      _pcp_curl -X POST "${PCP_API}/agents/d89cd20e-86ce-4941-be46-45916b48dfd9/wakeup" \
        -d "{\"source\":\"on_demand\",\"reason\":\"Log learning: node /app/scripts/learnings.mjs log ${type} ${category} ${summary}\",\"forceFreshSession\":true}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
run_id = data.get('id', data.get('runId', '?'))
print(f'📝 Learning sendo logado via SRE Monitor. Run: {run_id[:12]}...')
" 2>/dev/null
      ;;

    learn-list)
      _pcp_curl "${PCP_API}/agents/d89cd20e-86ce-4941-be46-45916b48dfd9/wakeup" \
        -X POST \
        -d '{"source":"on_demand","reason":"Run: node /app/scripts/learnings.mjs list --limit 10 and return the output","forceFreshSession":true}' | python3 -c "
import sys, json
data = json.load(sys.stdin)
run_id = data.get('id', data.get('runId', '?'))
print(f'📋 Buscando learnings via SRE Monitor. Run: {run_id[:12]}...')
print(f'   Consulte em 30s com: pcp run-log {run_id}')
" 2>/dev/null
      ;;

    learn-stats)
      _pcp_curl "${PCP_API}/agents/d89cd20e-86ce-4941-be46-45916b48dfd9/wakeup" \
        -X POST \
        -d '{"source":"on_demand","reason":"Run: node /app/scripts/learnings.mjs stats and return the full output","forceFreshSession":true}' | python3 -c "
import sys, json
data = json.load(sys.stdin)
run_id = data.get('id', data.get('runId', '?'))
print(f'📊 Buscando stats de learnings. Run: {run_id[:12]}...')
print(f'   Consulte em 30s com: pcp run-log {run_id}')
" 2>/dev/null
      ;;

    learn-search)
      local keyword="$*"
      _pcp_curl "${PCP_API}/agents/d89cd20e-86ce-4941-be46-45916b48dfd9/wakeup" \
        -X POST \
        -d "{\"source\":\"on_demand\",\"reason\":\"Run: node /app/scripts/learnings.mjs search ${keyword} and return the output\",\"forceFreshSession\":true}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
run_id = data.get('id', data.get('runId', '?'))
print(f'🔍 Buscando learnings com \"{keyword}\". Run: {run_id[:12]}...')
print(f'   Consulte em 30s com: pcp run-log {run_id}')
" 2>/dev/null
      ;;

    *)
      echo "Paperclip CLI — Comandos disponíveis:"
      echo ""
      echo "  pcp health                        Health check"
      echo "  pcp agents                        Lista agentes"
      echo "  pcp agent <id>                    Detalhes de um agente"
      echo "  pcp status                        Status geral completo"
      echo "  pcp runs [limit]                  Runs recentes"
      echo "  pcp live                          Runs ativos agora"
      echo "  pcp run-log <runId>               Log de execução"
      echo "  pcp run-detail <runId>            Detalhes de um run"
      echo "  pcp routines                      Lista rotinas"
      echo "  pcp routine <id>                  Detalhes de uma rotina"
      echo "  pcp routine-runs <id> [limit]     Runs de uma rotina"
      echo "  pcp trigger-routine <id>          Executar rotina manualmente"
      echo "  pcp wakeup <agentId> \"msg\"        Delegar tarefa para agente"
      echo "  pcp cancel <runId>                Cancelar run"
      echo ""
      echo "  Learnings (Self-Improving):"
      echo "  pcp learn-log <LRN|ERR|FEAT> <cat> <msg>  Logar learning"
      echo "  pcp learn-list                             Listar recentes"
      echo "  pcp learn-stats                            Estatísticas"
      echo "  pcp learn-search <keyword>                 Buscar"
      ;;
  esac
}
