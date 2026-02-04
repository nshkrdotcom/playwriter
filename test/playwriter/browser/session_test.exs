defmodule Playwriter.Browser.SessionTest do
  use ExUnit.Case, async: true

  alias Playwriter.Browser.Session

  describe "start_link/1" do
    @tag :requires_browser
    test "starts session with local transport" do
      assert {:ok, session} = Session.start_link(mode: :local, headless: true)
      assert Process.alive?(session)
      :ok = Session.close(session)
    end

    @tag :requires_windows_server
    test "starts session with remote transport" do
      assert {:ok, session} =
               Session.start_link(mode: :remote, ws_endpoint: "ws://localhost:3337/")

      assert Process.alive?(session)
      :ok = Session.close(session)
    end
  end

  describe "new_page/2" do
    @tag :requires_browser
    test "creates page in default context" do
      {:ok, session} = Session.start_link(mode: :local, headless: true)
      assert {:ok, page_id} = Session.new_page(session)
      assert is_binary(page_id)
      :ok = Session.close(session)
    end
  end

  describe "new_context/2" do
    @tag :requires_browser
    test "creates isolated context" do
      {:ok, session} = Session.start_link(mode: :local, headless: true)
      assert {:ok, context_guid} = Session.new_context(session, [])
      assert is_binary(context_guid)
      :ok = Session.close(session)
    end

    @tag :requires_browser
    test "creates context with options" do
      {:ok, session} = Session.start_link(mode: :local, headless: true)

      assert {:ok, context_guid} =
               Session.new_context(session,
                 viewport: %{width: 1280, height: 720},
                 user_agent: "Test Agent"
               )

      assert is_binary(context_guid)
      :ok = Session.close(session)
    end
  end

  describe "goto/4" do
    @tag :requires_browser
    test "navigates to URL" do
      {:ok, session} = Session.start_link(mode: :local, headless: true)
      {:ok, page} = Session.new_page(session)

      assert :ok = Session.goto(session, page, "https://example.com")

      :ok = Session.close(session)
    end
  end

  describe "content/2" do
    @tag :requires_browser
    test "returns page HTML" do
      {:ok, session} = Session.start_link(mode: :local, headless: true)
      {:ok, page} = Session.new_page(session)
      :ok = Session.goto(session, page, "https://example.com")

      assert {:ok, html} = Session.content(session, page)
      assert String.contains?(html, "Example Domain")

      :ok = Session.close(session)
    end
  end

  describe "screenshot/3" do
    @tag :requires_browser
    test "takes screenshot" do
      {:ok, session} = Session.start_link(mode: :local, headless: true)
      {:ok, page} = Session.new_page(session)
      :ok = Session.goto(session, page, "https://example.com")

      assert {:ok, data} = Session.screenshot(session, page)
      # PNG magic bytes
      assert <<0x89, 0x50, 0x4E, 0x47, _::binary>> = data

      :ok = Session.close(session)
    end
  end

  describe "click/4" do
    @tag :requires_browser
    test "clicks element" do
      {:ok, session} = Session.start_link(mode: :local, headless: true)
      {:ok, page} = Session.new_page(session)
      :ok = Session.goto(session, page, "https://example.com")

      # example.com has a link
      assert :ok = Session.click(session, page, "a")

      :ok = Session.close(session)
    end
  end

  describe "fill/5" do
    @tag :requires_browser
    test "fills input field" do
      {:ok, session} = Session.start_link(mode: :local, headless: true)
      {:ok, page} = Session.new_page(session)
      # Use httpbin which has form inputs
      :ok = Session.goto(session, page, "https://httpbin.org/forms/post")

      assert :ok = Session.fill(session, page, "input[name=custname]", "Test User")

      :ok = Session.close(session)
    end
  end

  describe "close_page/2" do
    @tag :requires_browser
    test "closes page" do
      {:ok, session} = Session.start_link(mode: :local, headless: true)
      {:ok, page} = Session.new_page(session)

      assert :ok = Session.close_page(session, page)

      # Page should not be found after close
      assert {:error, :not_found} = Session.content(session, page)

      :ok = Session.close(session)
    end
  end

  describe "close/1" do
    @tag :requires_browser
    test "closes session and cleans up" do
      {:ok, session} = Session.start_link(mode: :local, headless: true)
      {:ok, _page} = Session.new_page(session)

      assert :ok = Session.close(session)
      refute Process.alive?(session)
    end
  end
end
