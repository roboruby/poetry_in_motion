# Poetry in Motion

A Rails app whose screens are composed while you talk. You ask an operations analyst about a
synthetic bank; the analyst answers through [RubyLLM](https://rubyllm.com) and builds the
workspace around the conversation out of [Poetry](https://poetryui.com) components: KPI rows,
tables, charts, customer cards, filter forms, buttons that ask the next question for you.

It is the reference implementation for Poetry's RubyLLM installer: what `rails g ruby_llm:chat_ui`
scaffolds, rebuilt on Poetry's chat components and grown into a generative UI workspace.

## Setup

Ruby 4.0 and Rails 8.1 (see `.ruby-version`), SQLite. No Node: JavaScript ships through importmap
and Tailwind builds through `tailwindcss-rails`. The dataset ships in the repo, so the first run
needs no download.

```sh
bin/setup                 # bundle install, database, dataset import (about 30 seconds)
cp .env.example .env      # put your OpenRouter key in it
bin/dev                   # http://localhost:3000
```

`bin/setup` runs `bin/rails banking:setup`, which extracts `db/data/bank_sqlite.db.tar.xz`
(32 MB in git, 107 MB extracted; `tar` handles the xz on macOS and on Linux with `xz` installed)
into `tmp/banking/` and copies all seven tables into the app database with the dataset's own ids:
50,000 customers, 75,000 accounts, 100,000 cards, 5,000 merchants, 500 branches, 30,000 loans,
1,000,000 transactions. Re-run with `FORCE=1` to reimport; `bin/rails banking:stats` prints the
counts. If the bundled archive is ever removed, the task falls back to Kaggle's public download.

The model comes from [OpenRouter](https://openrouter.ai). `OPENROUTER_API_KEY` is read from `.env`
in development and test (dotenv) or from the environment. `POETRY_IN_MOTION_MODEL` picks any
OpenRouter model with tool calling; the default is `anthropic/claude-opus-5`. Without a key the
app runs, shows the workspaces, and tells you in the chat panel that the analyst cannot answer.

## Using it

Open the app and press **New workspace**. A workspace is one conversation and the screens it
produced; the list on the home page shows every workspace with its surface count.

**The chat panel** starts center stage on the empty canvas with four suggested questions. Type a
question and press Enter (Shift+Enter breaks a line), or click a suggestion. As the analyst works,
the panel shows activity lines ("Searched customers · Ada", "10 rows", "Composed a surface · Top
merchants"), a status line ("Querying transactions", "Composing the workspace", "Retrying"), and
then the reply as text. The reply is deliberately short: the answer is on the canvas.

**The canvas** fills with surfaces as answers arrive. Each surface is a titled tile: a dashboard
of KPIs with charts and tables, a customer profile with its accounts and recent activity, a ranked
list, a trend chart, a filter form. When the first surface lands, the chat panel docks to the
bottom right; the minimize button collapses it to a pill that counts unread lines, and the pill
opens it again. The × on a tile removes that surface without asking the analyst.

**Surfaces talk back.** A button inside a surface ("Show merchant detail", "Show all
transactions") sends its event and any bound fields to the analyst as a new turn, marked in the
chat as "You pressed …". Filter fields (text, choices, dates) carry their values along; a field
with a check (required, email, numeric) is validated in the browser and again on the server, and a
failed check re-renders the surface with the message instead of asking the analyst.

**Follow-ups evolve the canvas.** Refining a question about the same subject updates the existing
surface in place (new rows, a retitle, another chart) rather than adding a duplicate; a new subject
gets a new surface. Ask to remove something and it goes.

Good first questions: "Give me an overview of the bank", "Which merchants take the most money?",
"Show me our riskiest large loans", "How did transaction volume move through 2025?", "Find
customers in London with excellent credit", "Open the profile for CUS000MKX5RHTAP".

## How it works

**A chat is a workspace.** `Chat` and `Message` are RubyLLM's `acts_as_chat` / `acts_as_message`
records. The workspace state is not HTML: `ui_events` stores the A2UI messages the analyst emitted
(`createSurface`, `updateComponents`, `updateDataModel`, `deleteSurface`), and `Chat#surface_session`
replays them through poetry-agent's `Poetry::Agent::A2UI::Session` on every request.

**The analyst** (`app/agents/analyst.rb`, prompt in `app/prompts/analyst/instructions.txt.erb`) gets
two kinds of tools from `app/tools/`:

- Data tools query the dataset in SQL and answer JSON: `bank_overview`, `search_customers`,
  `customer_profile`, `transactions`, `loans`, `merchants`, `branches`, and `aggregate` (any metric
  by month, year, account type, card type, city, merchant, or credit band, narrowed to one
  merchant, customer, or account when asked).
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
turn; `Workspace::Streamer` owns every broadcast. When the provider fails mid-stream or a tool
call's JSON is cut off before it closes (OpenRouter reports the reason in the last chunk; the
guard in `config/initializers/ruby_llm_stream_guard.rb` reads it), the job retries the turn twice,
telling the model to send a smaller surface when its own output size was the cause.

**Two-way surfaces.** A `Button` with an agent event posts to `SurfaceActionsController`: the
bound inputs are written into the surface's data model (and the event log), the event becomes a
user turn prefixed `[ui action]`, and the analyst answers by updating the workspace.

**The dock** (`workspace_controller.js`) has three states: `hero` while the canvas is empty,
`docked` bottom-right once a surface exists, `minimized` as a pill with an unread count. The
canvas and the dock are one page; nothing is client-rendered beyond Stimulus.

## Layout

```
app/agents/analyst.rb              model, tools, instructions
app/prompts/analyst/               the system prompt (ERB over the vocabulary)
app/tools/                         RubyLLM tools: data and surfaces
app/lib/workspace/                 vocabulary, catalog, composer, streamer, text stream
app/lib/banking/                   dataset extraction and import
app/models/{customer,account,...}  read-only dataset models
app/models/{chat,message,ui_event} the conversation and the surface event log
app/views/chats/_dock.html.erb     the chat panel
app/views/surfaces/                tiles and A2UI surfaces
app/javascript/controllers/        workspace (dock states) and composer
config/initializers/ruby_llm*.rb   RubyLLM configuration and the stream guard
db/data/                           the dataset archive and its license note
```

## Tests

```sh
bin/rails test        # models, catalog, composer, tools, controllers, the job, the stream guard
bin/ci                # the full check: tests, RuboCop, Brakeman, bundler-audit
```

Tests run against small fixtures and never call a model; the dataset is only needed to use the app.

## Credits

Dataset: [Synthetic Banking Dataset](https://www.kaggle.com/datasets/akrambelha/synthetic-banking-dataset-csv-sql-sqlite)
by akrambelha, CC BY 4.0, redistributed unchanged in `db/data/`. Fully synthetic; no real people or
accounts.
