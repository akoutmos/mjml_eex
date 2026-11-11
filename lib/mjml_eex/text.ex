defmodule MjmlEEx.Text do
  @moduledoc false

  # Converts rendered MJML to plain text, for the text part of a multipart email (see
  # MjmlEEx.to_text/1). It works from the MJML rather than from the HTML that MJML compiles to,
  # so it follows the email's content instead of its layout tables:
  #
  #   * mj-head is left out, and so are HTML comments and elements with display:none.
  #   * The HTML in mj-text and mj-raw becomes paragraphs, with lists, quotes, preformatted
  #     text and tables. Links are written as "text (url)".
  #   * Buttons and linked images are written as "label: url", and social and navbar links one
  #     per line.
  #   * Dividers are written as "---". Other images and spacers are left out.
  #
  # Paragraphs are separated by a blank line.

  alias MjmlEEx.ParseError
  alias MjmlEEx.Spec.Generated
  alias MjmlEEx.TagEngine.Parser
  alias MjmlEEx.Text.Entities

  # Components whose content is HTML (or text)
  @ending_tags for {name, %{ending_tag: true}} <- Generated.components(), do: name

  @doc false
  @spec convert(String.t()) :: String.t()
  def convert(mjml) when is_binary(mjml) do
    # The content of ending tags is parsed on its own (see content/1)
    nodes = Parser.parse!(mjml, file: "nofile", interpolation: false, raw_text_tags: @ending_tags)

    case nodes |> blocks() |> join_blocks("\n\n") do
      "" -> ""
      text -> text <> "\n"
    end
  end

  ## MJML

  # The text of MJML nodes, as a list of blocks (paragraphs)
  defp blocks(nodes), do: Enum.flat_map(nodes, &block/1)

  defp block({:block, :tag, name, attrs, children, _meta, _close}) when name in @ending_tags,
    do: component(name, attrs, content(children))

  defp block({:block, :tag, name, attrs, children, _meta, _close}), do: component(name, attrs, children)
  defp block({:self_close, :tag, name, attrs, _meta}), do: component(name, attrs, [])
  defp block(_text), do: []

  defp component(name, _attrs, _children) when name in ~w(mj-head mj-include), do: []
  defp component(name, _attrs, children) when name in ~w(mj-text mj-raw mj-accordion-text), do: html_blocks(children)
  defp component("mj-accordion-title", _attrs, children), do: [inline_text(children)]
  defp component("mj-button", attrs, children), do: [link_line(inline_text(children), href(attrs))]
  defp component("mj-divider", _attrs, _children), do: ["---"]
  defp component("mj-table", _attrs, children), do: [table(children)]

  defp component(name, attrs, _children) when name in ~w(mj-image mj-carousel-image) do
    case href(attrs) do
      nil -> []
      href -> [link_line(attr(attrs, "alt") || "", href)]
    end
  end

  # One line per link
  defp component(name, _attrs, children) when name in ~w(mj-social mj-navbar), do: [join_blocks(blocks(children), "\n")]
  defp component("mj-navbar-link", attrs, children), do: [link_line(inline_text(children), href(attrs))]

  defp component("mj-social-element", attrs, children) do
    label =
      case inline_text(children) do
        "" -> network_name(attr(attrs, "alt") || attr(attrs, "name") || "")
        label -> label
      end

    [link_line(label, href(attrs))]
  end

  defp component(_name, _attrs, children), do: blocks(children)

  # The HTML content of an ending tag, such as mj-text, parsed on its own. MJML accepts HTML
  # that the parser doesn't, such as an unclosed <p> inserted with raw/1, or one half of a
  # wrapper <div> in an mj-raw. That content keeps its text without its structure, rather than
  # failing the whole email.
  defp content(children) do
    html = for {:text, text, _meta} <- children, into: "", do: text

    try do
      Parser.parse!(html, interpolation: false)
    rescue
      ParseError ->
        text =
          html
          |> strip_comments()
          |> String.replace(~r{<(script|style)\b.*?</\1\s*>}is, " ")
          |> String.replace(~r/<[^>]*>/, " ")

        [{:text, text, %{}}]
    end
  end

  @networks %{
    "dribbble" => "Dribbble",
    "facebook" => "Facebook",
    "github" => "GitHub",
    "google" => "Google",
    "instagram" => "Instagram",
    "linkedin" => "LinkedIn",
    "medium" => "Medium",
    "pinterest" => "Pinterest",
    "snapchat" => "Snapchat",
    "soundcloud" => "SoundCloud",
    "tumblr" => "Tumblr",
    "twitter" => "Twitter",
    "vimeo" => "Vimeo",
    "web" => "Website",
    "x" => "X",
    "xing" => "XING",
    "youtube" => "YouTube"
  }

  defp network_name(name) do
    name = String.replace_suffix(name, "-noshare", "")
    Map.get(@networks, name, name)
  end

  defp link_line(label, nil), do: label
  defp link_line("", href), do: href
  defp link_line(label, href) when label == href, do: label
  defp link_line(label, href), do: "#{label}: #{href}"

  ## HTML

  @skipped ~w(head title script style template)

  @blocks ~w(address article aside blockquote center dd details div dl dt fieldset figcaption figure footer form
             h1 h2 h3 h4 h5 h6 header hr li main nav ol p pre section summary table tbody td tfoot th thead tr ul)

  # HTML nodes as a list of blocks: inline content between block elements makes a paragraph
  defp html_blocks(nodes) do
    {blocks, inline} =
      Enum.reduce(nodes, {[], []}, fn node, {blocks, inline} ->
        if block_element?(node) do
          {Enum.reverse(html_block(node), [paragraph(Enum.reverse(inline)) | blocks]), []}
        else
          {blocks, [inline_node(node) | inline]}
        end
      end)

    [paragraph(Enum.reverse(inline)) | blocks] |> Enum.reverse() |> Enum.reject(&(&1 == ""))
  end

  defp block_element?({_kind, :tag, name, _attrs, _meta} = node), do: name in @blocks and not hidden?(node)

  defp block_element?({_kind, :tag, name, _attrs, _children, _meta, _close} = node),
    do: name in @blocks and not hidden?(node)

  defp block_element?(_node), do: false

  defp html_block({:self_close, :tag, "hr", _attrs, _meta}), do: ["---"]
  defp html_block({:self_close, :tag, _name, _attrs, _meta}), do: []
  defp html_block({:block, :tag, "ul", _attrs, children, _meta, _close}), do: [list(children, fn _index -> "- " end)]
  defp html_block({:block, :tag, "ol", _attrs, children, _meta, _close}), do: [list(children, &"#{&1}. ")]
  defp html_block({:block, :tag, "blockquote", _attrs, children, _meta, _close}), do: [quote_block(children)]
  defp html_block({:block, :tag, "pre", _attrs, children, _meta, _close}), do: [preformatted(children)]
  defp html_block({:block, :tag, "table", _attrs, children, _meta, _close}), do: [table(children)]
  defp html_block({:block, :tag, _name, _attrs, children, _meta, _close}), do: html_blocks(children)

  # Inline content as a string. Whitespace in text becomes single spaces, and <br> a newline,
  # so that paragraph/1 can collapse the spaces line by line.
  defp inline(nodes), do: nodes |> Enum.map(&inline_node/1) |> IO.iodata_to_binary()

  defp inline_node({:text, text, _meta}) do
    text |> strip_comments() |> String.replace(~r/\s+/u, " ") |> decode()
  end

  defp inline_node({_kind, :tag, name, _attrs, _meta}) when name in @skipped, do: ""
  defp inline_node({_kind, :tag, name, _attrs, _children, _meta, _close}) when name in @skipped, do: ""
  defp inline_node({:self_close, :tag, "br", _attrs, _meta}), do: "\n"

  defp inline_node({:block, :tag, "a", attrs, children, _meta, _close} = node) do
    if hidden?(node) do
      ""
    else
      text =
        case children |> inline() |> paragraph() |> String.replace("\n", " ") do
          "" -> image_alts(children)
          text -> text
        end

      case {text, href(attrs)} do
        {text, nil} -> text
        {"", href} -> href
        {text, href} -> if text == href or "mailto:" <> text == href, do: text, else: "#{text} (#{href})"
      end
    end
  end

  defp inline_node({:block, :tag, name, _attrs, children, _meta, _close} = node) do
    cond do
      hidden?(node) -> ""
      # Block content inside inline content, such as a <div> in an <a>
      name in @blocks -> [" ", inline(children), " "]
      true -> inline(children)
    end
  end

  defp inline_node(_node), do: ""

  defp image_alts(nodes) do
    nodes
    |> Enum.flat_map(fn
      {:self_close, :tag, "img", attrs, _meta} -> [attr(attrs, "alt") || ""]
      {:block, :tag, _name, _attrs, children, _meta, _close} -> [image_alts(children)]
      _node -> []
    end)
    |> Enum.join(" ")
    |> String.trim()
  end

  # Collapses the spaces in each line of inline content, and drops blank lines at the start and end
  defp paragraph(inline) do
    inline
    |> IO.iodata_to_binary()
    |> String.split("\n")
    |> Enum.map(&(&1 |> String.replace(~r/[ \t]+/, " ") |> String.trim()))
    |> Enum.drop_while(&(&1 == ""))
    |> Enum.reverse()
    |> Enum.drop_while(&(&1 == ""))
    |> Enum.reverse()
    |> Enum.join("\n")
  end

  defp inline_text(nodes), do: nodes |> inline() |> paragraph() |> String.replace("\n", " ")

  defp list(children, marker) do
    children
    |> Enum.filter(&match?({:block, :tag, "li", _attrs, _children, _meta, _close}, &1))
    |> Enum.reject(&hidden?/1)
    |> Enum.with_index(1)
    |> Enum.map_join("\n", fn {{:block, :tag, "li", _attrs, item, _meta, _close}, index} ->
      marker = marker.(index)
      indent = String.duplicate(" ", String.length(marker))
      [first | rest] = item |> html_blocks() |> join_blocks("\n") |> String.split("\n")
      Enum.join([marker <> first | Enum.map(rest, &if(&1 == "", do: "", else: indent <> &1))], "\n")
    end)
  end

  defp quote_block(children) do
    children
    |> html_blocks()
    |> join_blocks("\n\n")
    |> String.split("\n")
    |> Enum.map_join("\n", &String.trim_trailing("> " <> &1))
  end

  defp preformatted(children) do
    children |> Enum.map(&preformatted_node/1) |> IO.iodata_to_binary() |> String.trim("\n")
  end

  defp preformatted_node({:text, text, _meta}), do: text |> strip_comments() |> decode()
  defp preformatted_node({:self_close, :tag, "br", _attrs, _meta}), do: "\n"

  defp preformatted_node({:block, :tag, _name, _attrs, children, _meta, _close}),
    do: Enum.map(children, &preformatted_node/1)

  defp preformatted_node(_node), do: ""

  # Rows of cells, with the columns padded to line up. A cell with several lines, such as an
  # address, keeps them in its column. Columns that are empty in every row, such as spacers,
  # are left out.
  #
  #   Billed to  Jane Cooper
  #              Globex Corporation
  #
  #   Due        October 31, 2026
  defp table(children) do
    rows =
      children
      |> rows()
      |> Enum.map(fn cells -> Enum.map(cells, &(&1 |> html_blocks() |> join_blocks("\n") |> String.split("\n"))) end)
      |> Enum.reject(fn cells -> Enum.all?(cells, &(&1 == [""])) end)

    columns = rows |> Enum.map(&length/1) |> Enum.max(fn -> 0 end)
    rows = Enum.map(rows, &(&1 ++ List.duplicate([""], columns - length(&1))))

    {rows, widths} =
      rows
      |> Enum.zip_with(& &1)
      |> Enum.reject(fn column -> Enum.all?(column, &(&1 == [""])) end)
      |> then(fn columns ->
        {Enum.zip_with(columns, & &1),
         Enum.map(columns, fn column -> column |> List.flatten() |> Enum.map(&String.length/1) |> Enum.max() end)}
      end)

    # Rows with several lines are separated by a blank line, so they don't run together
    multiline? = Enum.any?(rows, fn cells -> Enum.any?(cells, &(length(&1) > 1)) end)

    Enum.map_join(rows, if(multiline?, do: "\n\n", else: "\n"), fn cells ->
      height = cells |> Enum.map(&length/1) |> Enum.max()

      Enum.map_join(0..(height - 1), "\n", fn line ->
        cells
        |> Enum.zip(widths)
        |> Enum.map_join("  ", fn {lines, width} -> String.pad_trailing(Enum.at(lines, line, ""), width) end)
        |> String.trim_trailing()
      end)
    end)
  end

  # The cells of each row of a table, through thead, tbody and tfoot
  defp rows(nodes) do
    Enum.flat_map(nodes, fn
      {:block, :tag, "tr", _attrs, cells, _meta, _close} = row ->
        if hidden?(row),
          do: [],
          else: [
            for(
              {:block, :tag, name, _, children, _, _} = cell <- cells,
              name in ~w(td th),
              not hidden?(cell),
              do: children
            )
          ]

      {:block, :tag, name, _attrs, children, _meta, _close} when name in ~w(thead tbody tfoot) ->
        rows(children)

      _node ->
        []
    end)
  end

  defp join_blocks(blocks, separator), do: blocks |> Enum.reject(&(&1 == "")) |> Enum.join(separator)

  ## Attributes, comments and entities

  defp hidden?({_kind, :tag, _name, attrs, _meta}), do: hidden_style?(attrs)
  defp hidden?({_kind, :tag, _name, attrs, _children, _meta, _close}), do: hidden_style?(attrs)

  defp hidden_style?(attrs), do: (attr(attrs, "style") || "") =~ ~r/display\s*:\s*none/i

  defp attr(attrs, name) do
    Enum.find_value(attrs, fn
      {^name, {:string, value, _meta}, _attr_meta} -> decode(value)
      {^name, nil, _attr_meta} -> ""
      _attr -> nil
    end)
  end

  # Links that go nowhere, such as "#", are left out
  defp href(attrs) do
    case attrs |> attr("href") |> Kernel.||("") |> String.trim() do
      "" -> nil
      "#" <> _fragment -> nil
      href -> href
    end
  end

  # Comments, including Outlook's conditional comments (<!--[if mso]>...<![endif]-->), are
  # left out. The content of <!--[if !mso]><!-->...<!--<![endif]--> is kept, as other email
  # clients show it.
  defp strip_comments(text), do: String.replace(text, ~r/<!--.*?-->/s, "")

  defp decode(text) do
    if String.contains?(text, "&") do
      Regex.replace(~r/&(?:#(\d+)|#[xX]([0-9a-fA-F]+)|([a-zA-Z][a-zA-Z0-9]*));/, text, fn
        entity, decimal, "", "" ->
          codepoint(String.to_integer(decimal), entity)

        entity, "", hex, "" ->
          codepoint(String.to_integer(hex, 16), entity)

        entity, "", "", name ->
          case Entities.character(name) do
            nil -> entity
            <<codepoint::utf8>> -> codepoint(codepoint, entity)
            characters -> characters
          end
      end)
    else
      text
    end
  end

  # Whitespace and non-breaking spaces become spaces. Invisible characters, such as the ones
  # used to pad preview text, and control characters are left out.
  @controls Enum.to_list(0..8) ++ [11, 12] ++ Enum.to_list(14..31) ++ Enum.to_list(127..159)

  defp codepoint(codepoint, _entity) when codepoint in [9, 10, 13, 160], do: " "
  defp codepoint(codepoint, _entity) when codepoint in [173, 847, 8203, 8204, 8205, 8288, 65_279], do: ""
  defp codepoint(codepoint, _entity) when codepoint in @controls, do: ""

  defp codepoint(codepoint, _entity) when codepoint in 0..0x10FFFF and codepoint not in 0xD800..0xDFFF,
    do: <<codepoint::utf8>>

  defp codepoint(_codepoint, entity), do: entity
end
