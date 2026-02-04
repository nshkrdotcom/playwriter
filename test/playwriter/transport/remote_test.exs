defmodule Playwriter.Transport.RemoteTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Playwriter.Transport.Remote

  describe "start_link/1" do
    test "returns not_supported error (use :windows mode instead)" do
      # Remote transport is disabled due to WSL2 networking issues
      # Users should use mode: :windows instead
      {result, _log} =
        with_log(fn ->
          Remote.start_link([])
        end)

      assert {:error, {:not_supported, message}} = result
      assert message =~ "windows"
    end

    test "returns not_supported even with valid endpoint" do
      {result, _log} =
        with_log(fn ->
          Remote.start_link(ws_endpoint: "ws://localhost:3337/")
        end)

      assert {:error, {:not_supported, _}} = result
    end
  end

  describe "healthy?/1" do
    test "returns false (transport is disabled)" do
      refute Remote.healthy?(:any_value)
    end
  end

  describe "all operations" do
    test "return not_supported error" do
      assert {:error, :not_supported} = Remote.launch_browser(nil, :chromium)
      assert {:error, :not_supported} = Remote.new_context(nil, "browser")
      assert {:error, :not_supported} = Remote.new_page(nil, "context")
      assert {:error, :not_supported} = Remote.goto(nil, "frame", "https://example.com")
      assert {:error, :not_supported} = Remote.content(nil, "frame")
      assert {:error, :not_supported} = Remote.screenshot(nil, "page")
      assert {:error, :not_supported} = Remote.click(nil, "frame", "selector")
      assert {:error, :not_supported} = Remote.fill(nil, "frame", "selector", "value")
      assert {:error, :not_supported} = Remote.close_page(nil, "page")
      assert {:error, :not_supported} = Remote.close_context(nil, "context")
      assert {:error, :not_supported} = Remote.close_browser(nil, "browser")
    end
  end

  describe "stop/1" do
    test "returns ok (no-op)" do
      assert :ok = Remote.stop(nil)
    end
  end
end
