# Configure Mox for transport mocking
Mox.defmock(Playwriter.Transport.Mock, for: Playwriter.Transport.Behaviour)

# Configure ExUnit
ExUnit.configure(
  exclude: [
    :skip_ci,
    :integration,
    :requires_browser,
    :requires_windows_server,
    :requires_legacy_server,
    :wsl_only,
    :chaos
  ]
)

local = if System.get_env("INTEGRATION"), do: [:integration, :requires_browser], else: []
windows = if System.get_env("WINDOWS_SERVER"), do: [:requires_windows_server], else: []
ExUnit.configure(include: local ++ windows)

ExUnit.start()
