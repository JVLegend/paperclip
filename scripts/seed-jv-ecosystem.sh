#!/usr/bin/env bash
#
# Seed JV Ecosystem into Paperclip
# Creates 3 companies, agents, projects, skills, and routines
#
# Usage:
#   PAPERCLIP_API_URL=https://jv-paperclip-production.up.railway.app/api \
#   PAPERCLIP_API_KEY=<setup-key> \
#   bash scripts/seed-jv-ecosystem.sh
#
set -euo pipefail

API="${PAPERCLIP_API_URL:?Set PAPERCLIP_API_URL}"
KEY="${PAPERCLIP_API_KEY:?Set PAPERCLIP_API_KEY}"

H1="Authorization: Bearer $KEY"
H2="Content-Type: application/json"

call() {
  local method=$1 path=$2; shift 2
  local resp
  resp=$(curl -sf -X "$method" "$API$path" -H "$H1" -H "$H2" "$@" 2>&1) || {
    echo "FAIL: $method $path"
    echo "$resp"
    return 1
  }
  echo "$resp"
}

jq_id() { echo "$1" | python3 -c "import sys,json; print(json.load(sys.stdin)['id'])"; }

echo "=== Seeding JV Ecosystem ==="
echo "API: $API"
echo ""

# ──────────────────────────────────────────────────────────────────────────────
# 1. COMPANIES
# ──────────────────────────────────────────────────────────────────────────────

echo "--- Creating Companies ---"

SML=$(call POST /companies -d '{
  "name": "SmartLab",
  "description": "Pipeline IA agentica CRISPR-Cas12a para diagnosticos AMR. Harvard Hackathon 2026.",
  "issuePrefix": "SML",
  "budgetMonthlyCents": 1000,
  "requireBoardApprovalForNewAgents": true
}')
SML_ID=$(jq_id "$SML")
echo "SmartLab: $SML_ID"

IAM=$(call POST /companies -d '{
  "name": "IA para Medicos",
  "description": "Motor de receita — apps medicos com IA, AEO Doctors, sites premium, cursos. iapmjv.com.br",
  "issuePrefix": "IAM",
  "budgetMonthlyCents": 2000,
  "requireBoardApprovalForNewAgents": true
}')
IAM_ID=$(jq_id "$IAM")
echo "IA para Medicos: $IAM_ID"

MCT=$(call POST /companies -d '{
  "name": "Mission Control",
  "description": "Kanban sync, grant tracking, vault management. Orquestracao cross-company do ecossistema JV.",
  "issuePrefix": "MCT",
  "budgetMonthlyCents": 1500,
  "requireBoardApprovalForNewAgents": true
}')
MCT_ID=$(jq_id "$MCT")
echo "Mission Control: $MCT_ID"

echo ""

# ──────────────────────────────────────────────────────────────────────────────
# 2. PROJECTS (repo links)
# ──────────────────────────────────────────────────────────────────────────────

echo "--- Creating Projects ---"

SML_PROJ=$(call POST "/companies/$SML_ID/projects" -d '{
  "name": "BacEnd Pipeline",
  "description": "CRISPR-Cas12a agentic pipeline. 12 AMR genes target.",
  "repoUrl": "https://github.com/JVLegend/bac_end_harvard"
}')
SML_PROJ_ID=$(jq_id "$SML_PROJ")
echo "SmartLab Project: $SML_PROJ_ID"

IAM_PROJ=$(call POST "/companies/$IAM_ID/projects" -d '{
  "name": "Site IAPM",
  "description": "Site iapmjv.com.br — HTML + Tailwind + Express. Vercel deploy.",
  "repoUrl": "https://github.com/WingsAI/iapm_site"
}')
IAM_PROJ_ID=$(jq_id "$IAM_PROJ")
echo "IAPM Project: $IAM_PROJ_ID"

MCT_PROJ=$(call POST "/companies/$MCT_ID/projects" -d '{
  "name": "SuperJV Vault",
  "description": "Obsidian vault P.A.R.A. — MOCs, Projects, Knowledge Base, Kanban.",
  "repoUrl": "https://github.com/JVLegend/SuperJV"
}')
MCT_PROJ_ID=$(jq_id "$MCT_PROJ")
echo "Mission Control Project: $MCT_PROJ_ID"

