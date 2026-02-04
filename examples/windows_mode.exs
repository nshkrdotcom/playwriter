# Test Windows mode - visible browser on Windows from WSL
# This bypasses all WSL2 networking issues!

IO.puts("Testing Playwriter with mode: :windows")
IO.puts("This will open a visible browser on Windows...")
IO.puts("")

# Simple fetch_html
IO.puts("1. Fetching HTML from example.com...")

case Playwriter.fetch_html("https://example.com", mode: :windows) do
  {:ok, html} ->
    IO.puts("   Got #{byte_size(html)} bytes of HTML")
    IO.puts("   Title: #{Regex.run(~r/<title>([^<]+)<\/title>/, html) |> List.last()}")

  {:error, reason} ->
    IO.puts("   Error: #{inspect(reason)}")
end

IO.puts("")

# Screenshot
IO.puts("2. Taking screenshot of example.com...")

case Playwriter.screenshot("https://example.com", mode: :windows) do
  {:ok, png} ->
    File.write!("windows_screenshot.png", png)
    IO.puts("   Saved windows_screenshot.png (#{byte_size(png)} bytes)")

  {:error, reason} ->
    IO.puts("   Error: #{inspect(reason)}")
end

IO.puts("")

# Full with_browser workflow
IO.puts("3. Testing with_browser for interaction...")

case Playwriter.with_browser([mode: :windows], fn ctx ->
       IO.puts("   Navigating to httpbin.org/forms/post...")
       :ok = Playwriter.goto(ctx, "https://httpbin.org/forms/post")

       IO.puts("   Browser visible for 2 seconds...")
       Process.sleep(2000)

       IO.puts("   Filling form fields...")
       :ok = Playwriter.fill(ctx, "input[name=custname]", "Test User")
       :ok = Playwriter.fill(ctx, "input[name=custtel]", "555-1234")
       :ok = Playwriter.fill(ctx, "input[name=custemail]", "test@example.com")

       IO.puts("   Form filled! Visible for 2 more seconds...")
       Process.sleep(2000)

       {:ok, html} = Playwriter.content(ctx)
       html
     end) do
  {:ok, html} ->
    IO.puts("   Success! Got #{byte_size(html)} bytes")

  {:error, reason} ->
    IO.puts("   Error: #{inspect(reason)}")
end

IO.puts("")
IO.puts("Done!")
