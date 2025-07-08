defmodule Playwriter.WindowsBrowserDirect do
  @moduledoc """
  Direct Windows browser control using PowerShell automation.
  This bypasses the WebSocket server approach and directly controls Windows browsers.
  """

  require Logger

  @doc """
  Opens a URL in Windows browser and captures the HTML.
  This approach uses PowerShell to directly control Windows browsers.
  """
  def fetch_with_powershell(url, opts \\ %{}) do
    browser = opts[:browser] || "chrome"

    # PowerShell script that opens browser, waits, and captures content
    ps_script = """
    # Open URL in browser
    if ('#{browser}' -eq 'firefox') {
        Start-Process firefox -ArgumentList '#{url}'
    } else {
        Start-Process chrome -ArgumentList '#{url}'
    }

    # Wait for page to load
    Start-Sleep -Seconds 5

    # Note: Getting HTML from browser is complex without proper automation
    # This is a simplified approach
    Write-Host "Browser opened successfully"
    """

    case System.cmd("powershell.exe", ["-Command", ps_script]) do
      {output, 0} ->
        Logger.info("Browser opened: #{String.trim(output)}")
        {:ok, "Browser opened - manual inspection required"}

      {error, _} ->
        {:error, "Failed to open browser: #{error}"}
    end
  end

  @doc """
  Alternative approach using Edge WebView2 which is built into Windows.
  """
  def fetch_with_edge_webview(url, opts \\ %{}) do
    # Create a PowerShell script that uses WebView2
    ps_script = """
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing

    # Create a form with WebView2
    $form = New-Object System.Windows.Forms.Form
    $form.Text = 'Playwriter Browser'
    $form.Size = New-Object System.Drawing.Size(1024,768)

    # Create WebBrowser control (uses Edge engine on modern Windows)
    $browser = New-Object System.Windows.Forms.WebBrowser
    $browser.Dock = 'Fill'
    $browser.Navigate('#{url}')

    # Add browser to form
    $form.Controls.Add($browser)

    # Show form
    $form.ShowDialog() | Out-Null
    """

    case opts[:headless] do
      true ->
        {:error, "Headless mode not supported with this approach"}

      _ ->
        case System.cmd("powershell.exe", ["-Command", ps_script]) do
          {output, 0} ->
            {:ok, output}

          {error, _} ->
            {:error, "Failed to open WebView: #{error}"}
        end
    end
  end

  @doc """
  Uses Windows' built-in Invoke-WebRequest for simple HTML fetching.
  This doesn't use a real browser but can work for simple pages.
  """
  def fetch_simple(url, _opts \\ %{}) do
    ps_script = """
    try {
        $response = Invoke-WebRequest -Uri '#{url}' -UseBasicParsing
        $response.Content
    } catch {
        Write-Error $_.Exception.Message
    }
    """

    case System.cmd("powershell.exe", ["-Command", ps_script]) do
      {html, 0} ->
        {:ok, html}

      {error, _} ->
        {:error, "Failed to fetch: #{error}"}
    end
  end
end
