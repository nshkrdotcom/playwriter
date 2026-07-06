# AGENTS.md — working in Playwriter

Guidance for agents and contributors working in this repository. Keep it
green, keep it small, and respect the two-Node-Playwright reality.

## What this library is

Elixir browser automation with a focus on driving a **visible Windows browser
from WSL**. Three transports behind one behaviour:

- `Playwriter.Transport.WindowsCmd` (`mode: :windows`) — the working WSL→Windows
  path. Elixir `Port` → `pwsh.exe`/`powershell.exe` → an embedded Node script
  (the `@node_script` heredoc) speaking newline-delimited JSON
  `{id, method, params}` ↔ `{id, result|error}` over stdio.
- `Playwriter.Transport.Local` (`mode: :local`) — headless, same machine; wraps
  the `playwright_ex` hex driver.
- `Playwriter.Transport.Remote` (`mode: :remote`) — a deliberate **dead stub**
  (WSL2's Hyper-V firewall blocks its WebSocket); every callback returns
  `{:error, :not_supported}`.

`Playwriter.Transport.Behaviour` is the contract: **one `@callback` per verb**.
Adding a callback is a compile-time obligation for `WindowsCmd`, `Local`,
`Remote`, **and** the Mox mock (`test/test_helper.exs`, auto-expands).
`Playwriter.Browser.Session` dispatches (`call_transport/3`), resolving
page/frame/context guids via `get_page_info/2`. On `:windows`, page == frame.

## The green bar

```
mix check
```

is `format --check-formatted` → `credo --strict` → `compile --warnings-as-errors`
→ `dialyzer` → `test`. Nothing lands red. If deps changed, the Dialyzer PLT may
need a rebuild (it happens automatically on the next `mix dialyzer`).

## Tests are tag-gated

Default `mix test` runs the **pure-unit + Mox** suite only. These tags are
excluded by default (`test/test_helper.exs`):
`:integration, :requires_browser, :requires_windows_server, :wsl_only, :chaos`.

- `INTEGRATION=true mix test` — includes `:requires_browser` (the `:local`
  headless path). Needs `mix playwriter.setup` first (Node driver + Chromium).
- `WINDOWS_SERVER=true mix test` — includes `:requires_windows_server` (the
  `:windows` visible-desktop path). Needs a WSL+Windows box with Node/Playwright
  installed on the Windows side.

Prefer a **Mox unit test** (inject via `Session.start_link(transport_module:
Mock)`) or a **pure-function test** of the `WindowsCmd` protocol
(`encode_command/3`, `process_result/1`, `split_messages/2`,
`classify_message/1`) before reaching for a browser. After editing the embedded
Node script, `node --check` it:

```
mix run -e 'File.write!("/tmp/t.js", Playwriter.Transport.WindowsCmd.node_script())'
node --check /tmp/t.js
```

## Adding a capability

Each verb is coordinated across: a `@callback` in `behaviour.ex`; the `:windows`
impl (a `case` in `@node_script` + client `@impl` fn + `handle_call`); the
`:local` impl (`local.ex`, via a `playwright_ex` helper where one exists); a
`{:error, :not_supported}` stub in `remote.ex`; the `Session` function +
`handle_call` (resolve the guid); and an optional `Playwriter` facade wrapper.

Binary returns use the explicit `{"value_b64": ...}` envelope (decoded with
`Base.decode64!/1`) — do not add magic-byte sniffing back.

## The two-version-string rule (release gotcha)

The version is hardcoded in **two** places and both must match, or
`Playwriter.version/0` will lie:

- `mix.exs` `@version`
- `lib/playwriter.ex` `def version, do: "..."`

## The two Node Playwrights

- `:local` uses the driver resolved from `PLAYWRIGHT_CLI` /
  `config :playwriter, :playwright_cli` / `node_modules/playwright/cli.js`
  (pinned in the repo `package.json`, tracking the version `playwright_ex`
  targets). Provision with `mix playwriter.setup`.
- `:windows` provisions its **own** Node Playwright on the Windows side (pinned
  in the `package.json` heredoc in `windows_cmd.ex`). Keep the two versions in
  the same major line.

## Packaging

`package.files` in `mix.exs` is a **whitelist**. The Windows Node script ships
embedded in `lib/`. Never ship `node_modules`, `_build`, `deps`, or
`priv/plts`. Run `mix hex.build` and inspect the tarball before releasing.
`mix docs` must be warning-free (every module in a `groups_for_modules` group,
every guide in `docs.extras`).
