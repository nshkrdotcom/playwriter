defmodule Playwriter.Transport.Remote do
  @moduledoc """
  Remote transport for connecting to a Playwright server via WebSocket.

  **Note:** This transport is not functional due to WSL2 Hyper-V firewall blocking
  WebSocket connections. Use `mode: :windows` instead for WSL-to-Windows browser automation.

  The `:windows` mode runs Playwright directly on Windows via PowerShell stdin/stdout,
  completely bypassing network issues.
  """

  @behaviour Playwriter.Transport.Behaviour

  require Logger

  # Client API - All return errors directing users to :windows mode

  @impl Playwriter.Transport.Behaviour
  def start_link(opts \\ []) do
    endpoint = opts[:ws_endpoint] || "not specified"

    Logger.error("""
    Remote transport is not available.

    WSL2's Hyper-V firewall blocks WebSocket connections to Windows.
    Use `mode: :windows` instead:

        Playwriter.fetch_html("https://example.com", mode: :windows)

    The :windows mode runs Playwright directly on Windows via PowerShell,
    bypassing all network issues.

    Attempted endpoint: #{endpoint}
    """)

    {:error,
     {:not_supported,
      "Use mode: :windows instead of mode: :remote for WSL-to-Windows browser automation"}}
  end

  @impl Playwriter.Transport.Behaviour
  def send_message(_transport, _message, _timeout \\ 30_000) do
    {:error, :not_supported}
  end

  @impl Playwriter.Transport.Behaviour
  def launch_browser(_transport, _browser_type, _opts \\ []) do
    {:error, :not_supported}
  end

  @impl Playwriter.Transport.Behaviour
  def new_context(_transport, _browser_guid, _opts \\ []) do
    {:error, :not_supported}
  end

  @impl Playwriter.Transport.Behaviour
  def new_page(_transport, _context_guid) do
    {:error, :not_supported}
  end

  @impl Playwriter.Transport.Behaviour
  def goto(_transport, _frame_guid, _url, _opts \\ []) do
    {:error, :not_supported}
  end

  @impl Playwriter.Transport.Behaviour
  def content(_transport, _frame_guid) do
    {:error, :not_supported}
  end

  @impl Playwriter.Transport.Behaviour
  def screenshot(_transport, _page_guid, _opts \\ []) do
    {:error, :not_supported}
  end

  @impl Playwriter.Transport.Behaviour
  def click(_transport, _frame_guid, _selector, _opts \\ []) do
    {:error, :not_supported}
  end

  @impl Playwriter.Transport.Behaviour
  def fill(_transport, _frame_guid, _selector, _value, _opts \\ []) do
    {:error, :not_supported}
  end

  @impl Playwriter.Transport.Behaviour
  def close_page(_transport, _page_guid) do
    {:error, :not_supported}
  end

  @impl Playwriter.Transport.Behaviour
  def close_context(_transport, _context_guid) do
    {:error, :not_supported}
  end

  @impl Playwriter.Transport.Behaviour
  def close_browser(_transport, _browser_guid) do
    {:error, :not_supported}
  end

  @impl Playwriter.Transport.Behaviour
  def healthy?(_transport) do
    false
  end

  @impl Playwriter.Transport.Behaviour
  def stop(_transport) do
    :ok
  end
end
