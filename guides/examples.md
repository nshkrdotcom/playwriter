# Examples

Real-world examples of using Playwriter for common browser automation tasks.

## Basic Examples

### Fetch Page Content

```elixir
# Simple HTML fetch
{:ok, html} = Playwriter.fetch_html("https://example.com")
IO.puts("Got #{String.length(html)} bytes")

# With options
{:ok, html} = Playwriter.fetch_html("https://example.com",
  headless: true,
  timeout: 60_000
)
```

### Take Screenshots

```elixir
# Basic screenshot
{:ok, png} = Playwriter.screenshot("https://example.com")
File.write!("screenshot.png", png)

# Full page screenshot
{:ok, full_png} = Playwriter.screenshot("https://example.com", full_page: true)
File.write!("full_page.png", full_png)

# Multiple screenshots
urls = ["https://example.com", "https://elixir-lang.org", "https://hex.pm"]

Enum.each(urls, fn url ->
  {:ok, png} = Playwriter.screenshot(url)
  filename = url |> URI.parse() |> Map.get(:host) |> String.replace(".", "_")
  File.write!("#{filename}.png", png)
end)
```

## Web Scraping

### Scrape with Floki

```elixir
# Add {:floki, "~> 0.36"} to your deps

{:ok, html} = Playwriter.fetch_html("https://news.ycombinator.com")

titles =
  html
  |> Floki.parse_document!()
  |> Floki.find(".titleline > a")
  |> Enum.map(fn element ->
    %{
      title: Floki.text(element),
      href: Floki.attribute(element, "href") |> List.first()
    }
  end)

Enum.each(titles, fn %{title: title, href: href} ->
  IO.puts("#{title}\n  #{href}\n")
end)
```

### Scrape Dynamic Content

```elixir
# For JavaScript-rendered pages, the browser executes JS before returning content
{:ok, html} = Playwriter.fetch_html("https://spa-example.com")

# The HTML includes dynamically loaded content
products =
  html
  |> Floki.parse_document!()
  |> Floki.find(".product-card")
  |> Enum.map(fn card ->
    %{
      name: card |> Floki.find(".name") |> Floki.text(),
      price: card |> Floki.find(".price") |> Floki.text()
    }
  end)
```

## Form Interaction

### Login Form

```elixir
{:ok, dashboard_html} = Playwriter.with_browser([headless: false], fn ctx ->
  # Navigate to login page
  :ok = Playwriter.goto(ctx, "https://example.com/login")

  # Fill in credentials
  :ok = Playwriter.fill(ctx, "#username", "myuser")
  :ok = Playwriter.fill(ctx, "#password", "mypassword")

  # Submit the form
  :ok = Playwriter.click(ctx, "button[type=submit]")

  # Wait for navigation (simple approach)
  Process.sleep(2000)

  # Get the dashboard content
  {:ok, html} = Playwriter.content(ctx)
  html
end)
```

### Search Form

```elixir
{:ok, results} = Playwriter.with_browser([], fn ctx ->
  :ok = Playwriter.goto(ctx, "https://search-site.com")

  # Type in search box
  :ok = Playwriter.fill(ctx, "input[name=q]", "elixir programming")

  # Click search button
  :ok = Playwriter.click(ctx, "button[type=submit]")

  # Wait for results
  Process.sleep(1000)

  # Extract results
  {:ok, html} = Playwriter.content(ctx)

  html
  |> Floki.parse_document!()
  |> Floki.find(".search-result")
  |> Enum.map(&Floki.text/1)
end)
```

## Multi-Page Navigation

### Follow Links

```elixir
{:ok, article_content} = Playwriter.with_browser([], fn ctx ->
  # Start at index page
  :ok = Playwriter.goto(ctx, "https://blog.example.com")

  # Click first article link
  :ok = Playwriter.click(ctx, "article a.read-more")

  # Wait for page load
  Process.sleep(1000)

  # Get article content
  {:ok, html} = Playwriter.content(ctx)

  html
  |> Floki.parse_document!()
  |> Floki.find("article .content")
  |> Floki.text()
end)
```

### Pagination

```elixir
{:ok, all_items} = Playwriter.with_browser([], fn ctx ->
  :ok = Playwriter.goto(ctx, "https://example.com/products")

  items = collect_pages(ctx, [])
  items
end)

defp collect_pages(ctx, acc) do
  # Get current page items
  {:ok, html} = Playwriter.content(ctx)

  page_items =
    html
    |> Floki.parse_document!()
    |> Floki.find(".product-item")
    |> Enum.map(&Floki.text/1)

  new_acc = acc ++ page_items

  # Try to click next page
  case Playwriter.click(ctx, "a.next-page", timeout: 2000) do
    :ok ->
      Process.sleep(1000)
      collect_pages(ctx, new_acc)

    {:error, _} ->
      # No more pages
      new_acc
  end
end
```

