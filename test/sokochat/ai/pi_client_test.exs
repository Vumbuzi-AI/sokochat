defmodule Sokochat.AI.PiClientTest do
  use ExUnit.Case, async: false
  alias Sokochat.AI.PiClient
  setup {Req.Test, :verify_on_exit!}

  setup do
    previous = Application.get_env(:sokochat, :intelligence)

    Application.put_env(:sokochat, :intelligence,
      backend: "pi",
      pi_url: "http://pi.local",
      pi_token: String.duplicate("a", 32)
    )

    Process.put(:pi_req_options, plug: {Req.Test, __MODULE__})

    on_exit(fn ->
      if previous,
        do: Application.put_env(:sokochat, :intelligence, previous),
        else: Application.delete_env(:sokochat, :intelligence)
    end)

    :ok
  end

  test "reacquires the immutable request without waiting inside the transport adapter" do
    payload = %{
      workspace_id: 4,
      conversation_id: 12,
      request_id: "message-99",
      input: [%{role: "user", content: "Hello"}]
    }

    Req.Test.expect(__MODULE__, fn conn ->
      assert conn |> Req.Test.raw_body() |> IO.iodata_to_binary() |> Jason.decode!() ==
               Jason.decode!(Jason.encode!(payload))

      assert Plug.Conn.get_req_header(conn, "authorization") == [
               "Bearer " <> String.duplicate("a", 32)
             ]

      conn |> Plug.Conn.put_status(202) |> Req.Test.json(%{status: "pending"})
    end)

    assert {:ok, %{"status" => "pending"}} = PiClient.exchange(payload)
  end

  test "rejects malformed stored replies instead of saving them as customer messages" do
    assert {:error, "The Pi service returned an invalid sales reply."} =
             PiClient.decode_answer(%{"text" => "{}", "tokens" => 0})
  end

  test "decodes a valid stored result for the durable completion transaction" do
    result = %{
      "text" => Jason.encode!(%{reply: "Hello there!", policy: "ok", cta: nil}),
      "tokens" => 12
    }

    assert {:ok, %{reply: "Hello there!", cta: nil, policy: "ok", tokens: 12}} =
             PiClient.decode_answer(result)
  end
end
