defmodule Playwriter.Browser.SessionDispatchTest do
  @moduledoc """
  Unit tests that a Session dispatches each new verb to the right transport
  callback with the right resolved guid, using the Mox behaviour mock injected
  via `transport_module:`. No real browser is involved.
  """
  use ExUnit.Case, async: false

  import Mox

  alias Playwriter.Browser.Session
  alias Playwriter.Transport.Mock

  # The Session runs in its own process, so expectations must be global.
  setup :set_mox_global
  setup :verify_on_exit!

  setup do
    stub(Mock, :start_link, fn _ -> {:ok, :mock_transport} end)
    stub(Mock, :launch_browser, fn _t, _type, _opts -> {:ok, "browser-1"} end)
    stub(Mock, :new_context, fn _t, _b, _opts -> {:ok, "ctx-1"} end)

    stub(Mock, :new_page, fn _t, _ctx ->
      {:ok, %{guid: "page-1", main_frame: %{guid: "frame-1"}}}
    end)

    stub(Mock, :close_page, fn _t, _g -> :ok end)
    stub(Mock, :close_context, fn _t, _g -> :ok end)
    stub(Mock, :stop, fn _t -> :ok end)

    {:ok, session} = Session.start_link(transport_module: Mock)
    on_exit(fn -> if Process.alive?(session), do: Session.close(session) end)
    {:ok, page} = Session.new_page(session)
    %{session: session, page: page}
  end

  test "evaluate/4 dispatches with the frame guid + expression + opts", %{session: s, page: p} do
    expect(Mock, :evaluate, fn :mock_transport, "frame-1", "crossOriginIsolated", opts ->
      assert opts[:is_function] == false
      {:ok, true}
    end)

    assert {:ok, true} = Session.evaluate(s, p, "crossOriginIsolated", is_function: false)
  end

  test "evaluate/4 passes arg + is_function through", %{session: s, page: p} do
    expect(Mock, :evaluate, fn :mock_transport, "frame-1", "(a) => a + 1", opts ->
      assert opts[:arg] == 2
      assert opts[:is_function] == true
      {:ok, 3}
    end)

    assert {:ok, 3} = Session.evaluate(s, p, "(a) => a + 1", arg: 2, is_function: true)
  end

  test "wait_for_function/4 dispatches with the frame guid and returns :ok", %{
    session: s,
    page: p
  } do
    expect(Mock, :wait_for_function, fn :mock_transport, "frame-1", "window.__ready", _opts ->
      {:ok, %{}}
    end)

    assert :ok = Session.wait_for_function(s, p, "window.__ready")
  end

  test "wait_for_function/4 surfaces a timeout error", %{session: s, page: p} do
    expect(Mock, :wait_for_function, fn _t, "frame-1", _expr, _opts -> {:error, :timeout} end)
    assert {:error, :timeout} = Session.wait_for_function(s, p, "false", timeout: 10)
  end

  test "add_init_script/4 dispatches against the raw context guid", %{session: s} do
    expect(Mock, :add_init_script, fn :mock_transport, "ctx-9", "window.__debug=1", _opts ->
      :ok
    end)

    assert :ok = Session.add_init_script(s, "ctx-9", "window.__debug=1")
  end

  test "add_cookies/3 dispatches against the raw context guid with the cookie list", %{session: s} do
    cookies = [%{name: "_listener_web_key", value: "signed", domain: "localhost", path: "/"}]
    expect(Mock, :add_cookies, fn :mock_transport, "ctx-9", ^cookies -> :ok end)
    assert :ok = Session.add_cookies(s, "ctx-9", cookies)
  end

  test "storage_state/2 dispatches against the raw context guid", %{session: s} do
    expect(Mock, :storage_state, fn :mock_transport, "ctx-9" ->
      {:ok, %{"cookies" => [], "origins" => []}}
    end)

    assert {:ok, %{"cookies" => []}} = Session.storage_state(s, "ctx-9")
  end

  test "new_cdp_session/2 dispatches with the page guid", %{session: s, page: p} do
    expect(Mock, :new_cdp_session, fn :mock_transport, "page-1" -> {:ok, "cdp-1"} end)
    assert {:ok, "cdp-1"} = Session.new_cdp_session(s, p)
  end

  test "cdp_send/4 passes the cdp session id, method and params through", %{session: s} do
    expect(Mock, :cdp_send, fn :mock_transport, "cdp-1", "Network.setBlockedURLs", params ->
      assert params == %{urls: ["*://ads.example/*"]}
      {:ok, %{}}
    end)

    assert {:ok, %{}} =
             Session.cdp_send(s, "cdp-1", "Network.setBlockedURLs", %{urls: ["*://ads.example/*"]})
  end

  test "expose_binding/4 dispatches against the raw context guid with the callback", %{session: s} do
    cb = fn args -> {:got, args} end

    expect(Mock, :expose_binding, fn :mock_transport, "ctx-9", "report", callback ->
      assert callback.([1, 2]) == {:got, [1, 2]}
      :ok
    end)

    assert :ok = Session.expose_binding(s, "ctx-9", "report", cb)
  end

  test "evaluate on an unknown page id returns :not_found", %{session: s} do
    assert {:error, :not_found} = Session.evaluate(s, "nope", "1+1")
  end
end
