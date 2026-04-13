---
name: kanban-sync
description: >
  Synchronize the kanban.json file in the SuperJV Obsidian vault with Paperclip
  issues across all companies. Reads kanban state, creates/updates cards based on
  Paperclip issue status, and commits changes (with board approval before push).
---

# Kanban Sync Skill

You synchronize the Mission Control kanban board (JSON file in the SuperJV vault)
with the state of issues across all Paperclip companies.

## Kanban File Location

In the SuperJV repo: `03_Resources/Mission_Control/kanban.json`

## Kanban JSON Format

```json
{
  "todo": [ ...cards ],
  "inprogress": [ ...cards ],
  "done": [ ...cards ]
}
```

Each card:
```json
{
  "id": 123,
  "title": "Short title",
  "description": "Detail + source file reference",
  "updated": "2026-04-13T10:00:00",
  "progress": 50
}
```

## Rules

1. **Read kanban.json** from the repo workspace
2. **Read Paperclip issues** via API: `GET /api/companies/{id}/issues?status=todo,in_progress,done`
3. **Sync logic**:
   - New Paperclip issue not in kanban → add card (next id = max existing id + 1)
   - Paperclip issue completed → move card to "done" column
   - Paperclip issue in_progress → move card to "inprogress" column
   - Kanban card with no matching Paperclip issue → leave as-is (manual items)
4. **One card per active project** — don't create separate cards for subtasks
5. **Preserve existing items** — never delete kanban cards, only move between columns
6. **Commit changes** with message: `kanban sync: [date] — [N] cards updated`
7. **Follow git-governance skill** — request approval before pushing

## Card Title Format

`[COMPANY_PREFIX] Issue title` — e.g., `[SML] Process mecA gene batch`

## Description Format

Include Paperclip issue ID and link:
```
Paperclip: COMPANY-123
Status: in_progress
Agent: AgentName
Updated: 2026-04-13
```

## Important

- Read the FULL kanban.json before making any changes
- Increment `id` from the max existing id across ALL columns
- Update the `updated` field with current ISO datetime
- Keep `progress` field: 0 for todo, estimate for inprogress, 100 for done
