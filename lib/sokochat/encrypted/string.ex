defmodule Sokochat.Encrypted.String do
  use Cloak.Ecto.Binary, vault: Sokochat.Vault
end
