# Troubleshooting

Common issues and their solutions when using Playwriter.

## Installation Issues

### "playwright_ex driver not found"

The Playwright Node.js driver isn't installed.

**Solution:**
```bash
mix playwright.install
```

Or manually:
```bash
cd deps/playwright_ex
npm install
npx playwright install chromium
```

### "Browser executable not found"

Playwright browsers aren't installed.

**Solution:**
```bash
npx playwright install chromium
# Or for all browsers:
npx playwright install
```

### Missing System Dependencies (Linux)

Chromium needs certain system libraries.

**Solution:**
```bash
# Debian/Ubuntu
npx playwright install-deps chromium

# Or manually
sudo apt-get install -y libwoff1 libopus0 libwebpdemux2 libgudev-1.0-0 \
  libsecret-1-0 libhyphen0 libgdk-pixbuf2.0-0 libegl1 libnotify4 libxslt1.1 \
  libevent-2.1-7 libgles2 libvpx7 libxcomposite1 libatk1.0-0 libatk-bridge2.0-0 \
  libepoxy0 libgtk-3-0 libharfbuzz-icu0
```

## Connection Issues

### "Connection refused" (Remote Mode)

The Playwright server isn't running or isn't accessible.

**Checklist:**
1. Is the server running?
   ```powershell
   # On Windows
   npx playwright run-server --port 3337
   ```

2. Is the port open?
   ```powershell
   # Windows
   netstat -an | findstr 3337
   ```

3. Is Windows Firewall blocking it?
   - Allow Node.js through firewall
   - Or temporarily disable for testing

4. Is the endpoint correct?
   ```elixir
   # Try explicit endpoint
   Playwriter.fetch_html(url,
     mode: :remote,
     ws_endpoint: "ws://localhost:3337/"
   )
   ```

### "Discovery failed"

Auto-discovery can't find a Playwright server.

**Debug steps:**
```elixir
# Check what discovery tries
{:ok, endpoint} = Playwriter.Server.Discovery.discover(timeout: 10_000)

# Check WSL gateway IP
{:ok, ip} = Playwriter.Server.Discovery.get_wsl2_host_ip()
IO.puts("Gateway IP: #{ip}")

# Try connecting manually
{:ok, html} = Playwriter.fetch_html(url,
  mode: :remote,
  ws_endpoint: "ws://#{ip}:3337/"
)
```

### "WebSocket timeout"

Connection established but operations time out.

**Solutions:**
- Increase timeout:
  ```elixir
  Playwriter.fetch_html(url, timeout: 120_000)
  ```
- Check network latency between WSL and Windows
- Ensure server isn't overloaded

## Browser Issues

### Browser doesn't appear (Remote Mode)

**Ensure headless is false:**
```elixir
Playwriter.fetch_html(url, mode: :remote, headless: false)
```

**Check browser is installed on Windows:**
```powershell
npx playwright install chromium
```

### Wrong browser type

**Specify browser:**
```elixir
Playwriter.fetch_html(url, browser_type: :firefox)
```

**Install the browser:**
```bash
npx playwright install firefox
npx playwright install webkit
```

### "Browser closed unexpectedly"

The browser crashed or was killed.

**Possible causes:**
- Out of memory
- Browser version incompatibility
- Corrupted browser installation

**Solutions:**
```bash
# Reinstall browsers
npx playwright install --force

# Use different browser
Playwriter.fetch_html(url, browser_type: :firefox)
```

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

## WSL-Specific Issues

### Can't reach Windows from WSL

**Check WSL version:**
```bash
wsl.exe -l -v
```

**WSL 2 networking:**
```bash
# Get Windows host IP
cat /etc/resolv.conf | grep nameserver
```

**WSL 1 networking:**
- Should use `localhost` directly

### Slow network between WSL and Windows

**Solutions:**
- Use localhost instead of IP when possible
- Consider WSL 1 for lower latency
- Run Elixir natively on Windows if latency is critical

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
Playwriter.with_browser([mode: :remote, headless: false], fn ctx ->
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
