# Automation Capabilities

Beyond navigation, clicking, and form-filling, Playwriter exposes the
lower-level browser-automation surface that a dev/test harness needs: arbitrary
JavaScript evaluation, predicate waiting, context init scripts, CDP-based
network fault injection, clean binary returns, and (experimentally) page-to-Elixir
callbacks.

Every capability is a callback on `Playwriter.Transport.Behaviour`, implemented
by each transport, and surfaced as a `Playwriter.Browser.Session` function. The
page-scoped ones also have thin `Playwriter` facade wrappers for use inside
`with_browser/2`.

## Transport support matrix

| Capability | `:windows` | `:local` | `:remote` |
|---|:---:|:---:|:---:|
| `evaluate/4` | ✅ | ✅ | — |
| `wait_for_function/4` | ✅ | ✅ | — |
| `add_init_script/4` | ✅ | ✅ | — |
| `add_cookies/3` + `storage_state/2` | ✅ | ✅ | — |
| `new_cdp_session/2` + `cdp_send/4` | ✅ | `:not_supported` | — |
| `expose_binding/4` | ✅ (experimental) | `:not_supported` | — |
| binary returns (`screenshot/3`) | ✅ `value_b64` | ✅ | — |

`:remote` is a deliberate dead stub (WSL2's Hyper-V firewall blocks its
WebSocket); every callback returns `{:error, :not_supported}`.

## `evaluate/4` — run JavaScript, get the result

```elixir
{:ok, true}  = Session.evaluate(session, page, "crossOriginIsolated")
{:ok, title} = Session.evaluate(session, page, "document.title")

# Pass an argument to a function body
{:ok, 42} = Session.evaluate(session, page, "(n) => n * 2", arg: 21, is_function: true)
```

Options: `:is_function` (treat the expression as a function body, default
`false`), `:arg` (argument passed to the function), `:timeout` (ms).

On the Windows wire protocol the result comes back in a distinct `{"json": v}`
envelope, so an evaluated value that itself looks like a handle (e.g. a map with
a `"guid"` key) is never misinterpreted.

## `wait_for_function/4` — poll until truthy

```elixir
:ok = Session.wait_for_function(session, page, "window.__ready === true", timeout: 60_000)
{:error, _} = Session.wait_for_function(session, page, "false", timeout: 500)
```

Options: `:is_function`, `:arg`, `:polling` (a number of ms or `"raf"`,
default `"raf"`), `:timeout`. Returns `:ok` once the predicate is truthy, or
`{:error, _}` on timeout. This is the backbone of the harness's
"snapshot-and-assert" loop.

## `add_init_script/4` — seed the page before it loads

```elixir
{:ok, ctx} = Session.new_context(session, [])
:ok = Session.add_init_script(session, ctx, "window.__debug = 1")
{:ok, page} = Session.new_page(session, context_guid: ctx)
# the script has already run by the time any page script executes
```

The script is **context-scoped** and runs before any page script on every page
and navigation in that context — so it must be added **before** `new_page/2`.
Use it to install a debug bridge or seed determinism (`Math.random`, timers).

## `add_cookies/3` + `storage_state/2` — start past an auth gate

For apps behind a login/onboarding gate, seed a pre-signed session cookie
instead of driving the login UI every test:

```elixir
{:ok, ctx} = Session.new_context(session, [])

:ok = Session.add_cookies(session, ctx, [
  %{name: "_listener_web_key", value: signed_cookie,
    domain: "localhost", path: "/", sameSite: "Lax"}
])

{:ok, page} = Session.new_page(session, context_guid: ctx)   # already authenticated
```

Cookie maps use Playwright's field names (`name`, `value`, and either `url` or
`domain`+`path`; optionally `httpOnly`, `secure`, `sameSite`, `expires`).

Alternatively, log in once through the real forms (`fill/4` + `click/4`),
capture the context's cookies + localStorage with `storage_state/2`, and re-seed
the cookies with `add_cookies/3` in later runs:

```elixir
{:ok, state} = Session.storage_state(session, ctx)   # %{"cookies" => [...], "origins" => [...]}
```

## CDP — network fault injection (`:windows` only)

```elixir
{:ok, cdp} = Session.new_cdp_session(session, page)

{:ok, _} = Session.cdp_send(session, cdp, "Network.emulateNetworkConditions", %{
  offline: false, latency: 200, downloadThroughput: 100_000, uploadThroughput: 100_000
})

{:ok, _} = Session.cdp_send(session, cdp, "Network.setBlockedURLs", %{urls: ["*://ads.example/*"]})
```

`new_cdp_session/2` opens a Chrome DevTools Protocol session for a page (via
`page.context().newCDPSession(page)` inside the Windows Node script) and returns
an opaque session id; `cdp_send/4` sends CDP commands over it.

`playwright_ex` exposes no CDP surface, so the `:local` transport returns
`{:error, :not_supported}` for both. For the headless-Linux backend prefer
server-side fault injection.

## Binary returns

Binary results (e.g. `screenshot/3`) use an explicit base64 contract: the
Windows Node script returns `{"value_b64": "<base64>"}`, which Playwriter decodes
with `Base.decode64!/1`. This replaces earlier magic-byte sniffing, so a `{"value"}`
string (like `content/2`'s HTML) is never mistaken for an image and vice-versa.

```elixir
{:ok, png} = Session.screenshot(session, page, [])
<<0x89, 0x50, 0x4E, 0x47, _::binary>> = png    # decoded PNG bytes
```

## `expose_binding/4` — page → Elixir callbacks (experimental)

> **Experimental, `:windows`-only.** This is the one verb that needs a
> bidirectional event channel over the stdio bridge. The request/response verbs
> are unaffected, and the message routing is unit-tested, but the full
> page → Elixir round trip is validated only on a Windows box (the
> `:requires_windows_server` suite). Prefer polling with `evaluate/4` +
> `wait_for_function/4` where you can.

```elixir
{:ok, ctx} = Session.new_context(session, [])

:ok = Session.expose_binding(session, ctx, "report", fn [payload] ->
  send(orchestrator, {:from_page, payload})
  :ack
end)

{:ok, page} = Session.new_page(session, context_guid: ctx)
# the page can now call window.report(data); the callback receives [data]
```

The callback is invoked with the argument list the page passed, and its return
value is passed back to the page. Register the binding on the context before
creating the page.

## Provisioning the `:local` driver

The `:local` transport shells out to a Node Playwright driver. Provision it
reproducibly:

```bash
mix playwriter.setup            # npm ci + npx playwright install chromium
mix playwriter.setup --with-deps  # also install OS libraries (needs sudo)
```

The driver is resolved from `PLAYWRIGHT_CLI`, then
`config :playwriter, :playwright_cli`, then `node_modules/playwright/cli.js`. The
pinned version lives in the project's `package.json` and tracks the version
`playwright_ex` targets.
