defmodule Playwriter.Test.Fixtures do
  @moduledoc """
  Test fixtures for Playwright responses.
  """

  @doc "Generate a browser launch response"
  def browser_launched do
    %{
      guid: "browser@" <> random_id(),
      version: "120.0.0.0"
    }
  end

  @doc "Generate a context creation response"
  def context_created do
    %{
      context: %{guid: "context@" <> random_id()},
      tracing: %{guid: "tracing@" <> random_id()}
    }
  end

  @doc "Generate a page creation response"
  def page_created do
    %{
      guid: "page@" <> random_id(),
      main_frame: %{guid: "frame@" <> random_id()}
    }
  end

  @doc "Generate a navigation response"
  def navigation_response do
    %{
      response: %{
        guid: "response@" <> random_id(),
        status: 200,
        url: "https://example.com"
      }
    }
  end

  @doc "Generate HTML content response"
  def html_content(html \\ nil) do
    %{
      value:
        html ||
          """
          <!DOCTYPE html>
          <html>
          <head><title>Example</title></head>
          <body><h1>Hello World</h1></body>
          </html>
          """
    }
  end

  @doc "Generate screenshot response (minimal PNG)"
  def screenshot_data do
    # Minimal valid 1x1 transparent PNG
    png_bytes =
      <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44,
        0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, 0x08, 0x06, 0x00, 0x00, 0x00, 0x1F,
        0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, 0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00,
        0x01, 0x00, 0x00, 0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
        0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82>>

    %{binary: Base.encode64(png_bytes)}
  end

  @doc "Generate a close response"
  def close_response do
    %{}
  end

  defp random_id do
    :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
  end
end
