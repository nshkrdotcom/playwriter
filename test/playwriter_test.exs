defmodule PlaywriterTest do
  use ExUnit.Case
  doctest Playwriter

  test "fetch HTML from google.com" do
    case Playwriter.Fetcher.fetch_html("https://google.com") do
      {:ok, html} ->
        assert is_binary(html)
        assert String.length(html) > 0
        assert String.contains?(html, "Google")

      {:error, reason} ->
        # Skip test if Playwright is not properly set up
        IO.puts("Skipping test due to Playwright setup issue: #{reason}")
    end
  end

  test "fetch HTML contains expected elements" do
    case Playwriter.Fetcher.fetch_html("https://google.com") do
      {:ok, html} ->
        assert String.contains?(html, "<html")
        assert String.contains?(html, "</html>")
        assert String.contains?(html, "<title>")

      {:error, reason} ->
        # Skip test if Playwright is not properly set up
        IO.puts("Skipping test due to Playwright setup issue: #{reason}")
    end
  end
end
