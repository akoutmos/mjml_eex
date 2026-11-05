defmodule MjmlEEx.Test.Emails.Welcome do
  @moduledoc false

  # Renders the colocated welcome.meex template
  use MjmlEEx

  defp greeting(name), do: "Welcome, #{name}"
end
