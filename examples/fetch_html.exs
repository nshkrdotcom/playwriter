# Fetch HTML Example
#
# Run: mix run examples/fetch_html.exs
#
# This example fetches HTML from example.com using a headless browser.

IO.puts("Fetching HTML from example.com...")

case Playwriter.fetch_html("https://example.com", headless: true) do
  {:ok, html} ->
    IO.puts("Success! Fetched #{String.length(html)} bytes")
    IO.puts("")
    IO.puts("First 500 characters:")
    IO.puts(String.slice(html, 0, 500))

  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
    System.halt(1)
end
