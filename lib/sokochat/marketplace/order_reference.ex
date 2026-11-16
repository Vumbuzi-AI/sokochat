defmodule Sokochat.Marketplace.OrderReference do
  @moduledoc "Stable, random public references; internal IDs remain private to order actions."

  def generate do
    <<a::binary-size(4), b::binary-size(4), c::binary-size(4)>> =
      :crypto.strong_rand_bytes(6) |> Base.encode16()

    "SC-#{a}-#{b}-#{c}"
  end
end
