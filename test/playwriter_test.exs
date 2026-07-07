defmodule PlaywriterTest do
  use ExUnit.Case, async: true

  import Mox

  setup :verify_on_exit!

  describe "version/0" do
    test "returns version string" do
      assert Playwriter.version() == "0.3.0"
    end
  end

  describe "with_browser/2" do
    @tag :requires_browser
    test "yields context to function and cleans up" do
      result =
        Playwriter.with_browser([headless: true], fn ctx ->
          assert Map.has_key?(ctx, :session)
          assert Map.has_key?(ctx, :page)
          assert is_pid(ctx.session)
          assert is_binary(ctx.page)
          :test_result
        end)

      assert {:ok, :test_result} = result
    end

    @tag :requires_browser
    test "cleans up on error" do
      result =
        Playwriter.with_browser([headless: true], fn _ctx ->
          raise "test error"
        end)

      assert {:error, %RuntimeError{message: "test error"}} = result
    end
  end

  describe "fetch_html/2" do
    @tag :requires_browser
    test "fetches HTML from URL" do
      {:ok, html} = Playwriter.fetch_html("https://example.com", headless: true)

      assert String.contains?(html, "Example Domain")
      assert String.contains?(html, "<html")
    end
  end

  describe "screenshot/2" do
    @tag :requires_browser
    test "takes screenshot of URL" do
      {:ok, data} = Playwriter.screenshot("https://example.com", headless: true)

      # PNG magic bytes
      assert <<0x89, 0x50, 0x4E, 0x47, _::binary>> = data
    end

    @tag :requires_browser
    test "supports full_page option" do
      {:ok, data} = Playwriter.screenshot("https://example.com", headless: true, full_page: true)

      assert <<0x89, 0x50, 0x4E, 0x47, _::binary>> = data
    end
  end

  describe "goto/3" do
    @tag :requires_browser
    test "navigates to URL" do
      {:ok, :ok} =
        Playwriter.with_browser([headless: true], fn ctx ->
          Playwriter.goto(ctx, "https://example.com")
        end)
    end
  end

  describe "content/1" do
    @tag :requires_browser
    test "gets page content after navigation" do
      {:ok, html} =
        Playwriter.with_browser([headless: true], fn ctx ->
          :ok = Playwriter.goto(ctx, "https://example.com")
          {:ok, html} = Playwriter.content(ctx)
          html
        end)

      assert String.contains?(html, "Example Domain")
    end
  end

  describe "click/3" do
    @tag :requires_browser
    test "clicks element" do
      {:ok, _} =
        Playwriter.with_browser([headless: true], fn ctx ->
          :ok = Playwriter.goto(ctx, "https://example.com")
          # example.com has a link, try clicking it
          result = Playwriter.click(ctx, "a", timeout: 5000)
          result
        end)
    end
  end
end
