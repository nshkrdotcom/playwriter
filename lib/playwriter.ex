defmodule Playwriter do
  @moduledoc """
  Cross-platform browser automation with WSL-to-Windows support.

  Playwriter provides a simple, composable API for browser automation,
  with special support for running in WSL while controlling a visible
  browser on Windows.

  ## Quick Start

      # Fetch HTML from a URL (headless)
      {:ok, html} = Playwriter.fetch_html("https://example.com")

      # Fetch with visible browser on Windows
      {:ok, html} = Playwriter.fetch_html("https://example.com",
        mode: :remote,
        ws_endpoint: "ws://localhost:3337/"
      )

      # Take a screenshot
      {:ok, png_data} = Playwriter.screenshot("https://example.com")
      File.write!("screenshot.png", png_data)

      # Full control with session
      {:ok, result} = Playwriter.with_browser(headless: true, fn ctx ->
        Playwriter.goto(ctx, "https://example.com")
        Playwriter.click(ctx, "button.accept")
        Playwriter.content(ctx)
      end)

  ## Transport Modes

  - `:local` - Uses playwright_ex with local browser (default)
  - `:remote` - Connects to a Playwright server via WebSocket
  - `:auto` - Auto-detects best transport

  ## WSL-to-Windows Integration

  To use a visible browser from WSL:

  1. Start the Playwright server on Windows:

         powershell.exe -File scripts/start_server.ps1

  2. Connect from your Elixir code:

         Playwriter.fetch_html("https://example.com",
           mode: :remote,
           ws_endpoint: "ws://localhost:3337/"
         )
  """

  alias Playwriter.Browser.Session

  @type context :: %{session: pid(), page: String.t()}
  @type result :: {:ok, term()} | {:error, term()}

  @doc """
  Execute a function with a browser session.

  The function receives a context map with `:session` and `:page` keys.
  Session and page are automatically created and cleaned up.

  ## Options

  - `:mode` - `:local`, `:remote`, or `:auto` (default: `:auto`)
  - `:ws_endpoint` - WebSocket URL for remote mode
  - `:headless` - Run browser in headless mode (default: true)
  - `:browser_type` - `:chromium`, `:firefox`, or `:webkit` (default: `:chromium`)

  ## Examples

      {:ok, html} = Playwriter.with_browser(headless: true, fn ctx ->
        Playwriter.goto(ctx, "https://example.com")
        Playwriter.content(ctx)
      end)

      # With visible Windows browser
      {:ok, html} = Playwriter.with_browser(mode: :remote, fn ctx ->
        Playwriter.goto(ctx, "https://example.com")
        Playwriter.click(ctx, "#accept-cookies")
        Playwriter.content(ctx)
      end)
  """
  @spec with_browser(keyword(), (context() -> term())) :: result()
  def with_browser(opts \\ [], fun) do
    with {:ok, session} <- Session.start_link(opts),
         {:ok, page} <- Session.new_page(session) do
      try do
        context = %{session: session, page: page}
        result = fun.(context)
        {:ok, result}
      rescue
        error ->
          {:error, error}
      after
        Session.close(session)
      end
    end
  end

  @doc """
  Fetch HTML content from a URL.

  This is a convenience wrapper around `with_browser/2`.

  ## Options

  All options from `with_browser/2` plus:

  - `:timeout` - Navigation timeout in ms (default: 30000)
  - `:wait_until` - When to consider navigation complete

  ## Examples

      {:ok, html} = Playwriter.fetch_html("https://example.com")

      {:ok, html} = Playwriter.fetch_html("https://example.com",
        mode: :remote,
        ws_endpoint: "ws://localhost:3337/"
      )
  """
  @spec fetch_html(String.t(), keyword()) :: {:ok, String.t()} | {:error, term()}
  def fetch_html(url, opts \\ []) do
    with_browser(opts, fn ctx ->
      with :ok <- goto(ctx, url, opts),
           {:ok, html} <- content(ctx) do
        html
      else
        error -> throw(error)
      end
    end)
  catch
    {:error, _} = error -> error
  end

  @doc """
  Take a screenshot of a URL.

  Returns the screenshot as PNG binary data.

  ## Options

  All options from `with_browser/2` plus:

  - `:full_page` - Capture entire scrollable page (default: false)
  - `:omit_background` - Transparent background (default: false)

  ## Examples

      {:ok, png} = Playwriter.screenshot("https://example.com")
      File.write!("screenshot.png", png)

      {:ok, png} = Playwriter.screenshot("https://example.com", full_page: true)
  """
  @spec screenshot(String.t(), keyword()) :: {:ok, binary()} | {:error, term()}
  def screenshot(url, opts \\ []) do
    with_browser(opts, fn ctx ->
      with :ok <- goto(ctx, url, opts),
           {:ok, data} <- Session.screenshot(ctx.session, ctx.page, opts) do
        data
      else
        error -> throw(error)
      end
    end)
  catch
    {:error, _} = error -> error
  end

  # Context-based operations (used inside with_browser callback)

  @doc """
  Navigate to a URL.

  Use inside `with_browser/2` callback.

  ## Examples

      Playwriter.with_browser(fn ctx ->
        :ok = Playwriter.goto(ctx, "https://example.com")
        # ...
      end)
  """
  @spec goto(context(), String.t(), keyword()) :: :ok | {:error, term()}
  def goto(ctx, url, opts \\ []) do
    Session.goto(ctx.session, ctx.page, url, opts)
  end

  @doc """
  Get page HTML content.

  Use inside `with_browser/2` callback.
  """
  @spec content(context()) :: {:ok, String.t()} | {:error, term()}
  def content(ctx) do
    Session.content(ctx.session, ctx.page)
  end

  @doc """
  Click an element.

  Use inside `with_browser/2` callback.

  ## Examples

      Playwriter.with_browser(fn ctx ->
        Playwriter.goto(ctx, "https://example.com")
        :ok = Playwriter.click(ctx, "button.submit")
      end)
  """
  @spec click(context(), String.t(), keyword()) :: :ok | {:error, term()}
  def click(ctx, selector, opts \\ []) do
    Session.click(ctx.session, ctx.page, selector, opts)
  end

  @doc """
  Fill an input field.

  Use inside `with_browser/2` callback.

  ## Examples

      Playwriter.with_browser(fn ctx ->
        Playwriter.goto(ctx, "https://example.com/login")
        :ok = Playwriter.fill(ctx, "input[name=email]", "test@example.com")
        :ok = Playwriter.fill(ctx, "input[name=password]", "secret123")
        :ok = Playwriter.click(ctx, "button[type=submit]")
      end)
  """
  @spec fill(context(), String.t(), String.t(), keyword()) :: :ok | {:error, term()}
  def fill(ctx, selector, value, opts \\ []) do
    Session.fill(ctx.session, ctx.page, selector, value, opts)
  end

  @doc """
  Returns the library version.
  """
  @spec version() :: String.t()
  def version, do: "0.1.0"
end
