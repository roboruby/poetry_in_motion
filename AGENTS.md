# AGENTS.md — poetry_in_motion

The reference app for Poetry's RubyLLM installer: a bank operations analyst
(RubyLLM over OpenRouter) whose answers become Poetry surfaces on a workspace.
README.md explains the architecture; this file carries the rules.

## Shape

- `Chat` is a workspace. Surfaces live only as the A2UI message log in
  `ui_events`, replayed through `Chat#surface_session` (poetry-agent's
  `Poetry::Agent::A2UI::Session` with `Workspace::Catalog`). Never store
  surface HTML; never mutate a surface without an event.
- The component vocabulary is declared once in `Workspace::Vocabulary`
  (prompt text + tool JSON schema) and rendered by `Workspace::Catalog`.
  Adding a component means all three: a vocabulary entry, a `render_<name>`
  method that renders a Poetry component, and a catalog test.
- `Workspace::Composer` is the only writer of `ui_events` and the only
  caller of the tile streams; tools and controllers go through it. It
  resolves `{ fromTool, key }` data references against the chat's latest
  tool results before validating, so persisted events hold real rows.
- Chat rows: appended at version 0 on create, morphed by `vreplace` with a
  rising version while streaming, settled at `Streamer::SETTLED_VERSION`.
  RubyLLM creates every row (tool results included) as an empty assistant
  placeholder first; the settled render fixes the role, so a row appended
  with the maximum version would never update. Keep that contract.
- Dataset models are read-only (`DatasetRecord`); the data is copied by
  `bin/rails banking:setup`, never committed.

## Gates

- `bin/rails test` (fixtures only; no dataset, no network) and `bin/ci`
  (RuboCop omakase, Brakeman with `config/brakeman.ignore`, audits).
- Live turns need `OPENROUTER_API_KEY` in `.env`; tests set a dummy key.

## Conventions

- Tools return JSON strings; `{ "error": ... }` is the recoverable failure
  the model can act on. Cap rows (`ApplicationTool::MAX_LIMIT`).
- Compose UI with `poetry_*` helpers and Poetry component classes; the only
  raw markup is layout wrappers (grid, tile chrome).
- Prose for the user, not for the model, goes in views; anything the model
  reads lives in `app/prompts/analyst/instructions.txt.erb` or a tool
  description.

<!-- poetry:agents:begin -->
## Building UI with poetry (88 components + 13 chart components + 8 blocks)

- FIRST MOVE on any UI brief: call the poetry MCP `compose` tool with the
  task text, before writing any ERB. It routes to the matching vetted
  block (source included, adapt in place - the winning path for screens)
  or to the right components. No MCP? `bin/rails g poetry:block --list`
  and start from the closest block. Composing a screen from scratch when
  a block matched is the known losing path.
- Compose with the `poetry_*` helpers; never hand-write `cn-*` classes, raw
  hex/oklch colors, or off-scale arbitrary values - tokens and variants carry
  the design.
- Machine catalog: `/poetry/llms.txt` (index + blocks) and `/poetry/llms-full.txt`
  (full contracts + Stimulus wiring: targets / values / actions / events).
- Check comes LAST: `bin/rails poetry:check` as the FINAL action, after
  the last edit (unknown components/slots/variants/wiring, icon names,
  enum values, typed-slot props, helper + setter arity, yield-less
  blocks, setter keywords, required content blocks, required slots,
  did-you-mean, `--json`; needs the `herb` gem in the Gemfile). An edit
  made after your last check is unverified markup - re-run it.
- Faster: the `poetry` MCP server (`.mcp.json`: command `bundle`, args
  `["exec", "poetry-agent"]`, the poetry-agent gem) serves ten tools from the live registry
  with no app boot - `compose`, `build_page`, `list_components`,
  `describe_component`, `check`, `list_blocks`, `describe_block`,
  `list_recipes`, `get_skill`, and `guidance`. Prefer `compose` (or `build_page` for a
  whole screen) to start, and its `check` tool when iterating. Wire it
  into every editor at once with `bin/rails g poetry:editor` (MCP
  configs for VS Code / Cursor / Claude Code / Zed / RubyMine plus
  registry-driven snippets).
- Browser agents (WebMCP): opt a rendered component into the user's own
  agent with `webmcp: "name"` on the helper call - Combobox, Dialog, Sheet,
  Drawer, and Tabs declare tools (`describe_component` at `full` lists them);
  declare a form as a tool with `poetry_webmcp_form(tool: { name:,
  description: })` (autosubmit is GET-only). Needs the poetry-agent gem and
  `registerPoetryAgent(application)`; `poetry:check` gates the opt-ins.
- One visual theme per app (chosen at install with `--theme`); components
  read tokens, never restate them.
- Component identity: pass `key:` (a record, or a literal string) on any
  poetry component inside a collection loop, a fragment-cache block, or
  a broadcast partial - keyed ids follow the record across Turbo morph
  reorders and stay stable inside cached fragments, where random ids
  force replacement. `key: record` derives via dom_id (a host `to_key`
  override propagates); explicit `id:` wins outright; repeated NEW
  records need explicit keys. `poetry:check` warns on unkeyed
  components in cache blocks and loops. Full story: the Stable IDs guide on the poetry docs site.
- Upgrading poetry gems: after `bundle update`, re-run
  `bin/rails g poetry:install` - the vendored token/theme/safelist
  files refresh (the installed theme sticks; `--theme` switches),
  new wiring appends, this section and the skills regenerate. Then
  rebuild CSS and run the suite. `bin/rails g poetry:diff` reports
  where copied-in components drift from the installed gems.
- `bin/rails g poetry:scaffold_templates` retargets the STANDARD
  `rails g scaffold` to emit poetry-composed views (DataTable index
  with URL state, Field-composed forms) plus a matching controller -
  prefer scaffolding over hand-writing CRUD views.
- Claude Code skills: `poetry` (component contracts by family),
  `poetry-design` (theme / compose / audit / study / figma / paper -
  the taste layer), and `poetry-component` (anatomy / documentation /
  audit - the authoring layer) live under `.claude/skills/` - load
  `poetry` whenever writing ERB, `poetry-design` whenever composing a
  page or screen, BEFORE building (any page task is a design task,
  not only ones that mention design), and `poetry-component` whenever
  authoring or reviewing an app-owned component. Install/refresh:
  `bin/rails g poetry:skill`.
- Design interop: `bin/rails poetry:design:export` writes this app's
  DESIGN.md (tokens + treatment) for external design skills.
- Overriding the theme: token-level restyling goes through
  `poetry:design:import` (design-overrides.css) - which also ingests a
  Figma variables export (`bin/rails poetry:figma:import[export.json]`)
  or a Paper "Copy theme" (`bin/rails poetry:paper:import[theme.css]`),
  dropping any swatch that fails WCAG AA. Host CSS that targets
  theme-owned `cn-*` classes is allowed ONLY as a declared
  override - a dated, reasoned entry under `overrides:` in
  config/poetry_components.yml (`bin/rails poetry:design:overrides`
  reports drift and prints the paste-ready declaration). Declare
  only after the user confirms intent; never declare to skip a fix.
<!-- poetry:agents:end -->
