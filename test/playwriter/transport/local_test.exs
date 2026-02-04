defmodule Playwriter.Transport.LocalTest do
  use ExUnit.Case, async: true

  alias Playwriter.Transport.Local

  describe "start_link/1" do
    @tag :requires_browser
    test "starts playwright_ex supervisor" do
      assert {:ok, pid} = Local.start_link([])
      assert Process.alive?(pid)
      assert Local.healthy?(pid)
      :ok = Local.stop(pid)
    end
  end

  describe "launch_browser/3" do
    @tag :requires_browser
    test "launches chromium headless" do
      {:ok, transport} = Local.start_link([])

      assert {:ok, browser_guid} = Local.launch_browser(transport, :chromium, headless: true)
      assert is_binary(browser_guid)

      :ok = Local.close_browser(transport, browser_guid)
      :ok = Local.stop(transport)
    end
  end

  describe "new_context/3" do
    @tag :requires_browser
    test "creates browser context" do
      {:ok, transport} = Local.start_link([])
      {:ok, browser_guid} = Local.launch_browser(transport, :chromium, headless: true)

      assert {:ok, context_guid} = Local.new_context(transport, browser_guid, [])
      assert is_binary(context_guid)

      :ok = Local.close_context(transport, context_guid)
      :ok = Local.close_browser(transport, browser_guid)
      :ok = Local.stop(transport)
    end
  end

  describe "new_page/2" do
    @tag :requires_browser
    test "creates page in context" do
      {:ok, transport} = Local.start_link([])
      {:ok, browser_guid} = Local.launch_browser(transport, :chromium, headless: true)
      {:ok, context_guid} = Local.new_context(transport, browser_guid, [])

      assert {:ok, %{guid: page_guid, main_frame: %{guid: _frame_guid}}} =
               Local.new_page(transport, context_guid)

      assert is_binary(page_guid)

      :ok = Local.close_page(transport, page_guid)
      :ok = Local.close_context(transport, context_guid)
      :ok = Local.close_browser(transport, browser_guid)
      :ok = Local.stop(transport)
    end
  end

  describe "goto/4" do
    @tag :requires_browser
    test "navigates to URL" do
      {:ok, transport} = Local.start_link([])
      {:ok, browser_guid} = Local.launch_browser(transport, :chromium, headless: true)
      {:ok, context_guid} = Local.new_context(transport, browser_guid, [])

      {:ok, %{guid: page_guid, main_frame: %{guid: frame_guid}}} =
        Local.new_page(transport, context_guid)

      assert {:ok, _response} = Local.goto(transport, frame_guid, "https://example.com", [])

      :ok = Local.close_page(transport, page_guid)
      :ok = Local.close_context(transport, context_guid)
      :ok = Local.close_browser(transport, browser_guid)
      :ok = Local.stop(transport)
    end
  end

  describe "content/2" do
    @tag :requires_browser
    test "gets page HTML content" do
      {:ok, transport} = Local.start_link([])
      {:ok, browser_guid} = Local.launch_browser(transport, :chromium, headless: true)
      {:ok, context_guid} = Local.new_context(transport, browser_guid, [])

      {:ok, %{guid: page_guid, main_frame: %{guid: frame_guid}}} =
        Local.new_page(transport, context_guid)

      {:ok, _} = Local.goto(transport, frame_guid, "https://example.com", [])

      assert {:ok, html} = Local.content(transport, frame_guid)
      assert String.contains?(html, "Example Domain")

      :ok = Local.close_page(transport, page_guid)
      :ok = Local.close_context(transport, context_guid)
      :ok = Local.close_browser(transport, browser_guid)
      :ok = Local.stop(transport)
    end
  end

  describe "screenshot/3" do
    @tag :requires_browser
    test "takes screenshot" do
      {:ok, transport} = Local.start_link([])
      {:ok, browser_guid} = Local.launch_browser(transport, :chromium, headless: true)
      {:ok, context_guid} = Local.new_context(transport, browser_guid, [])

      {:ok, %{guid: page_guid, main_frame: %{guid: frame_guid}}} =
        Local.new_page(transport, context_guid)

      {:ok, _} = Local.goto(transport, frame_guid, "https://example.com", [])

      assert {:ok, data} = Local.screenshot(transport, page_guid, [])
      # PNG magic bytes
      assert <<0x89, 0x50, 0x4E, 0x47, _::binary>> = data

      :ok = Local.close_page(transport, page_guid)
      :ok = Local.close_context(transport, context_guid)
      :ok = Local.close_browser(transport, browser_guid)
      :ok = Local.stop(transport)
    end
  end

  describe "healthy?/1" do
    @tag :requires_browser
    test "returns true for running transport" do
      {:ok, transport} = Local.start_link([])
      assert Local.healthy?(transport)
      :ok = Local.stop(transport)
    end
  end
end
