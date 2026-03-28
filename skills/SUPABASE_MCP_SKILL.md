# Supabase MCP — Guardrails & Usage Guide

Read this file before using any `mcp__supabase__*` tool.

---

## When to Use Supabase MCP

Use Supabase MCP tools for:

- **Schema inspection** — checking tables, columns, and relationships before writing migrations or queries
- **Debugging / logs** — reading logs and advisor warnings to diagnose production or staging issues
- **Migration management** — applying and tracking schema migrations in a controlled way

Do NOT use Supabase MCP tools speculatively or to "explore" outside of a clear task need.

---

## Permission Tiers

### Auto-allowed (safe, read-only)

These tools are safe to use without prompting:

| Tool | Purpose |
|---|---|
| `list_tables` | See current schema |
| `list_migrations` | Review applied migrations |
| `list_branches` | See active dev branches |
| `list_extensions` | Review enabled Postgres extensions |
| `list_edge_functions` | See deployed functions |
| `get_edge_function` | Inspect a specific function |
| `get_logs` | Read service logs |
| `get_project_url` | Retrieve project URL |
| `get_publishable_keys` | Retrieve anon/public keys |
| `get_advisors` | Read performance/security advisors |
| `search_docs` | Search Supabase documentation |
| `generate_typescript_types` | Generate types from schema |

### Requires user confirmation

Always stop and confirm with the user before using these:

| Tool | Risk |
|---|---|
| `execute_sql` | Runs arbitrary SQL — confirm the query with the user first |
| `apply_migration` | Modifies the database schema — irreversible in prod |
| `create_branch` | Creates a new database branch |
| `deploy_edge_function` | Deploys code to a live environment |

### Destructive — always confirm explicitly

These operations are hard to reverse. Never proceed without explicit user approval:

| Tool | Risk |
|---|---|
| `delete_branch` | Destroys a branch and its data |
| `reset_branch` | Resets a branch to an earlier state |
| `merge_branch` | Merges schema changes into another branch |
| `rebase_branch` | Rebases a branch — may cause conflicts or data loss |

---

## execute_sql Rules

- Always show the user the exact SQL before running it
- Get explicit approval before executing any statement
- Prefer `SELECT` queries for inspection; flag any mutating SQL (`INSERT`, `UPDATE`, `DELETE`, `DROP`, `ALTER`) as higher risk
- Never run destructive SQL without the user confirming the scope and target environment

---

## Branch Workflow

When schema changes are needed:

1. Create a dev branch with `create_branch` (confirm with user)
2. Apply migrations on the branch with `apply_migration`
3. Test using `list_tables`, `execute_sql` (SELECT)
4. Only `merge_branch` after user confirms the branch is ready
5. Never `reset_branch` or `delete_branch` without asking

---

## Environment Awareness

Always be explicit about which environment an action targets (production vs. a branch). If unclear, ask before proceeding.
