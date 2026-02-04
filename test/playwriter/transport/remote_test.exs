defmodule Playwriter.Transport.RemoteTest do
  use ExUnit.Case, async: true

  alias Playwriter.Transport.Remote

  describe "start_link/1" do
    test "requires ws_endpoint option" do
      assert {:error, {:missing_option, :ws_endpoint}} = Remote.start_link([])
    end

    test "validates ws_endpoint format" do
      assert {:error, {:invalid_endpoint, _}} = Remote.start_link(ws_endpoint: "not-a-url")
    end

    test "fails with connection error for invalid port" do
      # Use localhost with a port that's unlikely to have anything running
      # The connection failure causes a linked process exit, so we trap exits
      Process.flag(:trap_exit, true)

      result = Remote.start_link(ws_endpoint: "ws://127.0.0.1:59999/", timeout: 100)

      case result do
        {:error, _} ->
          # Direct error return
          assert true

        {:ok, pid} ->
          # Process started but will die - wait for EXIT message
          receive do
            {:EXIT, ^pid, reason} ->
              assert reason != :normal
          after
            200 -> flunk("Expected process to exit")
          end
      end
    end

    @tag :requires_windows_server
    test "connects to Windows Playwright server" do
      {:ok, transport} = Remote.start_link(ws_endpoint: "ws://localhost:3337/")

      assert Process.alive?(transport)
      assert Remote.healthy?(transport)

      :ok = Remote.stop(transport)
    end
  end

  describe "healthy?/1" do
    @tag :requires_windows_server
    test "returns true for connected transport" do
      {:ok, transport} = Remote.start_link(ws_endpoint: "ws://localhost:3337/")
      assert Remote.healthy?(transport)
      :ok = Remote.stop(transport)
    end

    test "returns false for non-existent process" do
      refute Remote.healthy?(:non_existent_process)
    end
  end

  describe "launch_browser/3" do
    @tag :requires_windows_server
    test "gets browser from server" do
      {:ok, transport} = Remote.start_link(ws_endpoint: "ws://localhost:3337/")

      # Remote transport doesn't launch - it uses the server's browser
      # This should return the browser guid from the server
      assert {:ok, browser_guid} = Remote.get_browser(transport)
      assert is_binary(browser_guid)

      :ok = Remote.stop(transport)
    end
  end

  describe "new_context/3" do
    @tag :requires_windows_server
    test "creates browser context" do
      {:ok, transport} = Remote.start_link(ws_endpoint: "ws://localhost:3337/")
      {:ok, browser_guid} = Remote.get_browser(transport)

      assert {:ok, context_guid} = Remote.new_context(transport, browser_guid, [])
      assert is_binary(context_guid)

      :ok = Remote.close_context(transport, context_guid)
      :ok = Remote.stop(transport)
    end
  end

  describe "new_page/2" do
    @tag :requires_windows_server
    test "creates page in context" do
      {:ok, transport} = Remote.start_link(ws_endpoint: "ws://localhost:3337/")
      {:ok, browser_guid} = Remote.get_browser(transport)
      {:ok, context_guid} = Remote.new_context(transport, browser_guid, [])

      assert {:ok, %{guid: page_guid}} = Remote.new_page(transport, context_guid)
      assert is_binary(page_guid)

      :ok = Remote.close_page(transport, page_guid)
      :ok = Remote.close_context(transport, context_guid)
      :ok = Remote.stop(transport)
    end
  end

  describe "goto/4" do
    @tag :requires_windows_server
    test "navigates to URL" do
      {:ok, transport} = Remote.start_link(ws_endpoint: "ws://localhost:3337/")
      {:ok, browser_guid} = Remote.get_browser(transport)
      {:ok, context_guid} = Remote.new_context(transport, browser_guid, [])

      {:ok, %{guid: _page_guid, main_frame: %{guid: frame_guid}}} =
        Remote.new_page(transport, context_guid)

      assert {:ok, _response} = Remote.goto(transport, frame_guid, "https://example.com", [])

      :ok = Remote.close_context(transport, context_guid)
      :ok = Remote.stop(transport)
    end
  end

  describe "content/2" do
    @tag :requires_windows_server
    test "gets page HTML content" do
      {:ok, transport} = Remote.start_link(ws_endpoint: "ws://localhost:3337/")
      {:ok, browser_guid} = Remote.get_browser(transport)
      {:ok, context_guid} = Remote.new_context(transport, browser_guid, [])

      {:ok, %{guid: _page_guid, main_frame: %{guid: frame_guid}}} =
        Remote.new_page(transport, context_guid)

      {:ok, _} = Remote.goto(transport, frame_guid, "https://example.com", [])

      assert {:ok, html} = Remote.content(transport, frame_guid)
      assert String.contains?(html, "Example Domain")

      :ok = Remote.close_context(transport, context_guid)
      :ok = Remote.stop(transport)
    end
  end
end
