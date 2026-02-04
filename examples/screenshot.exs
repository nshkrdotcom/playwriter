# Screenshot Example
#
# Usage:
#   mix run examples/screenshot.exs           # auto-detect mode
#   mix run examples/screenshot.exs --local   # force local mode
#   mix run examples/screenshot.exs --remote  # force remote mode (WSL to Windows)
#
# Options:
#   --local, -l      Use local Playwright (requires: mix playwriter.setup)
#   --remote, -r     Use remote Windows server (requires: powershell.exe -File priv/scripts/start_server.ps1)
#   --endpoint, -e   Specify WebSocket endpoint for remote mode
#   --headless, -h   Run headless (default: true for local, false for remote)
#
# Output: screenshot.png in current directory

Code.require_file("support.exs", __DIR__)
alias Playwriter.Examples.Support

# Parse args and detect mode
{requested_mode, opts} = Support.parse_args(System.argv())

case Support.detect_mode(requested_mode, opts) do
  {:ok, mode, playwriter_opts} ->
    Support.print_banner(mode, playwriter_opts)

    IO.puts("Taking screenshot of example.com...")
    IO.puts("")

    case Playwriter.screenshot("https://example.com", playwriter_opts) do
      {:ok, png_data} ->
        filename = "screenshot.png"
        File.write!(filename, png_data)
        IO.puts("Success! Screenshot saved to #{filename}")
        IO.puts("File size: #{byte_size(png_data)} bytes")

      {:error, reason} ->
        Support.print_runtime_error(reason, mode)
        System.halt(1)
    end

  {:error, error_type, reason} ->
    Support.print_error(error_type, reason)
    System.halt(1)
end
