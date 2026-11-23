# Example Support Module
#
# Shared utilities for Playwriter examples.
# This file is loaded by examples that need mode detection and error handling.

defmodule Playwriter.Examples.Support do
  @moduledoc false

  @doc """
  Parse command line args and determine mode.
  Returns {:local, opts} or {:windows, opts} or {:remote, opts} or {:auto, opts}
  """
  def parse_args(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          remote: :boolean,
          local: :boolean,
          windows: :boolean,
          headless: :boolean,
          endpoint: :string
        ],
        aliases: [r: :remote, l: :local, w: :windows, h: :headless, e: :endpoint]
      )

    mode =
      cond do
        opts[:windows] -> :windows
        opts[:remote] -> :remote
        opts[:local] -> :local
        true -> :auto
      end

    {mode, opts}
  end

  @doc """
  Detect which mode to use based on what's available.
  Returns {:ok, mode, opts} or {:error, reason, detail}
  """
  def detect_mode(requested_mode, opts) do
    case requested_mode do
      :local ->
        case check_local_available() do
          :ok -> {:ok, :local, build_opts(:local, opts)}
          {:error, reason} -> {:error, :local_unavailable, reason}
        end

      :windows ->
        case check_windows_available() do
          :ok -> {:ok, :windows, build_opts(:windows, opts)}
          {:error, reason} -> {:error, :windows_unavailable, reason}
        end

      :remote ->
        {:error, :remote_unavailable, :not_supported}

      :auto ->
        # Try windows first (best for WSL), then local
        case check_windows_available() do
          :ok ->
            {:ok, :windows, build_opts(:windows, opts)}

          {:error, _} ->
            case check_local_available() do
              :ok -> {:ok, :local, build_opts(:local, opts)}
              {:error, _} -> {:error, :no_mode_available, nil}
            end
        end
    end
  end

  defp check_local_available do
    cli =
      System.get_env("PLAYWRIGHT_CLI") ||
        Application.get_env(:playwriter, :playwright_cli) ||
        Playwriter.Setup.local_cli()

    if File.regular?(cli), do: :ok, else: {:error, :playwright_not_installed}
  end

  defp check_windows_available do
    with {:ok, channel} <- Playwriter.Setup.windows_channel(),
         {:ok, dir, mount} <- Playwriter.Setup.windows_tools(),
         :ok <- Playwriter.Setup.check_installed_channel(channel) do
      Playwriter.Setup.check_windows_driver(dir, mount, channel)
    end
  end

  defp build_opts(:local, opts) do
    [
      mode: :local,
      headless: Keyword.get(opts, :headless, true)
    ]
  end

  defp build_opts(:windows, opts) do
    [mode: :windows, headless: Keyword.get(opts, :headless, false)]
  end

  @doc """
  Print mode banner showing what mode we're using.
  """
  def print_banner(mode, opts) do
    IO.puts("=" |> String.duplicate(60))

    case mode do
      :local ->
        IO.puts("Mode: LOCAL (headless browser on this machine)")
        IO.puts("Switch to windows: mix run <example> --windows")

      :windows ->
        IO.puts("Mode: WINDOWS (visible browser on Windows desktop)")
        IO.puts("Switch to local: mix run <example> --local")

      :remote ->
        endpoint = opts[:ws_endpoint]
        headless = if opts[:headless], do: "headless", else: "visible"
        IO.puts("Mode: REMOTE (#{headless} browser via WebSocket)")
        IO.puts("Endpoint: #{endpoint}")
        IO.puts("Switch to local: mix run <example> --local")
    end

    IO.puts("=" |> String.duplicate(60))
    IO.puts("")
  end

  @doc """
  Print helpful error message based on what failed.
  """
  def print_error(:local_unavailable, _reason) do
    IO.puts("")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("ERROR: Local Playwright not installed")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("")
    IO.puts("To use local mode, run:")
    IO.puts("")
    IO.puts("    mix playwriter.setup")
    IO.puts("")
    IO.puts("Or use Windows mode (WSL to Windows):")
    IO.puts("")
    IO.puts("  1. Install Playwright on Windows:")

    IO.puts("     mix playwriter.setup --mode windows")

    IO.puts("")
    IO.puts("  2. Run with --windows flag:")
    IO.puts("     mix run <example> --windows")
    IO.puts("")
  end

  def print_error(:windows_unavailable, reason) do
    IO.puts("")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("ERROR: Windows mode not available")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("")

    case reason do
      :not_wsl ->
        IO.puts("Windows mode requires running from WSL.")
        IO.puts("")
        IO.puts("Use local mode instead:")
        IO.puts("")
        IO.puts("    mix run <example> --local")

      :playwright_not_installed_on_windows ->
        IO.puts("Playwright is not installed on Windows.")
        IO.puts("")
        IO.puts("Run the setup script:")
        IO.puts("")

        IO.puts("    mix playwriter.setup --mode windows")

        IO.puts("")
        IO.puts("Then try again.")
    end

    IO.puts("")
  end

  def print_error(:remote_unavailable, :not_supported) do
    IO.puts("Remote WebSocket mode is unsupported. Use --windows from WSL.")
  end

  def print_error(:no_mode_available, _reason) do
    IO.puts("")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("ERROR: No browser automation available")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("")
    IO.puts("Neither local nor Windows mode is available.")
    IO.puts("")
    IO.puts("OPTION 1: Use Windows mode (WSL to Windows)")
    IO.puts("")
    IO.puts("  1. Install Playwright on Windows:")

    IO.puts("     mix playwriter.setup --mode windows")

    IO.puts("")
    IO.puts("  2. Run example:")
    IO.puts("     mix run <example> --windows")
    IO.puts("")
    IO.puts("OPTION 2: Use local mode")
    IO.puts("")
    IO.puts("  1. Install Playwright:")
    IO.puts("     mix playwriter.setup")
    IO.puts("")
    IO.puts("  2. Run example:")
    IO.puts("     mix run <example> --local")
    IO.puts("")
  end

  @doc """
  Print runtime error with context.
  """
  def print_runtime_error(error, mode) do
    IO.puts("")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("ERROR: Operation failed")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("")
    IO.puts("Error: #{inspect(error)}")
    IO.puts("")

    case mode do
      :local ->
        IO.puts("This may indicate:")
        IO.puts("  - Browser crashed or timed out")
        IO.puts("  - Missing system dependencies")
        IO.puts("")
        IO.puts("Try: npx playwright install-deps chromium")
        IO.puts("Or try Windows mode: mix run <example> --windows")

      :windows ->
        IO.puts("This may indicate:")
        IO.puts("  - PowerShell failed to start")
        IO.puts("  - Playwright not installed on Windows")
        IO.puts("")
        IO.puts("Run the setup script:")

        IO.puts("  mix playwriter.setup --mode windows")

      :remote ->
        IO.puts("This may indicate:")
        IO.puts("  - Windows server disconnected")
        IO.puts("  - Network timeout")
        IO.puts("")
        IO.puts("Use Windows mode instead: mix run <example> --windows")
    end

    IO.puts("")
  end
end
