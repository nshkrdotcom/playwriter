# Screenshot Example
#
# Run: mix run examples/screenshot.exs
#
# This example takes a screenshot of example.com and saves it to a file.

IO.puts("Taking screenshot of example.com...")

case Playwriter.screenshot("https://example.com", headless: true, full_page: true) do
  {:ok, data} ->
    filename = "screenshot_#{:os.system_time(:second)}.png"
    File.write!(filename, data)
    IO.puts("Screenshot saved to: #{filename} (#{byte_size(data)} bytes)")

  {:error, reason} ->
    IO.puts("Error: #{inspect(reason)}")
    System.halt(1)
end
