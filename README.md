# Poetry in Motion

A Rails app where the user interface is composed while you talk. An operations analyst for a
synthetic bank answers questions through [RubyLLM](https://rubyllm.com) and builds the screen
around the conversation out of [Poetry](https://poetryui.com) components: KPI rows, tables, charts,
customer cards, filter forms. The chat starts center stage on an empty workspace, docks to the
bottom-right once the first surface lands, and every surface can talk back (a button on a card is
a new turn for the analyst).

It is the reference implementation for Poetry's RubyLLM installer: what `rails g ruby_llm:chat_ui`
scaffolds, rebuilt on Poetry's chat components and extended into a generative UI workspace.

## Setup

Ruby 4.0, Rails 8.1, SQLite, Node is not required (importmap, Tailwind via `tailwindcss-rails`).

```sh
bin/setup                 # bundle, database, and the banking dataset (about 170 MB download)
cp .env.example .env      # then put your OpenRouter key in it
bin/dev                   # http://localhost:3000
```

`bin/rails banking:setup` downloads the [synthetic banking dataset](https://www.kaggle.com/datasets/akrambelha/synthetic-banking-dataset-csv-sql-sqlite)
(Kaggle, CC BY 4.0: 50,000 customers, 75,000 accounts, 100,000 cards, 30,000 loans, 1,000,000
transactions, 5,000 merchants, 500 branches) into `tmp/banking` and copies every table into the
app database with the dataset's own ids. `banking:import` re-runs the copy; `banking:stats` prints
the row counts. Nothing from the dataset is committed.

The model comes from OpenRouter. `OPENROUTER_API_KEY` is read from `.env` (development and test)
or the environment; `POETRY_IN_MOTION_MODEL` picks any OpenRouter model with tool calling
(default `anthropic/claude-opus-5`).

## How it works

**A chat is a workspace.** `Chat` and `Message` are RubyLLM's `acts_as_chat` / `acts_as_message`
records. The workspace state is not HTML: `ui_events` stores the A2UI messages the analyst emitted
(`createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`), and `Chat#surface_session`
replays them through poetry-agent's `Poetry::Agent::A2UI::Session` on every request.

**The analyst** (`app/agents/analyst.rb`, prompt in `app/prompts/analyst/instructions.txt.erb`) gets
two kinds of tools from `app/tools/`:

- Data tools query the dataset in SQL and answer JSON: `bank_overview`, `search_customers`,
  `customer_profile`, `transactions`, `loans`, `merchants`, `branches`, and `aggregate` (any metric
  by month, year, account type, card type, city, merchant, or credit band).
- UI tools put Poetry on the page: `render_surface`, `update_surface`, `remove_surface`. Their
  parameters are the component vocabulary in `app/lib/workspace/vocabulary.rb`, declared once and
  reflected as the prompt text, the tool JSON schema, and the catalog the renderer understands.

**Rendering** is poetry-agent's A2UI renderer with a custom catalog (`app/lib/workspace/catalog.rb`):
the spec's basic catalog (text, layout, forms, buttons) plus `Grid`, `Stat`, `Badge`, `Table`,
`Chart` (bar, line, area, pie, donut from poetry-charts), `Metadata`, and `Empty`. Every component
renders a Poetry component; the analyst never writes HTML. `Workspace::Composer` validates a
surface by replaying the session and rendering it once, persists the accepted messages, and streams
the changed tiles over Turbo Streams. Rejected surfaces (an unknown component, a cycle) come back
to the model as errors and persist nothing. A surface's data model can point at a tool's latest
result (`{ "fromTool": "merchants", "key": "rows" }`) so the model never retypes rows it just
fetched; the composer copies the result in before validating.

**Streaming** follows Poetry's message scroller contract: rows are appended when a message is
created and morphed in place while the assistant writes, through poetry-agent's versioned
`vreplace` stream action, so a late frame never repaints a settled row. `ChatResponseJob` runs the
turn; `Workspace::Streamer` owns every broadcast.

**Two-way surfaces.** A `Button` with an agent event posts to `SurfaceActionsController`: the
bound inputs are written into the surface's data model (and the event log), the event becomes a
user turn prefixed `[ui action]`, and the analyst answers by updating the workspace. Checks
(`required`, `email`, `regex`, ...) run in the browser and again on the server; a failed check
re-renders the surface with its errors and no turn.

**The dock** (`workspace_controller.js`) has three states: `hero` while the canvas is empty,
`docked` bottom-right once a surface exists, `minimized` as a pill with an unread count. The
canvas and the dock are one page; nothing is client-rendered beyond Stimulus.

## Layout

```
app/agents/analyst.rb              model, tools, instructions
app/prompts/analyst/               the system prompt (ERB over the vocabulary)
app/tools/                         RubyLLM tools: data and surfaces
app/lib/workspace/                 vocabulary, catalog, composer, streamer, text stream
app/lib/banking/                   dataset download and import
app/models/{customer,account,...}  read-only dataset models
app/models/{chat,message,ui_event} the conversation and the surface event log
app/views/chats/_dock.html.erb     the chat panel
app/views/surfaces/                tiles and A2UI surfaces
app/javascript/controllers/        workspace (dock states) and composer
```

## Tests

```sh
bin/rails test        # models, catalog, composer, tools, controllers, the job
bin/ci                # the full check: tests, RuboCop, Brakeman, bundler-audit
```

Tests run against small fixtures; the dataset is only needed to use the app.

## Credits

Dataset: [Synthetic Banking Dataset](https://www.kaggle.com/datasets/akrambelha/synthetic-banking-dataset-csv-sql-sqlite)
by akrambelha, CC BY 4.0. Fully synthetic; no real people or accounts.
