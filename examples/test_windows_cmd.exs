# Test the WindowsCmd transport
# This bypasses WSL2 networking by running Node.js directly on Windows via cmd.exe

Logger.configure(level: :info)

alias Playwriter.Transport.WindowsCmd

IO.puts("Starting WindowsCmd transport...")

case WindowsCmd.start_link([]) do
  {:ok, transport} ->
    IO.puts("Transport started!")

    # Launch browser
    IO.puts("Launching browser...")

    case WindowsCmd.launch_browser(transport, :chromium, headless: false) do
      {:ok, browser_id} ->
        IO.puts("Browser launched: #{inspect(browser_id)}")

        # Create context
        case WindowsCmd.new_context(transport, browser_id) do
          {:ok, context_id} ->
            IO.puts("Context created: #{inspect(context_id)}")

            # Create page
            case WindowsCmd.new_page(transport, context_id) do
              {:ok, %{guid: page_id, main_frame: %{guid: _frame_id}}} ->
                IO.puts("Page created: #{page_id}")

                # Navigate
                IO.puts("Navigating to example.com...")
                goto_result = WindowsCmd.goto(transport, page_id, "https://example.com")
                IO.puts("Goto result: #{inspect(goto_result)}")

                if goto_result in [:ok, {:ok, nil}, {:ok, %{"ok" => true}}] do
                  IO.puts("Navigation successful!")

                  # Wait so user can see the browser
                  IO.puts("Browser visible for 3 seconds...")
                  Process.sleep(3000)

                  # Get content
                  case WindowsCmd.content(transport, page_id) do
                    {:ok, html} ->
                      IO.puts("Got HTML content (#{byte_size(html)} bytes)")
                      IO.puts("Title area: #{String.slice(html, 0, 300)}...")

                    error ->
                      IO.puts("Content error: #{inspect(error)}")
                  end

                  # Take screenshot
                  case WindowsCmd.screenshot(transport, page_id) do
                    {:ok, binary} when is_binary(binary) ->
                      File.write!("windows_cmd_screenshot.png", binary)

                      IO.puts(
                        "Screenshot saved to windows_cmd_screenshot.png (#{byte_size(binary)} bytes)"
                      )

                    error ->
                      IO.puts("Screenshot error: #{inspect(error)}")
                  end
                end

                # Cleanup
                IO.puts("Cleaning up...")
                WindowsCmd.close_page(transport, page_id)
                WindowsCmd.close_context(transport, context_id)

              error ->
                IO.puts("New page error: #{inspect(error)}")
            end

          error ->
            IO.puts("New context error: #{inspect(error)}")
        end

        WindowsCmd.close_browser(transport, browser_id)

      error ->
        IO.puts("Launch error: #{inspect(error)}")
    end

    WindowsCmd.stop(transport)
    IO.puts("Test complete!")

  {:error, reason} ->
    IO.puts("Failed to start transport: #{inspect(reason)}")
end
