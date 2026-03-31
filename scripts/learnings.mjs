/**
 * learnings.mjs — Self-improving agent learning system
 *
 * Stores learnings, errors, and feature requests in PostgreSQL.
 * Used by Paperclip agents to build institutional memory.
 *
 * Usage:
 *   node /app/scripts/learnings.mjs init                          # Create table
 *   node /app/scripts/learnings.mjs log <type> <category> <summary> [--priority high] [--area backend] [--agent CEO] [--details "..."] [--pattern-key "..."]
 *   node /app/scripts/learnings.mjs list [--type LRN] [--status pending] [--limit 20]
 *   node /app/scripts/learnings.mjs get <id>
 *   node /app/scripts/learnings.mjs resolve <id> [--notes "..."]
 *   node /app/scripts/learnings.mjs promote <id> <target>         # target: soul|agents|skill|global
 *   node /app/scripts/learnings.mjs recurring [--min-count 3]     # Show recurring patterns
 *   node /app/scripts/learnings.mjs stats                         # Summary statistics
 *   node /app/scripts/learnings.mjs search <keyword>              # Full-text search
 */

import { createRequire } from 'node:module';

const require = createRequire('/app/packages/db/');
const postgres = require('postgres');

const DB_URL = process.env.DATABASE_URL || 'postgres://paperclip:paperclip@127.0.0.1:54329/paperclip';
const sql = postgres(DB_URL);

// ── Helpers ──────────────────────────────────────────────────

function generateId(type) {
  const now = new Date();
  const date = now.toISOString().slice(0, 10).replace(/-/g, '');
  const rand = Math.random().toString(36).slice(2, 5).toUpperCase();
  return `${type}-${date}-${rand}`;
}

function parseArgs(args) {
  const flags = {};
  const positional = [];
  for (let i = 0; i < args.length; i++) {
    if (args[i].startsWith('--')) {
      const key = args[i].slice(2);
      flags[key] = args[i + 1] || 'true';
      i++;
    } else {
      positional.push(args[i]);
    }
  }
  return { flags, positional };
}

// ── Commands ─────────────────────────────────────────────────

async function init() {
  await sql`
    CREATE TABLE IF NOT EXISTS learnings (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL CHECK (type IN ('LRN', 'ERR', 'FEAT')),
      category TEXT NOT NULL,
      summary TEXT NOT NULL,
      details TEXT,
      priority TEXT DEFAULT 'medium' CHECK (priority IN ('low', 'medium', 'high', 'critical')),
      status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'in_progress', 'resolved', 'wont_fix', 'promoted', 'promoted_to_skill')),
      area TEXT DEFAULT 'general',
      agent_name TEXT,
      pattern_key TEXT,
      recurrence_count INTEGER DEFAULT 1,
      first_seen TIMESTAMPTZ DEFAULT NOW(),
      last_seen TIMESTAMPTZ DEFAULT NOW(),
      promoted_to TEXT,
      resolution_notes TEXT,
      resolved_at TIMESTAMPTZ,
      created_at TIMESTAMPTZ DEFAULT NOW(),
      updated_at TIMESTAMPTZ DEFAULT NOW()
    )
  `;

  // Index for common queries
  await sql`CREATE INDEX IF NOT EXISTS idx_learnings_type ON learnings(type)`;
  await sql`CREATE INDEX IF NOT EXISTS idx_learnings_status ON learnings(status)`;
  await sql`CREATE INDEX IF NOT EXISTS idx_learnings_pattern ON learnings(pattern_key)`;
  await sql`CREATE INDEX IF NOT EXISTS idx_learnings_priority ON learnings(priority)`;

  console.log('[learnings] Table initialized.');
}

