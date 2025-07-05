#!/usr/bin/env elixir

# Simple test to understand the context options issue
IO.puts("Testing Browser.new_context with various options...")

# Load the dependencies
Mix.install([
  {:playwright, "~> 1.46"}
])

# Test the prepare function directly
defmodule TestPrepare do
  alias Playwright.SDK.Extra
  
  def test_prepare_function do
    IO.puts("Testing prepare function with different options...")
    
    # Test 1: Empty map
    IO.puts("Test 1: Empty map")
    try do
      result = prepare(%{})
      IO.puts("✓ Success: #{inspect(result)}")
    rescue
      e -> IO.puts("✗ Error: #{inspect(e)}")
    end
    
    # Test 2: headless option
    IO.puts("\nTest 2: headless option")
    try do
      result = prepare(%{headless: false})
      IO.puts("✓ Success: #{inspect(result)}")
    rescue
      e -> IO.puts("✗ Error: #{inspect(e)}")
    end
    
    # Test 3: devtools option
    IO.puts("\nTest 3: devtools option")
    try do
      result = prepare(%{devtools: true})
      IO.puts("✓ Success: #{inspect(result)}")
    rescue
      e -> IO.puts("✗ Error: #{inspect(e)}")
    end
    
    # Test 4: Multiple options
    IO.puts("\nTest 4: Multiple options")
    try do
      result = prepare(%{headless: false, devtools: true})
      IO.puts("✓ Success: #{inspect(result)}")
    rescue
      e -> IO.puts("✗ Error: #{inspect(e)}")
    end
  end
  
  # Copy the prepare function from browser.ex
  defp prepare(%{extra_http_headers: headers}) do
    %{
      extraHTTPHeaders:
        Enum.reduce(headers, [], fn {k, v}, acc ->
          [%{name: k, value: v} | acc]
        end)
    }
  end

  defp prepare(opts) when is_map(opts) do
    Enum.reduce(opts, %{}, fn {k, v}, acc -> Map.put(acc, prepare(k), v) end)
  end

  defp prepare(string) when is_binary(string) do
    string
  end

  defp prepare(atom) when is_atom(atom) do
    Extra.Atom.to_string(atom)
    |> Recase.to_camel()
    |> Extra.Atom.from_string()
  end
end

TestPrepare.test_prepare_function()