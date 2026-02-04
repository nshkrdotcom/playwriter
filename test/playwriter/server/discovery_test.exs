defmodule Playwriter.Server.DiscoveryTest do
  use ExUnit.Case, async: true

  alias Playwriter.Server.Discovery

  describe "discover/1" do
    test "returns error when no server found" do
      assert {:error, :not_found} = Discovery.discover(ports: [59_999], timeout: 100)
    end

    @tag :requires_windows_server
    test "finds running Windows server" do
      {:ok, endpoint} = Discovery.discover()

      assert String.starts_with?(endpoint, "ws://")
    end
  end

  describe "hosts/0" do
    test "includes localhost" do
      hosts = Discovery.hosts()
      assert "localhost" in hosts
    end

    test "includes 127.0.0.1" do
      hosts = Discovery.hosts()
      assert "127.0.0.1" in hosts
    end
  end

  describe "get_wsl2_host_ip/0" do
    @tag :wsl_only
    test "extracts IP from resolv.conf" do
      ip = Discovery.get_wsl2_host_ip()

      if ip do
        assert Regex.match?(~r/^\d+\.\d+\.\d+\.\d+$/, ip)
      end
    end
  end

  describe "check_endpoint/2" do
    test "returns error for unreachable endpoint" do
      assert {:error, _} = Discovery.check_endpoint("ws://localhost:59999/", timeout: 100)
    end

    @tag :requires_windows_server
    test "returns ok for reachable endpoint" do
      assert :ok = Discovery.check_endpoint("ws://localhost:3337/")
    end
  end
end
