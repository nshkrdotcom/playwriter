defmodule Playwriter.CapabilitiesIntegrationTest do
  @moduledoc """
  Real-browser tests for the harness capabilities (evaluate / wait_for_function /
  add_init_script / CDP / expose_binding) against a generic data: URL target.

  Tag-gated out of the default suite:

  - `:requires_browser` - the `:local` headless path. Run with:
        INTEGRATION=true mix test test/playwriter/capabilities_integration_test.exs
    (needs `mix playwriter.setup` first for the Node driver + Chromium).
  - `:requires_windows_server` - the `:windows` visible-desktop path. Run on a
    WSL+Windows box with `mix playwriter.setup` on the Windows side:
        WINDOWS_SERVER=true mix test test/playwriter/capabilities_integration_test.exs
  """
  use ExUnit.Case, async: false

  alias Playwriter.Browser.Session

  @page "data:text/html,<button id=x>hi</button><p id=t>ready</p>"

  # ------------------------------------------------------------------ :local

  describe "local (headless) capabilities" do
    @describetag :requires_browser

    setup do
      {:ok, session} = Session.start_link(mode: :local, headless: true)
      on_exit(fn -> if Process.alive?(session), do: Session.close(session) end)
      {:ok, page} = Session.new_page(session)
      :ok = Session.goto(session, page, @page)
      %{session: session, page: page}
    end

    test "evaluate returns a serialized value (proves the new-callback path)", %{
      session: s,
      page: p
    } do
      assert {:ok, 2} = Session.evaluate(s, p, "1 + 1")
      assert {:ok, "x"} = Session.evaluate(s, p, "document.getElementById('x').id")
      # a data: URL is not cross-origin isolated - the canonical harness probe
      assert {:ok, false} = Session.evaluate(s, p, "crossOriginIsolated")
    end

    test "evaluate passes an argument to a function body", %{session: s, page: p} do
      assert {:ok, 42} = Session.evaluate(s, p, "(n) => n * 2", arg: 21, is_function: true)
    end

    test "wait_for_function resolves when the predicate is truthy", %{session: s, page: p} do
      assert :ok =
               Session.wait_for_function(
                 s,
                 p,
                 "document.getElementById('t').textContent === 'ready'"
               )
    end

    test "wait_for_function times out on a never-true predicate", %{session: s, page: p} do
      assert {:error, _} = Session.wait_for_function(s, p, "false", timeout: 300)
    end

    test "add_init_script runs before page scripts (context-scoped)", %{session: s} do
      {:ok, ctx} = Session.new_context(s, [])
      :ok = Session.add_init_script(s, ctx, "window.__injected = 42;")
      {:ok, page} = Session.new_page(s, context_guid: ctx)
      :ok = Session.goto(s, page, @page)
      assert {:ok, 42} = Session.evaluate(s, page, "window.__injected")
    end

    test "CDP is not supported on the local transport", %{session: s, page: p} do
      assert {:error, :not_supported} = Session.new_cdp_session(s, p)
      assert {:error, :not_supported} = Session.cdp_send(s, "cdp-1", "Network.enable", %{})
    end

    test "expose_binding is not supported on the local transport", %{session: s} do
      {:ok, ctx} = Session.new_context(s, [])
      assert {:error, :not_supported} = Session.expose_binding(s, ctx, "cb", fn _ -> :ok end)
    end
  end

  # Separate block: no shared session (playwright_ex's connection is a global
  # singleton, so only one :local session may exist at a time).
  describe "local facade wrappers" do
    @describetag :requires_browser

    test "evaluate/wait_for_function wrappers work end to end" do
      result =
        Playwriter.with_browser([mode: :local, headless: true], fn ctx ->
          :ok = Playwriter.goto(ctx, @page)
          :ok = Playwriter.wait_for_function(ctx, "document.readyState === 'complete'")
          {:ok, id} = Playwriter.evaluate(ctx, "document.getElementById('x').id")
          id
        end)

      assert {:ok, "x"} = result
    end
  end

  # ---------------------------------------------------------------- :windows

  describe "windows (visible desktop) capabilities" do
    @describetag :requires_windows_server

    setup do
      {:ok, session} = Session.start_link(mode: :windows, headless: false)
      on_exit(fn -> if Process.alive?(session), do: Session.close(session) end)
      {:ok, page} = Session.new_page(session)
      :ok = Session.goto(session, page, @page)
      %{session: session, page: page}
    end

    test "evaluate returns a serialized value", %{session: s, page: p} do
      assert {:ok, 2} = Session.evaluate(s, p, "1 + 1")
      assert {:ok, "x"} = Session.evaluate(s, p, "document.getElementById('x').id")
    end

    test "wait_for_function resolves when truthy", %{session: s, page: p} do
      assert :ok =
               Session.wait_for_function(
                 s,
                 p,
                 "document.getElementById('t').textContent === 'ready'"
               )
    end

    test "add_init_script runs before page scripts", %{session: s} do
      {:ok, ctx} = Session.new_context(s, [])
      :ok = Session.add_init_script(s, ctx, "window.__injected = 7;")
      {:ok, page} = Session.new_page(s, context_guid: ctx)
      :ok = Session.goto(s, page, @page)
      assert {:ok, 7} = Session.evaluate(s, page, "window.__injected")
    end

    test "screenshot returns decoded PNG binary via the value_b64 contract", %{
      session: s,
      page: p
    } do
      assert {:ok, <<0x89, 0x50, 0x4E, 0x47, _::binary>>} = Session.screenshot(s, p, [])
    end

    test "CDP session throttles the network", %{session: s, page: p} do
      assert {:ok, cdp} = Session.new_cdp_session(s, p)

      assert {:ok, _} =
               Session.cdp_send(s, cdp, "Network.emulateNetworkConditions", %{
                 offline: false,
                 latency: 100,
                 downloadThroughput: 100_000,
                 uploadThroughput: 100_000
               })
    end

    test "expose_binding lets the page call back into Elixir (experimental)", %{session: s} do
      test_pid = self()
      {:ok, ctx} = Session.new_context(s, [])

      :ok =
        Session.expose_binding(s, ctx, "report", fn args ->
          send(test_pid, {:binding_called, args})
          "ack"
        end)

      {:ok, page} = Session.new_page(s, context_guid: ctx)
      :ok = Session.goto(s, page, @page)

      assert {:ok, "ack"} =
               Session.evaluate(s, page, "window.report('hello')", is_function: false)

      assert_receive {:binding_called, ["hello"]}, 5_000
    end
  end
end