echo ""

# ──────────────────────────────────────────────────────────────────────────────
# 3. AGENTS
# ──────────────────────────────────────────────────────────────────────────────

echo "--- Creating Agents ---"

# SmartLab agents
SML_CEO=$(call POST "/companies/$SML_ID/agents" -d '{
  "name": "SmartLab-CEO",
  "role": "ceo",
  "title": "CEO",
  "adapterType": "claude_local",
  "adapterConfig": {},
  "budgetMonthlyCents": 500
}')
SML_CEO_ID=$(jq_id "$SML_CEO")
echo "SmartLab CEO: $SML_CEO_ID"

SML_GENOMIC=$(call POST "/companies/$SML_ID/agents" -d '{
  "name": "GenomicDesigner",
  "role": "specialized",
  "title": "Genomic Pipeline Engineer",
  "adapterType": "claude_local",
  "adapterConfig": {},
  "budgetMonthlyCents": 300
}')
SML_GENOMIC_ID=$(jq_id "$SML_GENOMIC")
echo "GenomicDesigner: $SML_GENOMIC_ID"

SML_BLAST=$(call POST "/companies/$SML_ID/agents" -d '{
  "name": "BLASTValidator",
  "role": "specialized",
  "title": "Validation Engineer",
  "adapterType": "claude_local",
  "adapterConfig": {},
  "budgetMonthlyCents": 200
}')
SML_BLAST_ID=$(jq_id "$SML_BLAST")
echo "BLASTValidator: $SML_BLAST_ID"

# IA para Medicos agents
IAM_CEO=$(call POST "/companies/$IAM_ID/agents" -d '{
  "name": "IAPM-CEO",
  "role": "ceo",
  "title": "CEO",
  "adapterType": "claude_local",
  "adapterConfig": {},
  "budgetMonthlyCents": 500
}')
IAM_CEO_ID=$(jq_id "$IAM_CEO")
echo "IAPM CEO: $IAM_CEO_ID"

IAM_CONTENT=$(call POST "/companies/$IAM_ID/agents" -d '{
  "name": "ContentWriter",
  "role": "specialized",
  "title": "Content & AEO Specialist",
  "adapterType": "claude_local",
  "adapterConfig": {},
  "budgetMonthlyCents": 500
}')
IAM_CONTENT_ID=$(jq_id "$IAM_CONTENT")
echo "ContentWriter: $IAM_CONTENT_ID"

IAM_PROSPECTOR=$(call POST "/companies/$IAM_ID/agents" -d '{
  "name": "DoctorProspector",
  "role": "specialized",
  "title": "Lead Generation Specialist",
  "adapterType": "claude_local",
  "adapterConfig": {},
  "budgetMonthlyCents": 500
}')
IAM_PROSPECTOR_ID=$(jq_id "$IAM_PROSPECTOR")
echo "DoctorProspector: $IAM_PROSPECTOR_ID"

# Mission Control agents
MCT_CEO=$(call POST "/companies/$MCT_ID/agents" -d '{
  "name": "MCT-CEO",
  "role": "ceo",
  "title": "CEO",
  "adapterType": "claude_local",
  "adapterConfig": {},
  "budgetMonthlyCents": 500
}')
MCT_CEO_ID=$(jq_id "$MCT_CEO")
echo "MCT CEO: $MCT_CEO_ID"

MCT_GRANT=$(call POST "/companies/$MCT_ID/agents" -d '{
  "name": "GrantTracker",
  "role": "specialized",
  "title": "Grant Pipeline Monitor",
  "adapterType": "claude_local",
  "adapterConfig": {},
  "budgetMonthlyCents": 300
}')
MCT_GRANT_ID=$(jq_id "$MCT_GRANT")
echo "GrantTracker: $MCT_GRANT_ID"

MCT_KANBAN=$(call POST "/companies/$MCT_ID/agents" -d '{
  "name": "KanbanSyncer",
  "role": "specialized",
  "title": "Kanban Synchronization Agent",
  "adapterType": "claude_local",
  "adapterConfig": {},
  "budgetMonthlyCents": 200
}')
MCT_KANBAN_ID=$(jq_id "$MCT_KANBAN")
echo "KanbanSyncer: $MCT_KANBAN_ID"

