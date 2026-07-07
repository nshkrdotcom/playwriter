defmodule Playwriter.Transport.WindowsCmdTest do
  @moduledoc """
  Pure-function unit tests for the WindowsCmd wire protocol: command encoding,
  result-envelope decoding, stream framing, and message routing. These exercise
  the protocol contract without a browser or a live PowerShell port.
  """
  use ExUnit.Case, async: true

  alias Playwriter.Transport.WindowsCmd

  describe "encode_command/3" do
    test "encodes {id, method, params} as a JSON line" do
      json = WindowsCmd.encode_command(7, "evaluate", %{pageId: "page-0", expression: "1+1"})
      assert {:ok, decoded} = Jason.decode(json)

      assert decoded == %{
               "id" => 7,
               "method" => "evaluate",
               "params" => %{"pageId" => "page-0", "expression" => "1+1"}
             }

      refute String.contains?(json, "\n")
    end
  end

  describe "process_result/1" do
    test "guid without mainFrame -> the bare guid (context / CDP session)" do
      assert {:ok, "ctx-0"} = WindowsCmd.process_result(%{"guid" => "ctx-0"})
      assert {:ok, "cdp-1"} = WindowsCmd.process_result(%{"guid" => "cdp-1"})
    end

    test "guid with mainFrame -> page/frame map (page == frame on Windows)" do
      assert {:ok, %{guid: "page-0", main_frame: %{guid: "page-0"}}} =
               WindowsCmd.process_result(%{
                 "guid" => "page-0",
                 "mainFrame" => %{"guid" => "page-0"}
               })
    end

    test "json envelope returns the value verbatim (any JSON type)" do
      assert {:ok, true} = WindowsCmd.process_result(%{"json" => true})
      assert {:ok, 2} = WindowsCmd.process_result(%{"json" => 2})
      assert {:ok, nil} = WindowsCmd.process_result(%{"json" => nil})
      assert {:ok, %{"a" => 1}} = WindowsCmd.process_result(%{"json" => %{"a" => 1}})
      assert {:ok, [1, 2, 3]} = WindowsCmd.process_result(%{"json" => [1, 2, 3]})
    end

    test "json envelope wins over an inner value that itself looks like a guid" do
      # The distinct {json} envelope is what lets evaluate return {guid: ...}
      # data without being mistaken for a handle.
      assert {:ok, %{"guid" => "x"}} = WindowsCmd.process_result(%{"json" => %{"guid" => "x"}})
    end

    test "value_b64 envelope decodes base64 to a binary (screenshot / PCM)" do
      png = <<0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A>>
      assert {:ok, ^png} = WindowsCmd.process_result(%{"value_b64" => Base.encode64(png)})
    end

    test "value envelope is a plain string, no base64 sniffing" do
      # Content that *starts* like a PNG data-uri prefix must stay a string now.
      assert {:ok, "iVBORw0KGgo not really a png"} =
               WindowsCmd.process_result(%{"value" => "iVBORw0KGgo not really a png"})

      assert {:ok, "<html></html>"} = WindowsCmd.process_result(%{"value" => "<html></html>"})
    end

    test "ok -> :ok, unknown map -> {:ok, map}" do
      assert :ok = WindowsCmd.process_result(%{"ok" => true})
      assert {:ok, %{"weird" => 1}} = WindowsCmd.process_result(%{"weird" => 1})
    end
  end

  describe "split_messages/2 (stream framing)" do
    test "one complete line -> one message, empty buffer" do
      {msgs, buf} = WindowsCmd.split_messages("", ~s({"id":1,"result":{"ok":true}}\n))
      assert msgs == [%{"id" => 1, "result" => %{"ok" => true}}]
      assert buf == ""
    end

    test "multiple messages in one chunk are all decoded" do
      {msgs, buf} =
        WindowsCmd.split_messages("", ~s({"id":1,"result":{}}\n{"id":2,"error":"x"}\n))

      assert msgs == [%{"id" => 1, "result" => %{}}, %{"id" => 2, "error" => "x"}]
      assert buf == ""
    end

    test "a partial trailing line is buffered, not decoded" do
      {msgs, buf} = WindowsCmd.split_messages("", ~s({"id":1,"result":{}}\n{"id":2,"res))
      assert msgs == [%{"id" => 1, "result" => %{}}]
      assert buf == ~s({"id":2,"res)
    end

    test "a buffered partial completes on the next chunk" do
      {msgs1, buf1} = WindowsCmd.split_messages("", ~s({"id":2,"res))
      assert msgs1 == []
      {msgs2, buf2} = WindowsCmd.split_messages(buf1, ~s(ult":{"ok":true}}\n))
      assert msgs2 == [%{"id" => 2, "result" => %{"ok" => true}}]
      assert buf2 == ""
    end

    test "stray non-JSON stdout lines are dropped" do
      {msgs, buf} =
        WindowsCmd.split_messages("", ~s(some node warning\n{"id":1,"result":{"ok":true}}\n))

      assert msgs == [%{"id" => 1, "result" => %{"ok" => true}}]
      assert buf == ""
    end
  end

  describe "classify_message/1 (routing)" do
    test "result -> response" do
      assert {:response, 1, %{"ok" => true}} =
               WindowsCmd.classify_message(%{"id" => 1, "result" => %{"ok" => true}})
    end

    test "error -> error_response" do
      assert {:error_response, 3, "boom"} =
               WindowsCmd.classify_message(%{"id" => 3, "error" => "boom"})
    end

    test "binding event -> binding dispatch with args" do
      msg = %{"event" => "binding", "name" => "cb", "callId" => "call-1", "args" => [1, 2]}
      assert {:binding, "cb", "call-1", [1, 2]} = WindowsCmd.classify_message(msg)
    end

    test "binding event without args defaults to []" do
      msg = %{"event" => "binding", "name" => "cb", "callId" => "call-2"}
      assert {:binding, "cb", "call-2", []} = WindowsCmd.classify_message(msg)
    end

    test "ready / unknown messages are ignored" do
      assert :ignore = WindowsCmd.classify_message(%{"ready" => true})
      assert :ignore = WindowsCmd.classify_message(%{"random" => "noise"})
    end
  end

  describe "node_script/0" do
    test "embeds handlers for every new capability" do
      script = WindowsCmd.node_script()

      for token <- [
            "case 'evaluate'",
            "case 'waitForFunction'",
            "case 'addInitScript'",
            "case 'addCookies'",
            "case 'storageState'",
            "case 'newCDPSession'",
            "case 'cdpSend'",
            "case 'exposeBinding'",
            "case 'bindingResult'",
            "value_b64:",
            "json:",
            "event: 'binding'"
          ] do
        assert String.contains?(script, token), "node script missing: #{token}"
      end
    end
  end

  describe "get_windows_user/0" do
    test "config :playwriter, :windows_user overrides detection" do
      original = Application.get_env(:playwriter, :windows_user)
      Application.put_env(:playwriter, :windows_user, "override-user")

      on_exit(fn ->
        case original do
          nil -> Application.delete_env(:playwriter, :windows_user)
          value -> Application.put_env(:playwriter, :windows_user, value)
        end
      end)

      assert WindowsCmd.get_windows_user() == "override-user"
    end
  end
end
