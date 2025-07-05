# Simple test to start Playwright server
IO.puts("Testing simple server startup...")

# Very basic PowerShell command
simple_command = """
cd $env:TEMP
npx -y playwright run-server --port 3333
"""

IO.puts("Running simple command in background...")

# Start it in background
spawn(fn ->
  {output, exit_code} = System.cmd("powershell.exe", [
    "-Command", simple_command
  ])
  IO.puts("Server output: #{output}")
  IO.puts("Server exit code: #{exit_code}")
end)

IO.puts("Waiting 15 seconds for server to start...")
Process.sleep(15_000)

# Test connection
IO.puts("Testing connection...")
case :gen_tcp.connect('localhost', 3333, [:binary, active: false], 2000) do
  {:ok, socket} ->
    :gen_tcp.close(socket)
    IO.puts("✓ Server is running!")
  {:error, reason} ->
    IO.puts("✗ Server not accessible: #{inspect(reason)}")
end