## WSL to Windows

### Visible Browser Development

```elixir
# See the browser on your Windows desktop while developing
{:ok, result} = Playwriter.with_browser([mode: :remote, headless: false], fn ctx ->
  :ok = Playwriter.goto(ctx, "https://example.com")

  # Pause to inspect
  IO.puts("Browser is visible on Windows. Press Enter to continue...")
  IO.gets("")

  {:ok, html} = Playwriter.content(ctx)
  html
end)
```

### Debug Session

```elixir
defmodule DebugScraper do
  def run(url) do
    Playwriter.with_browser([mode: :remote, headless: false], fn ctx ->
      :ok = Playwriter.goto(ctx, url)

      debug_loop(ctx)
    end)
  end

  defp debug_loop(ctx) do
    IO.puts("\nCommands: content, screenshot, click <selector>, goto <url>, quit")

    case IO.gets("> ") |> String.trim() do
      "content" ->
        {:ok, html} = Playwriter.content(ctx)
        IO.puts("Got #{String.length(html)} bytes")
        debug_loop(ctx)

      "screenshot" ->
        {:ok, png} = Playwriter.screenshot(ctx)
        File.write!("debug.png", png)
        IO.puts("Saved to debug.png")
        debug_loop(ctx)

      "click " <> selector ->
        case Playwriter.click(ctx, selector) do
          :ok -> IO.puts("Clicked!")
          {:error, e} -> IO.puts("Error: #{inspect(e)}")
        end
        debug_loop(ctx)

      "goto " <> url ->
        :ok = Playwriter.goto(ctx, url)
        IO.puts("Navigated!")
        debug_loop(ctx)

      "quit" ->
        :done

      other ->
        IO.puts("Unknown command: #{other}")
        debug_loop(ctx)
    end
  end
end

# Usage: DebugScraper.run("https://example.com")
```

## Error Handling

### Retry on Failure

```elixir
defmodule RobustScraper do
  def fetch_with_retry(url, opts \\ []) do
    max_retries = Keyword.get(opts, :max_retries, 3)
    delay = Keyword.get(opts, :retry_delay, 1000)

    do_fetch(url, opts, max_retries, delay)
  end

  defp do_fetch(url, opts, retries_left, delay) do
    case Playwriter.fetch_html(url, opts) do
      {:ok, html} ->
        {:ok, html}

      {:error, reason} when retries_left > 0 ->
        IO.puts("Retry #{retries_left} after error: #{inspect(reason)}")
        Process.sleep(delay)
        do_fetch(url, opts, retries_left - 1, delay * 2)

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

### Graceful Degradation

```elixir
def scrape_safely(url) do
  case Playwriter.fetch_html(url, timeout: 30_000) do
    {:ok, html} ->
      parse_content(html)

    {:error, :timeout} ->
      Logger.warning("Timeout fetching #{url}")
      {:error, :timeout}

    {:error, {:navigation_failed, _}} ->
      Logger.warning("Navigation failed for #{url}")
      {:error, :navigation_failed}

    {:error, reason} ->
      Logger.error("Unexpected error: #{inspect(reason)}")
      {:error, reason}
  end
end
```

## Batch Processing

### Concurrent Scraping

```elixir
defmodule BatchScraper do
  def scrape_urls(urls, concurrency \\ 5) do
    urls
    |> Task.async_stream(
      fn url ->
        case Playwriter.fetch_html(url) do
          {:ok, html} -> {url, {:ok, html}}
          {:error, reason} -> {url, {:error, reason}}
        end
      end,
      max_concurrency: concurrency,
      timeout: 60_000
    )
    |> Enum.map(fn {:ok, result} -> result end)
  end
end

# Usage
urls = [
  "https://example.com",
  "https://elixir-lang.org",
  "https://hex.pm"
]

results = BatchScraper.scrape_urls(urls)
```

## Testing Integration

### ExUnit Integration

```elixir
defmodule MyApp.BrowserTest do
  use ExUnit.Case

  @tag :browser
  test "homepage loads correctly" do
    {:ok, html} = Playwriter.fetch_html("http://localhost:4000")

    assert String.contains?(html, "Welcome")
    assert String.contains?(html, "<title>My App</title>")
  end

  @tag :browser
  test "login flow works" do
    {:ok, result} = Playwriter.with_browser([headless: true], fn ctx ->
      :ok = Playwriter.goto(ctx, "http://localhost:4000/login")
      :ok = Playwriter.fill(ctx, "#email", "test@example.com")
      :ok = Playwriter.fill(ctx, "#password", "password123")
      :ok = Playwriter.click(ctx, "button[type=submit]")

      Process.sleep(500)

      {:ok, html} = Playwriter.content(ctx)
      String.contains?(html, "Dashboard")
    end)

    assert result == true
  end
end
```

Run browser tests:
```bash
mix test --only browser
```