echo ""

# ──────────────────────────────────────────────────────────────────────────────
# 4. ROUTINES
# ──────────────────────────────────────────────────────────────────────────────

echo "--- Creating Routines ---"

# Grant Deadline Monitor — weekdays 9am BRT (12:00 UTC)
call POST "/companies/$MCT_ID/routines" -d '{
  "title": "Grant Deadline Monitor",
  "description": "Check grant deadlines from MOC_Business.md. Alert on approaching deadlines. Weekly digest on Mondays.",
  "projectId": "'"$MCT_PROJ_ID"'",
  "assigneeAgentId": "'"$MCT_GRANT_ID"'",
  "priority": "high",
  "status": "active",
  "concurrencyPolicy": "coalesce_if_active",
  "triggers": [{
    "kind": "cron",
    "label": "Weekdays 9am BRT",
    "cronExpression": "0 12 * * 1-5",
    "timezone": "America/Sao_Paulo",
    "enabled": true
  }]
}' > /dev/null
echo "Grant Deadline Monitor: created (weekdays 9am)"

# Kanban Sync — every 6 hours
call POST "/companies/$MCT_ID/routines" -d '{
  "title": "Kanban Vault Sync",
  "description": "Sync kanban.json in SuperJV vault with Paperclip issues across all companies.",
  "projectId": "'"$MCT_PROJ_ID"'",
  "assigneeAgentId": "'"$MCT_KANBAN_ID"'",
  "priority": "medium",
  "status": "active",
  "concurrencyPolicy": "coalesce_if_active",
  "triggers": [{
    "kind": "cron",
    "label": "Every 6 hours",
    "cronExpression": "0 */6 * * *",
    "timezone": "America/Sao_Paulo",
    "enabled": true
  }]
}' > /dev/null
echo "Kanban Vault Sync: created (every 6h)"

# SmartLab Gene Check — Mondays 10am BRT (13:00 UTC)
call POST "/companies/$SML_ID/routines" -d '{
  "title": "AMR Gene Batch Check",
  "description": "Check bac_end_harvard repo. Report progress on 12 AMR genes. Create issues for next batch.",
  "projectId": "'"$SML_PROJ_ID"'",
  "assigneeAgentId": "'"$SML_GENOMIC_ID"'",
  "priority": "medium",
  "status": "active",
  "concurrencyPolicy": "forbid",
  "triggers": [{
    "kind": "cron",
    "label": "Mondays 10am BRT",
    "cronExpression": "0 13 * * 1",
    "timezone": "America/Sao_Paulo",
    "enabled": true
  }]
}' > /dev/null
echo "AMR Gene Batch Check: created (Mondays 10am)"

# Doctor Prospector — every 3 hours
call POST "/companies/$IAM_ID/routines" -d '{
  "title": "Doctor Prospection Batch",
  "description": "Find 15 doctors without websites in SP via Overpass API. Draft cold emails for review. Rotate regions each run.",
  "projectId": "'"$IAM_PROJ_ID"'",
  "assigneeAgentId": "'"$IAM_PROSPECTOR_ID"'",
  "priority": "medium",
  "status": "active",
  "concurrencyPolicy": "coalesce_if_active",
  "triggers": [{
    "kind": "cron",
    "label": "Every 3 hours",
    "cronExpression": "0 */3 * * *",
    "timezone": "America/Sao_Paulo",
    "enabled": true
  }]
}' > /dev/null
echo "Doctor Prospection Batch: created (every 3h)"

echo ""
echo "=== Seed Complete ==="
echo ""
echo "Companies:"
echo "  SmartLab:         $SML_ID"
echo "  IA para Medicos:  $IAM_ID"
echo "  Mission Control:  $MCT_ID"
echo ""
echo "Next steps:"
echo "  1. Set GITHUB_TOKEN as env var on Railway"
echo "  2. Assign skills to agents via the Paperclip UI"
echo "  3. Trigger a manual heartbeat on GrantTracker to test"
echo "  4. Monitor approvals queue for git push requests"
