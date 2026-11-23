# Troubleshooting

## Driver or browser missing

Check the transport you intend to use:

```bash
mix playwriter.setup --mode local --check
mix playwriter.setup --mode windows --check
```

Run the matching command without `--check` to provision missing or stale assets. If you use `PLAYWRIGHT_BROWSERS_PATH`, use the same path for setup and runtime. A local Linux launch that reports missing system libraries can be repaired with `mix playwriter.setup --with-deps` when you intend to authorize those package changes.

## Windows Node or PowerShell missing

Verify the Windows runtime with `Get-Command node.exe, npm.cmd` from Windows PowerShell and check WSL interop with `powershell.exe -NoProfile -NonInteractive -Command 'whoami; $env:TEMP'` from WSL. See [WSL–Windows Setup](wsl-windows.md) for account and PATH checks. A user override must match the account running the PowerShell process.

If Windows Code Integrity blocks the managed Chromium build, use a supported, installed browser channel permitted by your host policy. See [Use an installed Windows browser](wsl-windows.md#use-an-installed-windows-browser).

## Browser opens and immediately closes

One-shot calls close their browser after finishing. Use a session or a visible example to keep the window open during several actions. See [Usage Examples](examples.md).

## Unsupported transport

Use `:windows` for visible browser automation from WSL and `:local` for same-host automation. Playwriter's legacy `:remote` transport returns `{:error, :not_supported}`.

## Navigation Issues

### Page doesn't load completely

JavaScript content not rendered.

**Solution - wait longer:**
```elixir
Playwriter.with_browser([], fn ctx ->
  :ok = Playwriter.goto(ctx, url)
  Process.sleep(3000)  # Wait for JS
  {:ok, html} = Playwriter.content(ctx)
  html
end)
```

**Solution - use wait_until:**
```elixir
:ok = Playwriter.goto(ctx, url, wait_until: :networkidle)
```

### "Navigation timeout"

Page takes too long to load.

**Solutions:**
```elixir
# Increase navigation timeout
:ok = Playwriter.goto(ctx, url, timeout: 60_000)

# Or don't wait for full load
:ok = Playwriter.goto(ctx, url, wait_until: :domcontentloaded)
```

### SSL/Certificate errors

Site has invalid certificates.

**Solution:**
```elixir
Playwriter.with_browser([ignore_https_errors: true], fn ctx ->
  :ok = Playwriter.goto(ctx, "https://self-signed.example.com")
end)
```

## Element Interaction Issues

### "Element not found"

Selector doesn't match any element.

**Debug steps:**
1. Verify selector in browser DevTools
2. Check if element is in an iframe
3. Wait for element to appear:
   ```elixir
   Process.sleep(1000)
   :ok = Playwriter.click(ctx, selector)
   ```

### "Element not clickable"

Element is covered or not visible.

**Solutions:**
- Scroll element into view
- Wait for animations to complete
- Check for overlays/modals

### "Element detached"

Page changed while interacting.

**Solution:**
```elixir
# Re-query after navigation
:ok = Playwriter.goto(ctx, url)
Process.sleep(500)
:ok = Playwriter.click(ctx, selector)
```

## Performance Issues

### Slow scraping

**Tips:**
1. Use headless mode:
   ```elixir
   Playwriter.fetch_html(url, headless: true)
   ```

2. Use local transport for production:
   ```elixir
   Playwriter.fetch_html(url, mode: :local)
   ```

3. Disable images (if supported):
   ```elixir
   # Custom context options
   ```

4. Reuse browser sessions for multiple pages

### Memory issues

Many browser instances consuming memory.

**Solutions:**
- Ensure sessions are closed properly
- Use `with_browser/2` which handles cleanup
- Limit concurrent sessions
- Monitor with `:observer.start()`

## Debugging Tips

### Enable verbose logging

```elixir
# In config/dev.exs
config :logger, level: :debug
```

### Inspect session state

```elixir
Playwriter.with_browser([], fn ctx ->
  # Get session state
  state = :sys.get_state(ctx.session)
  IO.inspect(state, label: "Session state")

  :ok
end)
```

### Take debug screenshots

```elixir
Playwriter.with_browser([headless: false], fn ctx ->
  :ok = Playwriter.goto(ctx, url)

  # Before action
  {:ok, before} = Playwriter.screenshot(ctx)
  File.write!("/tmp/before.png", before)

  result = Playwriter.click(ctx, selector)

  # After action (or on error)
  {:ok, after_shot} = Playwriter.screenshot(ctx)
  File.write!("/tmp/after.png", after_shot)

  result
end)
```

### Interactive debugging

```elixir
# Pause to inspect browser
Playwriter.with_browser([mode: :windows, headless: false], fn ctx ->
  :ok = Playwriter.goto(ctx, url)

  IO.puts("Inspect the browser now. Press Enter to continue...")
  IO.gets("")

  {:ok, html} = Playwriter.content(ctx)
  html
end)
```

## Getting Help

If you're still stuck:

1. Check existing issues: https://github.com/yourusername/playwriter/issues
2. Open a new issue with:
   - Playwriter version (`Playwriter.version()`)
   - Elixir/OTP versions (`elixir -v`)
   - Operating system
   - Minimal reproduction code
   - Full error message/stacktrace