async function log(args) {
  const { flags, positional } = parseArgs(args);
  const [type, category, ...summaryParts] = positional;
  const summary = summaryParts.join(' ');

  if (!type || !category || !summary) {
    console.error('Usage: log <LRN|ERR|FEAT> <category> <summary> [--priority high] [--area backend] [--agent CEO] [--details "..."] [--pattern-key "..."]');
    process.exit(1);
  }

  const validTypes = ['LRN', 'ERR', 'FEAT'];
  if (!validTypes.includes(type.toUpperCase())) {
    console.error(`Invalid type: ${type}. Must be one of: ${validTypes.join(', ')}`);
    process.exit(1);
  }

  const id = generateId(type.toUpperCase());
  const priority = flags.priority || 'medium';
  const area = flags.area || 'general';
  const agent = flags.agent || null;
  const details = flags.details || null;
  const patternKey = flags['pattern-key'] || null;

  // Check for existing pattern and increment recurrence
  if (patternKey) {
    const existing = await sql`
      SELECT id, recurrence_count FROM learnings
      WHERE pattern_key = ${patternKey} AND status NOT IN ('resolved', 'wont_fix')
      ORDER BY created_at DESC LIMIT 1
    `;
    if (existing.length > 0) {
      const newCount = existing[0].recurrence_count + 1;
      await sql`
        UPDATE learnings
        SET recurrence_count = ${newCount}, last_seen = NOW(), updated_at = NOW()
        WHERE id = ${existing[0].id}
      `;
      console.log(JSON.stringify({
        action: 'recurrence_updated',
        existing_id: existing[0].id,
        recurrence_count: newCount,
        note: newCount >= 3 ? 'PROMOTE_CANDIDATE: 3+ recurrences detected' : null
      }));
      return;
    }
  }

  await sql`
    INSERT INTO learnings (id, type, category, summary, details, priority, area, agent_name, pattern_key)
    VALUES (${id}, ${type.toUpperCase()}, ${category}, ${summary}, ${details}, ${priority}, ${area}, ${agent}, ${patternKey})
  `;

  console.log(JSON.stringify({ action: 'logged', id, type: type.toUpperCase(), category, summary, priority }));
}

async function list(args) {
  const { flags } = parseArgs(args);
  const limit = parseInt(flags.limit || '20');
  const type = flags.type || null;
  const status = flags.status || null;
  const area = flags.area || null;

  let rows;
  if (type && status) {
    rows = await sql`SELECT * FROM learnings WHERE type = ${type.toUpperCase()} AND status = ${status} ORDER BY created_at DESC LIMIT ${limit}`;
  } else if (type) {
    rows = await sql`SELECT * FROM learnings WHERE type = ${type.toUpperCase()} ORDER BY created_at DESC LIMIT ${limit}`;
  } else if (status) {
    rows = await sql`SELECT * FROM learnings WHERE status = ${status} ORDER BY created_at DESC LIMIT ${limit}`;
  } else {
    rows = await sql`SELECT * FROM learnings ORDER BY created_at DESC LIMIT ${limit}`;
  }

  if (rows.length === 0) {
    console.log(JSON.stringify({ total: 0, items: [] }));
    return;
  }

  const items = rows.map(r => ({
    id: r.id,
    type: r.type,
    category: r.category,
    summary: r.summary,
    priority: r.priority,
    status: r.status,
    area: r.area,
    agent: r.agent_name,
    pattern_key: r.pattern_key,
    recurrence: r.recurrence_count,
    created: r.created_at?.toISOString().slice(0, 16)
  }));

  console.log(JSON.stringify({ total: rows.length, items }, null, 2));
}

async function get(args) {
  const id = args[0];
  if (!id) { console.error('Usage: get <id>'); process.exit(1); }

  const rows = await sql`SELECT * FROM learnings WHERE id = ${id}`;
  if (rows.length === 0) { console.log('Not found.'); return; }

  console.log(JSON.stringify(rows[0], null, 2));
}

async function resolve(args) {
  const { flags, positional } = parseArgs(args);
  const id = positional[0];
  const notes = flags.notes || null;

  if (!id) { console.error('Usage: resolve <id> [--notes "..."]'); process.exit(1); }

  await sql`
    UPDATE learnings
    SET status = 'resolved', resolution_notes = ${notes}, resolved_at = NOW(), updated_at = NOW()
    WHERE id = ${id}
  `;
  console.log(JSON.stringify({ action: 'resolved', id }));
}

async function promote(args) {
  const [id, target] = args;
  if (!id || !target) { console.error('Usage: promote <id> <soul|agents|skill|global>'); process.exit(1); }

  const validTargets = ['soul', 'agents', 'skill', 'global'];
  if (!validTargets.includes(target)) {
    console.error(`Invalid target: ${target}. Must be one of: ${validTargets.join(', ')}`);
    process.exit(1);
  }

  const newStatus = target === 'skill' ? 'promoted_to_skill' : 'promoted';
  await sql`
    UPDATE learnings
    SET status = ${newStatus}, promoted_to = ${target}, updated_at = NOW()
    WHERE id = ${id}
  `;
  console.log(JSON.stringify({ action: 'promoted', id, target }));
}

