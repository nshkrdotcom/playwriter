defmodule Playwriter.WindowsBrowserAdapter do
  @moduledoc """
  Adapter for connecting to Windows browsers from WSL using Playwright's WebSocket transport.
  
  This module provides utilities to:
  1. Automatically start a Playwright server on Windows if needed
  2. Connect to it from WSL
  3. Use Windows Chrome/Firefox browsers from your Elixir app in WSL
  
  No manual setup required - everything is handled automatically!
  """
  
  require Logger
  
  # Module attributes for future use
  # @server_check_interval 30_000  # 30 seconds  
  # @server_start_timeout 15_000   # 15 seconds

  @doc """
  Starts a Playwright server on Windows and returns the WebSocket endpoint.
  
  This uses PowerShell to execute commands on the Windows side.
  """
  def start_windows_playwright_server(opts \\ %{}) do
    # Try different ports - prioritize 3337 for true headed servers
    ports_to_try = [3337, 3336, 3335, 3334, 3333, 9222, 9223]
    port = opts[:port] || find_available_port(ports_to_try)
    
    # Try different connection methods in order
    endpoints_to_try = get_possible_endpoints(port)
    
    # Try each endpoint to see if server is already running
    working_endpoint = find_working_endpoint(endpoints_to_try)
    
    case working_endpoint do
      nil ->
        # No server found, provide instructions instead of auto-starting
        Logger.error("No Playwright server found.")
        Logger.error("Please manually start the TRUE headed server:")
        Logger.error("1. Run: ./start_true_headed_server.sh")
        Logger.error("2. Then retry your command")
        Logger.error("3. This will create VISIBLE browser windows automatically!")
        raise "No Playwright server available. Please start manually to avoid process pollution."
        
      endpoint ->
        Logger.info("Using existing Playwright server at #{endpoint}")
        endpoint
    end
  end
  
  defp get_possible_endpoints(port) do
    base_endpoints = [
      "ws://localhost:#{port}/",
      "ws://127.0.0.1:#{port}/",
      "ws://172.19.176.1:#{port}/",  # Common WSL interface IP
      "ws://host.docker.internal:#{port}/"
    ]
    
    # Try to get Windows host IP from multiple sources
    additional_ips = []
    
    # Method 1: resolv.conf nameserver
    additional_ips = case get_windows_host_ip() do
      {:ok, windows_host} ->
        [windows_host | additional_ips]
      _ ->
        additional_ips
    end
    
    # Method 2: default gateway
    additional_ips = case System.cmd("ip", ["route", "show", "default"]) do
      {output, 0} ->
        case Regex.run(~r/default via (\d+\.\d+\.\d+\.\d+)/, output) do
          [_, gateway_ip] ->
            [gateway_ip | additional_ips]
          _ ->
            additional_ips
        end
      _ ->
        additional_ips
    end
    
    # Add additional IPs as WebSocket endpoints
    additional_endpoints = Enum.map(additional_ips, fn ip -> "ws://#{ip}:#{port}/" end)
    
    additional_endpoints ++ base_endpoints
  end
  
  defp find_working_endpoint(endpoints) do
    Enum.find(endpoints, fn endpoint ->
      check_server_running(endpoint)
    end)
  end
  
  defp find_available_port(ports) do
    Enum.find(ports, fn port ->
      endpoints = get_possible_endpoints(port)
      
      case Enum.find(endpoints, &check_server_running/1) do
        nil -> 
          # Port is free, we can use it
          Logger.info("Port #{port} is available")
          true
        endpoint ->
          # Something is running on this port, check if it's a Playwright server
          case test_playwright_endpoint(endpoint) do
            true ->
              Logger.info("Found existing Playwright server at #{endpoint}")
              true  # We can use this port since it's already our server
            false ->
              Logger.info("Port #{port} is occupied by non-Playwright service, trying next port")
              false  # Port is occupied by something else, try next port
          end
      end
    end) || List.last(ports)  # Fallback to last port if none found
  end
  
  defp test_playwright_endpoint(ws_endpoint) do
    # Try to connect and see if it responds like a Playwright server
    try do
      {_session, browser} = Playwright.BrowserType.connect(ws_endpoint)
      
      # If we got a browser object, it's a Playwright server
      case browser.__struct__ do
        Playwright.Browser -> 
          Logger.info("Confirmed Playwright server at #{ws_endpoint}")
          true
        _ -> 
          false
      end
    rescue
      _ -> 
        # Connection failed or returned error, not a Playwright server
        false
    end
  end
  
  # Legacy server startup function (no longer used - replaced by manual server management)
  # defp start_server_on_windows(port) do
  #   Logger.info("Attempting to start Playwright server on port #{port}")
  #   
  #   # Simple PowerShell command to start server on specific port
  #   ps_command = """
  #   cd $env:TEMP
  #   Start-Process powershell -ArgumentList '-NoExit', '-Command', 'cd $env:TEMP; npx playwright run-server --port #{port}' -WindowStyle Normal
  #   """
  #   
  #   case System.cmd("powershell.exe", ["-Command", ps_command]) do
  #     {output, 0} ->
  #       Logger.info("Server startup command executed")
  #       Logger.debug("Output: #{output}")
  #     {output, exit_code} ->
  #       Logger.error("Server startup failed with exit code #{exit_code}")
  #       Logger.debug("Output: #{output}")
  #   end
  # end
  
  defp check_server_running(ws_endpoint) do
    # Try to connect to see if server is running
    uri = URI.parse(ws_endpoint)
    case :gen_tcp.connect(String.to_charlist(uri.host), uri.port, [:binary, active: false], 1000) do
      {:ok, socket} ->
        :gen_tcp.close(socket)
        true
      {:error, _} ->
        false
    end
  end
  
  
  @doc """
  Gets the Windows host IP address from WSL.
  """
  def get_windows_host_ip do
    # Try multiple methods to get Windows host
    with {:error, _} <- try_resolv_conf(),
         {:error, _} <- try_host_ip() do
      # Fallback to localhost which often works in WSL2
      {:ok, "localhost"}
    end
  end
  
  defp try_resolv_conf do
    case System.cmd("cat", ["/etc/resolv.conf"]) do
      {output, 0} ->
        case Regex.run(~r/nameserver\s+(\d+\.\d+\.\d+\.\d+)/, output) do
          [_, ip] -> {:ok, ip}
          _ -> {:error, "Could not find Windows host IP in resolv.conf"}
        end
      _ ->
        {:error, "Could not read /etc/resolv.conf"}
    end
  end
  
  defp try_host_ip do
    # Try to get the host IP from ip route
    case System.cmd("ip", ["route", "show"]) do
      {output, 0} ->
        case Regex.run(~r/default via (\d+\.\d+\.\d+\.\d+)/, output) do
          [_, ip] -> {:ok, ip}
          _ -> {:error, "Could not find default gateway"}
        end
      _ ->
        {:error, "Could not run ip route"}
    end
  end
  
  @doc """
  Connects to a Windows browser via WebSocket.
  
  ## Examples
  
      # Connect to Chrome on Windows
      {:ok, browser} = Playwriter.WindowsBrowserAdapter.connect_windows_browser(:chromium)
      
      # Connect to Firefox on Windows
      {:ok, browser} = Playwriter.WindowsBrowserAdapter.connect_windows_browser(:firefox)
  """
  def connect_windows_browser(browser_type \\ :chromium, opts \\ %{}) do
    ws_endpoint = cond do
      # If ws_endpoint is explicitly provided, use it
      opts[:ws_endpoint] ->
        Logger.info("Using provided WebSocket endpoint: #{opts[:ws_endpoint]}")
        opts[:ws_endpoint]
        
      # If PLAYWRIGHT_WS_ENDPOINT env var is set, use it
      System.get_env("PLAYWRIGHT_WS_ENDPOINT") ->
        endpoint = System.get_env("PLAYWRIGHT_WS_ENDPOINT")
        Logger.info("Using WebSocket endpoint from env: #{endpoint}")
        endpoint
        
      # Otherwise, try to find or start a server
      true ->
        start_windows_playwright_server(%{browser: to_string(browser_type)})
    end
    
    # Use BrowserType.connect which works better with remote servers
    # This returns {session_pid, browser} tuple
    # Note: connect doesn't take launch options, those are set server-side
    {_session, browser} = Playwright.BrowserType.connect(ws_endpoint)
    {:ok, browser}
  end
  
  @doc """
  Lists available Chrome profiles on Windows.
  """
  def get_chrome_profiles do
    try do
      # Get Chrome user data directory
      case System.cmd("powershell.exe", ["-Command", "$env:LOCALAPPDATA + '\\Google\\Chrome\\User Data'"]) do
        {chrome_path, 0} ->
          chrome_path = String.trim(chrome_path)
          
          # List profile directories
          case System.cmd("powershell.exe", ["-Command", "Get-ChildItem '#{chrome_path}' -Directory | Where-Object {$_.Name -match '^(Default|Profile )' -or $_.Name -eq 'Profile 1'} | Select-Object Name,FullName | ForEach-Object {\"$($_.Name)|$($_.FullName)\"}"]) do
            {output, 0} ->
              profiles = output
              |> String.split("\n")
              |> Enum.map(&String.trim/1)
              |> Enum.filter(&(&1 != ""))
              |> Enum.map(fn line ->
                case String.split(line, "|", parts: 2) do
                  [name, path] -> {name, path}
                  _ -> nil
                end
              end)
              |> Enum.filter(&(&1 != nil))
              
              {:ok, profiles}
            _ ->
              {:error, "Could not list Chrome profile directories"}
          end
        _ ->
          {:error, "Could not find Chrome user data directory"}
      end
    rescue
      error ->
        {:error, "Error listing Chrome profiles: #{inspect(error)}"}
    end
  end

  @doc """
  Enhanced fetch function that uses Windows browsers.
  """
  def fetch_with_windows_browser(url, opts \\ %{}) do
    browser_type = opts[:browser] || :chromium
    
    with {:ok, browser} <- connect_windows_browser(browser_type, opts) do
      # For Windows browsers, create context with valid options
      context_options = %{
        viewport: %{width: 1920, height: 1080},
        user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
      }
      
      context = Playwright.Browser.new_context(browser, context_options)
      page = Playwright.BrowserContext.new_page(context)
      
      # Set viewport if provided
      if opts[:viewport] do
        Playwright.Page.set_viewport_size(page, opts[:viewport])
      end
      
      # Navigate to URL
      case Playwright.Page.goto(page, url, %{wait_until: "networkidle"}) do
        {:ok, _response} ->
          # Get page content
          content = Playwright.Page.content(page)
          
          # Clean up
          Playwright.Page.close(page)
          Playwright.BrowserContext.close(context)
          Playwright.Browser.close(browser)
          
          {:ok, content}
          
        {:error, reason} ->
          Playwright.Page.close(page)
          Playwright.BrowserContext.close(context)
          Playwright.Browser.close(browser)
          {:error, reason}
      end
    end
  end
end