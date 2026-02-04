# Interaction Example
#
# Usage:
#   mix run examples/interaction.exs           # auto-detect mode
#   mix run examples/interaction.exs --local   # force local mode
#   mix run examples/interaction.exs --remote  # force remote mode (WSL to Windows)
#
# Options:
#   --local, -l      Use local Playwright (requires: mix playwriter.setup)
#   --remote, -r     Use remote Windows server (requires: powershell.exe -File priv/scripts/start_server.ps1)
#   --endpoint, -e   Specify WebSocket endpoint for remote mode
#   --headless, -h   Run headless (default: true for local, false for remote)
#
# This example demonstrates form interaction using with_browser.

Code.require_file("support.exs", __DIR__)
alias Playwriter.Examples.Support

# Parse args and detect mode
{requested_mode, opts} = Support.parse_args(System.argv())

case Support.detect_mode(requested_mode, opts) do
  {:ok, mode, playwriter_opts} ->
    Support.print_banner(mode, playwriter_opts)

    IO.puts("Demonstrating form interaction...")
    IO.puts("")

    result =
      Playwriter.with_browser(playwriter_opts, fn ctx ->
        IO.puts("1. Navigating to httpbin.org form...")
        :ok = Playwriter.goto(ctx, "https://httpbin.org/forms/post")

        IO.puts("2. Filling form fields...")
        :ok = Playwriter.fill(ctx, "input[name=custname]", "Test User")
        :ok = Playwriter.fill(ctx, "input[name=custemail]", "test@example.com")
        :ok = Playwriter.fill(ctx, "input[name=custtel]", "555-1234")

        IO.puts("3. Getting page content before submit...")
        {:ok, _content} = Playwriter.content(ctx)

        IO.puts("4. Clicking submit button...")
        :ok = Playwriter.click(ctx, "button")

        # Wait a moment for navigation
        Process.sleep(1000)

        IO.puts("5. Getting result page content...")
        {:ok, result_html} = Playwriter.content(ctx)

        result_html
      end)

    case result do
      {:ok, html} ->
        IO.puts("")
        IO.puts("Success! Form submitted.")
        IO.puts("Result page preview (first 500 chars):")
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
