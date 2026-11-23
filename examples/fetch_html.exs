# Fetch HTML Example
#
# Usage:
#   mix run examples/fetch_html.exs           # auto-detect mode
#   mix run examples/fetch_html.exs --local   # force local mode
#   mix run examples/fetch_html.exs --windows  # use Windows stdio from WSL
#
# Options:
#   --local, -l      Use local Playwright (requires: mix playwriter.setup)
#   --windows, -w    Use Windows stdio (requires: mix playwriter.setup --mode windows)
#   --headless, -h   Run headless (default: true for local, false for Windows)

Code.require_file("support.exs", __DIR__)
alias Playwriter.Examples.Support

# Parse args and detect mode
{requested_mode, opts} = Support.parse_args(System.argv())

case Support.detect_mode(requested_mode, opts) do
  {:ok, mode, playwriter_opts} ->
    Support.print_banner(mode, playwriter_opts)

    IO.puts("Fetching HTML from example.com...")
    IO.puts("")

    case Playwriter.fetch_html("https://example.com", playwriter_opts) do
      {:ok, html} ->
        IO.puts("Success! Fetched #{String.length(html)} bytes")
        IO.puts("")
        IO.puts("First 500 characters:")
        IO.puts("-" |> String.duplicate(40))
        IO.puts(String.slice(html, 0, 500))

      {:error, reason} ->
        Support.print_runtime_error(reason, mode)
        System.halt(1)
    end

  {:error, error_type, reason} ->
    Support.print_error(error_type, reason)
    System.halt(1)
end
