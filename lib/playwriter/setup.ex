defmodule Playwriter.Setup do
  @moduledoc false

  alias Playwriter.Transport.WindowsCmd

  @version "1.65.1"
  @local_dir ".playwriter-driver"
  @browser_probe """
  const fs = require('node:fs');
  const driver = require('./node_modules/playwright');
  if (require('./node_modules/playwright/package.json').version !== process.argv[1])
    throw new Error('Unexpected Playwright package version');
  if (process.argv[2] === 'installed') process.exit(0);
  const browser = driver[process.argv[2]];
  if (!fs.existsSync(browser.executablePath()))
    throw new Error('Matching browser missing: ' + browser.executablePath());
  """

  def local_dir, do: Path.expand(@local_dir)
  def local_cli, do: Path.join(local_dir(), "node_modules/playwright/cli.js")

  def local_tools do
    with node when is_binary(node) <- System.find_executable("node"),
         npm when is_binary(npm) <- System.find_executable("npm"),
         {version, 0} <- System.cmd(node, ["--version"], stderr_to_stdout: true),
         :ok <- check_node(version),
         :ok <- version_command(npm) do
      {:ok, node, npm}
    else
      _ ->
        {:error,
         "Local setup needs Node.js >= 20 and npm in this shell. Use a supported Node LTS."}
    end
  end

  def windows_tools do
    command = """
    $ErrorActionPreference = 'Stop'
    #{windows_path_refresh()}
    Set-Location -LiteralPath $env:TEMP
    $node = Get-Command node.exe -CommandType Application
    $npm = Get-Command npm.cmd -CommandType Application
    $version = & $node.Source --version
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    $null = & $npm.Source --version
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    @{ node = $version; temp = $env:TEMP; user = $env:USERNAME } | ConvertTo-Json -Compress
    """

    with {:ok, output} <- windows_command(command),
         {:ok, %{"node" => version, "temp" => temp, "user" => user}} <-
           Jason.decode(String.trim_leading(output, "\uFEFF")),
         :ok <- check_node(version),
         :ok <- check_windows_user(user),
         {mount, 0} <- System.cmd("wslpath", ["-u", temp], stderr_to_stdout: true) do
      name = "playwriter-stdio-#{@version}"
      {:ok, temp <> "\\" <> name, Path.join(String.trim(mount), name)}
    else
      {:error, message} when is_binary(message) -> {:error, message}
      _ -> {:error, "Cannot resolve the Windows Playwriter directory using WSL interop."}
    end
  rescue
    ErlangError -> {:error, "Windows setup requires WSL interop and wslpath."}
  end

  def windows_path_refresh do
    """
    $env:Path += ';' + [Environment]::GetEnvironmentVariable('Path', 'Machine')
    $env:Path += ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
    """
  end

  def windows_shell do
    Enum.find(
      [
        "/mnt/c/Program Files/PowerShell/7/pwsh.exe",
        "/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
      ],
      &File.regular?/1
    ) || System.find_executable("powershell.exe")
  end

  def windows_args(command) do
    script =
      "$ProgressPreference = 'SilentlyContinue'; [Console]::OutputEncoding = [Text.UTF8Encoding]::new($false)\n" <>
        command

    encoded = script |> :unicode.characters_to_binary(:utf8, {:utf16, :little}) |> Base.encode64()
    ["-NoProfile", "-NonInteractive", "-EncodedCommand", encoded]
  end

  def ps_quote(value), do: "'" <> String.replace(value, "'", "''") <> "'"

  def install(:local, browser, with_deps, check) do
    with {:ok, node, npm} <- local_tools() do
      prepare_local(node, npm, local_dir(), browser, with_deps, check)
    end
  end

  def install(:windows, "chromium", false, check) do
    with {:ok, channel} <- windows_channel(),
         {:ok, dir, mount} <- windows_tools(),
         :ok <- check_installed_channel(channel) do
      prepare_windows(dir, mount, channel, check)
    end
  end

  defp prepare_local(node, _npm, dir, browser, _with_deps, true),
    do: probe_local(node, dir, browser)

  defp prepare_local(node, npm, dir, browser, with_deps, false) do
    with_setup_lock(dir, fn ->
      with :ok <- copy_driver(dir),
           :ok <- run(npm, ["ci"], dir),
           :ok <-
             run(node, browser_args("node_modules/playwright/cli.js", browser, with_deps), dir) do
        probe_local(node, dir, browser)
      end
    end)
  end

  defp prepare_windows(dir, mount, channel, true), do: check_windows_driver(dir, mount, channel)

  defp prepare_windows(dir, mount, channel, false) do
    with_setup_lock(mount, fn ->
      with :ok <- copy_driver(mount),
           :ok <- run_windows(dir, "npm.cmd", ["ci"]),
           :ok <- install_windows_browser(dir, channel),
           :ok <- File.write(Path.join(mount, "transport.js"), WindowsCmd.node_script()) do
        check_windows_driver(dir, mount, channel)
      end
    end)
  end

  defp with_setup_lock(dir, install) do
    lock = dir <> ".setup-lock"

    case File.mkdir(lock) do
      :ok ->
        try do
          install.()
        after
          File.rmdir(lock)
        end

      {:error, :eexist} ->
        {:error,
         "Setup is already locked at #{lock}. If no setup is running, remove the empty lock directory and retry."}

      error ->
        error
    end
  end

  defp install_windows_browser(dir, nil) do
    run_windows(
      dir,
      "node.exe",
      browser_args("node_modules/playwright/cli.js", "chromium", false)
    )
  end

  defp install_windows_browser(_dir, _channel), do: :ok

  def windows_channel do
    case System.get_env("PLAYWRITER_WINDOWS_CHANNEL") ||
           Application.get_env(:playwriter, :windows_channel) do
      channel when channel in [nil, "chrome", "msedge"] -> {:ok, channel}
      _ -> {:error, "Windows browser channel must be chrome or msedge."}
    end
  end

  def check_installed_channel(nil), do: :ok

  def check_installed_channel(channel) do
    relative =
      case channel do
        "chrome" -> "Google\\Chrome\\Application\\chrome.exe"
        "msedge" -> "Microsoft\\Edge\\Application\\msedge.exe"
      end

    command = """
    $roots = @(${env:ProgramFiles(x86)}, $env:ProgramFiles, $env:LOCALAPPDATA)
    foreach ($root in $roots) {
      if ($root -and (Test-Path -LiteralPath (Join-Path $root #{ps_quote(relative)}))) { exit 0 }
    }
    exit 1
    """

    case windows_command(command) do
      {:ok, _} ->
        :ok

      {:error, _} ->
        {:error,
         "Windows browser channel #{channel} is missing from its standard installation paths."}
    end
  end

  def check_windows_driver(dir, mount, channel) do
    with :ok <- driver_exists?(mount, "windows"),
         {:ok, script} <- File.read(Path.join(mount, "transport.js")),
         true <- script == WindowsCmd.node_script() do
      browser = if channel, do: "installed", else: "chromium"
      run_windows(dir, "node.exe", ["-e", @browser_probe, @version, browser])
    else
      _ ->
        {:error,
         "Windows stdio driver missing or stale. Run mix playwriter.setup --mode windows."}
    end
  end

  defp check_node(version) do
    case Version.parse(version |> String.trim() |> String.trim_leading("v")) do
      {:ok, %Version{major: major}} when major >= 20 -> :ok
      _ -> {:error, "Playwriter needs Node.js >= 20. Use a supported Node LTS."}
    end
  end

  defp version_command(executable) do
    case System.cmd(executable, ["--version"], stderr_to_stdout: true) do
      {_, 0} -> :ok
      _ -> :error
    end
  end

  defp check_windows_user(user) do
    case Application.get_env(:playwriter, :windows_user) do
      nil ->
        :ok

      override ->
        if String.downcase(override) == String.downcase(user) do
          :ok
        else
          {:error,
           "Windows account override #{override} differs from the active PowerShell user #{user}."}
        end
    end
  end

  defp copy_driver(dir) do
    source = Application.app_dir(:playwriter, "priv/driver")
    files = ["package.json", "package-lock.json"]

    with true <- Enum.all?(files, &File.regular?(Path.join(source, &1))),
         :ok <- File.mkdir_p(dir) do
      copy_driver_files(source, dir, files)
    else
      false -> {:error, "Packaged Playwright driver manifests are missing."}
      error -> error
    end
  end

  defp copy_driver_files(source, dir, files) do
    Enum.reduce_while(files, :ok, fn file, :ok ->
      continue_if_ok(File.cp(Path.join(source, file), Path.join(dir, file)))
    end)
  end

  defp probe_local(node, dir, browser) do
    with :ok <- driver_exists?(dir, "local") do
      browsers = if browser == "all", do: ~w(chromium firefox webkit), else: [browser]

      Enum.reduce_while(browsers, :ok, fn name, :ok ->
        continue_if_ok(run(node, ["-e", @browser_probe, @version, name], dir))
      end)
    end
  end

  defp continue_if_ok(:ok), do: {:cont, :ok}
  defp continue_if_ok(error), do: {:halt, error}

  defp driver_exists?(dir, mode) do
    if File.regular?(Path.join(dir, "node_modules/playwright/cli.js")) do
      :ok
    else
      {:error, "Playwright driver missing. Run mix playwriter.setup --mode #{mode}."}
    end
  end

  defp browser_args(cli, browser, with_deps) do
    [cli, "install"] ++
      if(with_deps, do: ["--with-deps"], else: []) ++
      if(browser == "all", do: [], else: [browser])
  end

  defp run(executable, args, dir) do
    case System.cmd(executable, args, cd: dir, stderr_to_stdout: true) do
      {output, 0} ->
        if String.trim(output) != "", do: IO.write(output)
        :ok

      {output, status} ->
        {:error, "#{Path.basename(executable)} exited #{status}: #{String.trim(output)}"}
    end
  end

  defp run_windows(dir, executable, args) do
    # Encode each argument to avoid PowerShell and Windows native quote translation.
    if executable == "node.exe" and List.first(args) == "-e" do
      ["-e", script, version, browser] = args
      encoded = Base.encode64(script)
      args = ["-e", "eval(Buffer.from('#{encoded}','base64').toString())", version, browser]
      windows_driver_command(dir, executable, args)
    else
      windows_driver_command(dir, executable, args)
    end
  end

  defp windows_driver_command(dir, executable, args) do
    command = """
    $ErrorActionPreference = 'Stop'
    #{windows_path_refresh()}
    Set-Location -LiteralPath #{ps_quote(dir)}
    & #{executable} #{Enum.map_join(args, " ", &ps_quote/1)}
    exit $LASTEXITCODE
    """

    case windows_command(command) do
      {:ok, output} ->
        if output != "", do: IO.puts(output)
        :ok

      error ->
        error
    end
  end

  defp windows_command(command) do
    case windows_shell() do
      nil ->
        {:error, "Windows PowerShell is unavailable. Enable WSL interop and try again."}

      shell ->
        case System.cmd(shell, windows_args(command), stderr_to_stdout: true) do
          {output, 0} ->
            {:ok, String.trim(output)}

          {output, status} ->
            {:error,
             "Windows PowerShell exited #{status}. Check Windows Node/npm and stdio setup. #{String.trim(output)}"}
        end
    end
  end
end
