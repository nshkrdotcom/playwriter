# Configure Mox for transport mocking
Mox.defmock(Playwriter.Transport.Mock, for: Playwriter.Transport.Behaviour)

# Configure ExUnit
ExUnit.configure(
  exclude: [
    :skip_ci,
    :integration,
    :requires_browser,
    :requires_windows_server,
    :wsl_only,
    :chaos
  ]
)

# Include integration tests when INTEGRATION=true
if System.get_env("INTEGRATION") do
  ExUnit.configure(include: [:integration, :requires_browser])
end

# Include Windows server tests when WINDOWS_SERVER=true
if System.get_env("WINDOWS_SERVER") do
  ExUnit.configure(include: [:requires_windows_server])
end

ExUnit.start()