async function recurring(args) {
  const { flags } = parseArgs(args);
  const minCount = parseInt(flags['min-count'] || '2');

  const rows = await sql`
    SELECT pattern_key, type, category, MAX(summary) as summary,
           SUM(recurrence_count) as total_count,
           MIN(first_seen) as first_seen, MAX(last_seen) as last_seen,
           COUNT(*) as entries,
           ARRAY_AGG(id) as ids
    FROM learnings
    WHERE pattern_key IS NOT NULL AND status NOT IN ('resolved', 'wont_fix', 'promoted', 'promoted_to_skill')
    GROUP BY pattern_key, type, category
    HAVING SUM(recurrence_count) >= ${minCount}
    ORDER BY total_count DESC
  `;

  if (rows.length === 0) {
    console.log(JSON.stringify({ message: `No patterns with ${minCount}+ recurrences.`, items: [] }));
    return;
  }

  const items = rows.map(r => ({
    pattern_key: r.pattern_key,
    type: r.type,
    category: r.category,
    summary: r.summary,
    total_count: parseInt(r.total_count),
    first_seen: r.first_seen?.toISOString().slice(0, 10),
    last_seen: r.last_seen?.toISOString().slice(0, 10),
    promote_candidate: parseInt(r.total_count) >= 3,
    ids: r.ids
  }));

  console.log(JSON.stringify({ total: items.length, items }, null, 2));
}

async function stats() {
  const byType = await sql`SELECT type, COUNT(*) as count FROM learnings GROUP BY type ORDER BY type`;
  const byStatus = await sql`SELECT status, COUNT(*) as count FROM learnings GROUP BY status ORDER BY count DESC`;
  const byPriority = await sql`SELECT priority, COUNT(*) as count FROM learnings GROUP BY priority ORDER BY
    CASE priority WHEN 'critical' THEN 1 WHEN 'high' THEN 2 WHEN 'medium' THEN 3 WHEN 'low' THEN 4 END`;
  const byAgent = await sql`SELECT COALESCE(agent_name, '(no agent)') as agent, COUNT(*) as count FROM learnings GROUP BY agent_name ORDER BY count DESC`;
  const total = await sql`SELECT COUNT(*) as count FROM learnings`;
  const pendingHigh = await sql`SELECT COUNT(*) as count FROM learnings WHERE status = 'pending' AND priority IN ('high', 'critical')`;
  const promoteCandidates = await sql`
    SELECT COUNT(DISTINCT pattern_key) as count FROM learnings
    WHERE pattern_key IS NOT NULL AND recurrence_count >= 3 AND status NOT IN ('resolved', 'promoted', 'promoted_to_skill')
  `;

  console.log(JSON.stringify({
    total: parseInt(total[0].count),
    pending_high_priority: parseInt(pendingHigh[0].count),
    promote_candidates: parseInt(promoteCandidates[0].count),
    by_type: Object.fromEntries(byType.map(r => [r.type, parseInt(r.count)])),
    by_status: Object.fromEntries(byStatus.map(r => [r.status, parseInt(r.count)])),
    by_priority: Object.fromEntries(byPriority.map(r => [r.priority, parseInt(r.count)])),
    by_agent: Object.fromEntries(byAgent.map(r => [r.agent, parseInt(r.count)]))
  }, null, 2));
}

async function search(args) {
  const keyword = args.join(' ');
  if (!keyword) { console.error('Usage: search <keyword>'); process.exit(1); }

  const rows = await sql`
    SELECT id, type, category, summary, priority, status, agent_name, recurrence_count, created_at
    FROM learnings
    WHERE summary ILIKE ${'%' + keyword + '%'} OR details ILIKE ${'%' + keyword + '%'} OR category ILIKE ${'%' + keyword + '%'}
    ORDER BY created_at DESC LIMIT 20
  `;

  const items = rows.map(r => ({
    id: r.id,
    type: r.type,
    category: r.category,
    summary: r.summary,
    priority: r.priority,
    status: r.status,
    agent: r.agent_name,
    recurrence: r.recurrence_count
  }));

  console.log(JSON.stringify({ keyword, total: items.length, items }, null, 2));
}

// ── Main ─────────────────────────────────────────────────────

const [command, ...args] = process.argv.slice(2);

try {
  switch (command) {
    case 'init':      await init(); break;
    case 'log':       await log(args); break;
    case 'list':      await list(args); break;
    case 'get':       await get(args); break;
    case 'resolve':   await resolve(args); break;
    case 'promote':   await promote(args); break;
    case 'recurring': await recurring(args); break;
    case 'stats':     await stats(); break;
    case 'search':    await search(args); break;
    default:
      console.log(`Self-Improving Agent — Learnings DB

Commands:
  init                              Create learnings table
  log <LRN|ERR|FEAT> <cat> <msg>    Log a learning/error/feature
  list [--type X] [--status X]      List entries
  get <id>                          Get entry details
  resolve <id> [--notes "..."]      Mark as resolved
  promote <id> <target>             Promote (soul|agents|skill|global)
  recurring [--min-count N]         Show recurring patterns
  stats                             Summary statistics
  search <keyword>                  Full-text search`);
  }
} catch (e) {
  console.error('[learnings] Error:', e.message);
} finally {
  try { await sql.end(); } catch (_) {}
}
