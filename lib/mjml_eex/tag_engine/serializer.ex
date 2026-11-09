defmodule MjmlEEx.TagEngine.Serializer do
  @moduledoc false

  # Turns a parsed tree of plain MJML (no expressions or components) back into an
  # MJML string. Attribute quoting and text are kept as written; whitespace between
  # attributes is normalized. The mjml_eex-only attributes (`mjml-raw-text` and
  # `mjml-no-curly-interpolation`) are removed.

  alias MjmlEEx.TagEngine.Tags

  @doc false
  @spec to_iodata([tuple()]) :: iodata()
  def to_iodata(nodes) when is_list(nodes), do: Enum.map(nodes, &node_to_iodata/1)

  defp node_to_iodata({:text, text, _meta}), do: text

  defp node_to_iodata({:block, :tag, name, attrs, children, _open_meta, _close_meta}) do
    ["<", name, attrs_to_iodata(attrs), ">", to_iodata(children), "</", name, ">"]
  end

  defp node_to_iodata({:self_close, :tag, name, attrs, %{closing: :void}}) do
    ["<", name, attrs_to_iodata(attrs), ">"]
  end

  defp node_to_iodata({:self_close, :tag, name, attrs, _meta}) do
    ["<", name, attrs_to_iodata(attrs), " />"]
  end

  defp node_to_iodata(node) do
    raise ArgumentError, "only plain MJML can be serialized, got: #{inspect(node)}"
  end

  defp attrs_to_iodata(attrs) do
    for {name, value, _meta} <- attrs, name not in Tags.mjml_eex_attributes() do
      case value do
        nil -> [" ", name]
        {:string, string, %{delimiter: delimiter}} -> [" ", name, "=", delimiter, string, delimiter]
        other -> raise ArgumentError, "only plain MJML can be serialized, got attribute: #{inspect({name, other})}"
      end
    end
  end
end
