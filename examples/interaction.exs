# Interaction Example
#
# Run: mix run examples/interaction.exs
#
# This example demonstrates form interaction using with_browser.

IO.puts("Demonstrating form interaction...")
IO.puts("")

result =
  Playwriter.with_browser([headless: true], fn ctx ->
    IO.puts("1. Navigating to httpbin.org form...")
    :ok = Playwriter.goto(ctx, "https://httpbin.org/forms/post")

    IO.puts("2. Filling form fields...")
    :ok = Playwriter.fill(ctx, "input[name=custname]", "Test User")
    :ok = Playwriter.fill(ctx, "input[name=custemail]", "test@example.com")
    :ok = Playwriter.fill(ctx, "input[name=custtel]", "555-1234")

    IO.puts("3. Getting page content before submit...")
    {:ok, _content} = Playwriter.content(ctx)

    IO.puts("4. Clicking submit button...")
    :ok = Playwriter.click(ctx, "button[type=submit]")

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
    IO.puts(String.slice(html, 0, 500))

  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
    System.halt(1)
end
