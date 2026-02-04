# Example Support Module
#
# Shared utilities for Playwriter examples.
# This file is loaded by examples that need mode detection and error handling.

defmodule Playwriter.Examples.Support do
  @moduledoc false

  @doc """
  Parse command line args and determine mode.
  Returns {:local, opts} or {:remote, opts} or {:auto, opts}
  """
  def parse_args(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        switches: [
          remote: :boolean,
          local: :boolean,
          headless: :boolean,
          endpoint: :string
        ],
        aliases: [r: :remote, l: :local, h: :headless, e: :endpoint]
      )

    mode =
      cond do
        opts[:remote] -> :remote
        opts[:local] -> :local
        true -> :auto
      end

    {mode, opts}
  end

  @doc """
  Detect which mode to use based on what's available.
  Returns {:ok, :local | :remote, opts} or {:error, :no_mode_available}
  """
  def detect_mode(requested_mode, opts) do
    case requested_mode do
      :local ->
        case check_local_available() do
          :ok -> {:ok, :local, build_opts(:local, opts)}
          {:error, reason} -> {:error, :local_unavailable, reason}
        end

      :remote ->
        case check_remote_available(opts[:endpoint]) do
          {:ok, endpoint} -> {:ok, :remote, build_opts(:remote, opts, endpoint)}
          {:error, reason} -> {:error, :remote_unavailable, reason}
        end

      :auto ->
        # Try remote first (primary use case for WSL), then local
        case check_remote_available(opts[:endpoint]) do
          {:ok, endpoint} ->
            {:ok, :remote, build_opts(:remote, opts, endpoint)}

          {:error, _} ->
            case check_local_available() do
              :ok -> {:ok, :local, build_opts(:local, opts)}
              {:error, _} -> {:error, :no_mode_available, nil}
            end
        end
    end
  end

  defp check_local_available do
    # Check if playwright_ex has its dependencies installed
    # playwright_ex needs node_modules/playwright/cli.js to work
    playwright_cli_paths = [
      Path.join(["deps", "playwright_ex", "node_modules", "playwright", "cli.js"]),
      Path.join(["deps", "playwright_ex", "node_modules", ".bin", "playwright"])
    ]

    if Enum.any?(playwright_cli_paths, &File.exists?/1) do
      :ok
    else
      {:error, :playwright_not_installed}
    end
  end

  defp check_remote_available(explicit_endpoint) do
    if explicit_endpoint do
      {:ok, explicit_endpoint}
    else
      case Playwriter.Server.Discovery.discover(timeout: 2000) do
        {:ok, endpoint} -> {:ok, endpoint}
        {:error, _} -> {:error, :server_not_found}
      end
    end
  end

  defp build_opts(:local, opts) do
    [
      mode: :local,
      headless: Keyword.get(opts, :headless, true)
    ]
  end

  defp build_opts(:remote, opts, endpoint) do
    [
      mode: :remote,
      ws_endpoint: endpoint,
      headless: Keyword.get(opts, :headless, false)
    ]
  end

  @doc """
  Print mode banner showing what mode we're using.
  """
  def print_banner(mode, opts) do
    IO.puts("=" |> String.duplicate(60))

    case mode do
      :local ->
        IO.puts("Mode: LOCAL (headless browser on this machine)")
        IO.puts("Switch to remote: mix run <example> --remote")

      :remote ->
        endpoint = opts[:ws_endpoint]
        headless = if opts[:headless], do: "headless", else: "visible"
        IO.puts("Mode: REMOTE (#{headless} browser on Windows)")
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
    IO.puts("Or use remote mode (WSL to Windows):")
    IO.puts("")
    IO.puts("  1. Start Windows server:")
    IO.puts("     powershell.exe -File priv/scripts/start_server.ps1")
    IO.puts("")
    IO.puts("  2. Run with --remote flag:")
    IO.puts("     mix run <example> --remote")
    IO.puts("")
  end

  def print_error(:remote_unavailable, _reason) do
    IO.puts("")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("ERROR: No Playwright server found")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("")
    IO.puts("To use remote mode, start the Windows server:")
    IO.puts("")
    IO.puts("    powershell.exe -File priv/scripts/start_server.ps1")
    IO.puts("")
    IO.puts("Or specify endpoint directly:")
    IO.puts("")
    IO.puts("    mix run <example> --remote --endpoint ws://localhost:3337/")
    IO.puts("")
    IO.puts("Or use local mode instead:")
    IO.puts("")
    IO.puts("  1. Install Playwright locally:")
    IO.puts("     mix playwriter.setup")
    IO.puts("")
    IO.puts("  2. Run with --local flag:")
    IO.puts("     mix run <example> --local")
    IO.puts("")
  end

  def print_error(:no_mode_available, _reason) do
    IO.puts("")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("ERROR: No browser automation available")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("")
    IO.puts("Neither local nor remote mode is available.")
    IO.puts("")
    IO.puts("OPTION 1: Use remote mode (WSL to Windows)")
    IO.puts("")
    IO.puts("  1. Start Windows server:")
    IO.puts("     powershell.exe -File priv/scripts/start_server.ps1")
    IO.puts("")
    IO.puts("  2. Run example:")
    IO.puts("     mix run <example> --remote")
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
        IO.puts("Or try remote mode: mix run <example> --remote")

      :remote ->
        IO.puts("This may indicate:")
        IO.puts("  - Windows server disconnected")
        IO.puts("  - Network timeout")
        IO.puts("")
        IO.puts("Check that the server is still running on Windows.")
    end

    IO.puts("")
  end
end
