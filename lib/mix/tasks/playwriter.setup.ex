defmodule Mix.Tasks.Playwriter.Setup do
  @moduledoc """
  Provisions the pinned Playwright driver and browser for one transport.

      mix playwriter.setup
      mix playwriter.setup --mode windows
      mix playwriter.setup --mode windows --check

  Local setup uses the invoking shell's Node.js and npm. Windows setup uses
  Windows Node.js and npm through WSL interop. Install the host runtime before
  running this task. The task never installs Node.js or starts a server.

  Local setup also accepts `--browser chromium|firefox|webkit|all` and
  `--with-deps` to explicitly request system libraries.
  """

  use Mix.Task
  @shortdoc "Prepare the local or WSL-to-Windows Playwright driver"

  @impl Mix.Task
  def run(args) do
    {opts, positional, invalid} =
      OptionParser.parse(args,
        strict: [mode: :string, browser: :string, with_deps: :boolean, check: :boolean]
      )

    mode = opts[:mode] || "local"
    browser = opts[:browser] || "chromium"
    with_deps = opts[:with_deps] || false
    check = opts[:check] || false

    validate!(positional, invalid, mode, browser, with_deps, check)

    Mix.Task.run("app.config")

    case Playwriter.Setup.install(
           if(mode == "windows", do: :windows, else: :local),
           browser,
           with_deps,
           check
         ) do
      :ok -> Mix.shell().info("Playwriter #{mode} driver and #{browser} ready.")
      {:error, reason} when is_binary(reason) -> Mix.raise(reason)
      {:error, reason} -> Mix.raise("Playwriter #{mode} setup failed: #{inspect(reason)}")
    end
  end

  defp validate!([], [], mode, browser, with_deps, check) do
    unless valid_options?(mode, browser, with_deps, check), do: invalid_options!()
  end

  defp validate!(_, _, _, _, _, _), do: invalid_options!()

  @spec invalid_options!() :: no_return()
  defp invalid_options!, do: Mix.raise("Invalid setup arguments. See mix help playwriter.setup.")

  defp valid_options?("windows", "chromium", false, _check), do: true

  defp valid_options?("local", browser, true, false),
    do: browser in ~w(chromium firefox webkit all)

  defp valid_options?("local", browser, false, _check),
    do: browser in ~w(chromium firefox webkit all)

  defp valid_options?(_, _, _, _), do: false
end
