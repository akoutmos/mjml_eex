defmodule MjmlEEx.TemplatesTest do
  # Themes set with Theme.put/1 are per process
  use ExUnit.Case, async: true

  alias MjmlEEx.Templates.{
    FlashSale,
    ForgotPassword,
    Invoice,
    MagicLink,
    Newsletter,
    OneTimePassword,
    OrderConfirmation,
    PaymentFailed,
    ProductLaunch,
    SecurityAlert,
    TeamInvitation,
    TrialConversion,
    VerifyEmail,
    Webinar,
    Welcome
  }

  alias MjmlEEx.Theme

  @url "https://acme.com/x"
  @brand %{
    product_name: "Acme",
    logo: "https://acme.com/logo.png",
    product_url: "https://acme.com",
    address: "Acme Inc., 1 Market St, San Francisco"
  }
  @social [x: "https://x.com/acme", github: "https://github.com/acme"]

  # The required assigns of each template
  @required %{
    ForgotPassword => %{product_name: "Acme", reset_url: @url},
    OneTimePassword => %{product_name: "Acme", code: "482913"},
    VerifyEmail => %{product_name: "Acme", verify_url: @url},
    TrialConversion => %{product_name: "Acme", trial_ends: "October 15", upgrade_url: @url},
    Invoice => %{
      product_name: "Acme",
      invoice_number: "INV-42",
      amount_due: "$108.00",
      due_date: "October 31, 2026",
      items: [%{description: "Pro plan", amount: "$100.00"}]
    },
    Webinar => %{
      product_name: "Acme",
      title: "Ship faster with Acme",
      date: "Thursday, November 6, 2026",
      time: "10:00 AM PT",
      description: "A live walkthrough.",
      register_url: @url,
      unsubscribe_url: @url
    },
    Newsletter => %{product_name: "Acme", title: "The Acme Dispatch", unsubscribe_url: @url},
    ProductLaunch => %{
      product_name: "Acme",
      headline: "Introducing Insights",
      description: "Dashboards that build themselves.",
      cta_url: @url,
      unsubscribe_url: @url
    },
    FlashSale => %{product_name: "Acme", headline: "40% off everything", shop_url: @url, unsubscribe_url: @url},
    MagicLink => %{product_name: "Acme", sign_in_url: @url},
    Welcome => %{product_name: "Acme", cta_url: @url},
    TeamInvitation => %{product_name: "Acme", inviter_name: "Maya Patel", team_name: "Globex", accept_url: @url},
    PaymentFailed => %{product_name: "Acme", amount: "$120.00", update_url: @url},
    SecurityAlert => %{product_name: "Acme", secure_url: @url},
    OrderConfirmation => %{
      product_name: "Acme",
      order_number: "#1042",
      items: [%{name: "Mug", price: "$38.00"}],
      total: "$38.00"
    }
  }

  @story %{label: "Guides", title: "Automate five reports", summary: "Ten minutes each.", image: @url, url: @url}

  # Every other assign of each template
  @optional %{
    ForgotPassword => Map.merge(@brand, %{name: "Jane", expires_in: "2 hours", support_url: @url}),
    OneTimePassword =>
      Map.merge(@brand, %{
        expires_in: "5 minutes",
        device: "Chrome on macOS",
        location: "Lisbon, Portugal",
        requested_at: "October 12, 2026 at 9:41 AM",
        support_url: @url
      }),
    VerifyEmail =>
      Map.merge(@brand, %{name: "Jane", email: "jane@example.com", expires_in: "2 days", support_url: @url}),
    TrialConversion =>
      Map.merge(@brand, %{
        days_left: 3,
        name: "Jane",
        plan: "Business",
        price: "$24 per user, per month",
        usage: [%{value: "12", label: "Projects"}, %{value: "5", label: "Teammates"}],
        features: ["Unlimited projects", "SSO"],
        contact_url: @url,
        support_url: @url,
        unsubscribe_url: @url
      }),
    Invoice =>
      Map.merge(@brand, %{
        items: [
          %{description: "Pro plan", detail: "Oct 1 – Oct 31", quantity: 10, amount: "$100.00"},
          %{description: "Storage", quantity: 1, amount: "$8.00"}
        ],
        totals: [{"Subtotal", "$100.00"}, {"Tax", "$8.00"}],
        issued_on: "October 1, 2026",
        billed_to: ["Jane Cooper", "Globex Corporation"],
        pay_url: @url,
        pdf_url: @url,
        support_url: @url
      }),
    Webinar =>
      Map.merge(@brand, %{
        duration: "45 minutes",
        label: "Live demo",
        topics: ["Automate reports", "Hand off work"],
        speakers: [%{name: "Maya Patel", role: "Head of Product"}, %{name: "Tom Okafor", photo: @url}],
        recording: true,
        name: "Jane",
        preview: "Save your seat",
        social: @social
      }),
    Newsletter =>
      Map.merge(@brand, %{
        issue: "Issue 42",
        intro: "Here's what's new.",
        sign_off: "Maya",
        featured: %{@story | title: "Inside the redesign"},
        stories: [@story, Map.drop(@story, [:image, :label])],
        links: [%{title: "Release notes", url: @url, source: "Changelog"}, %{title: "Careers", url: @url}],
        preview: "This month at Acme",
        social: @social
      }),
    ProductLaunch =>
      Map.merge(@brand, %{
        cta_label: "Get started",
        label: "Beta",
        image: @url,
        image_alt: "The Insights dashboard",
        features: [
          %{title: "Live", description: "Updates as work happens."},
          %{title: "Alerts", description: "Hear about changes."},
          %{title: "Reports", description: "Share a link."}
        ],
        features_title: "Highlights",
        quote: %{text: "It replaced three tools.", author: "Sam Lee", role: "COO, Globex"},
        learn_more_url: @url,
        preview: "Meet Insights",
        social: @social
      }),
    FlashSale =>
      Map.merge(@brand, %{
        description: "Two days only.",
        label: "Weekend sale",
        code: "FLASH40",
        ends: "Ends Sunday at midnight",
        cta_label: "Shop now",
        background_image: "https://acme.com/sale.png",
        products: [
          %{name: "Mug", price: "$32", sale_price: "$19", image: @url, url: @url},
          %{name: "Vase", price: "$68", image: @url, url: @url},
          %{name: "Bowl", price: "$54", sale_price: "$32", image: @url, url: @url}
        ],
        products_title: "Best sellers",
        terms: "While supplies last.",
        preview: "40% off ends tonight",
        social: @social
      }),
    MagicLink =>
      Map.merge(@brand, %{
        email: "jane@example.com",
        expires_in: "10 minutes",
        device: "Safari on iPhone",
        location: "Toronto, Canada",
        requested_at: "October 12, 2026 at 9:41 AM",
        support_url: @url
      }),
    Welcome =>
      Map.merge(@brand, %{
        name: "Jane",
        intro: "Let's get you set up.",
        cta_label: "Go to your dashboard",
        steps: [
          %{title: "Create a project", description: "Projects hold your work.", url: @url, action: "Create one"},
          %{title: "Invite your team", description: "Plan together."}
        ],
        docs_url: @url,
        support_url: @url,
        sign_off: "Maya, CEO of Acme"
      }),
    TeamInvitation =>
      Map.merge(@brand, %{
        inviter_photo: "https://acme.com/maya.png",
        message: "Join us!",
        role: "Editor",
        expires_in: "3 days",
        support_url: @url
      }),
    PaymentFailed =>
      Map.merge(@brand, %{
        name: "Jane",
        payment_method: "Visa ending in 4242",
        plan: "Pro",
        reason: "Your card was declined.",
        retry_on: "October 15",
        pay_by: "October 22",
        invoice_url: @url,
        support_url: @url
      }),
    SecurityAlert =>
      Map.merge(@brand, %{
        event: :password_changed,
        name: "Jane",
        device: "Firefox on Windows",
        location: "Berlin, Germany",
        ip_address: "203.0.113.42",
        occurred_at: "October 12, 2026 at 9:41 AM",
        support_url: @url
      }),
    OrderConfirmation =>
      Map.merge(@brand, %{
        items: [
          %{name: "Mug", detail: "Rust", quantity: 2, price: "$38.00", image: "https://acme.com/mug.png"},
          %{name: "Vase", price: "$68.00"}
        ],
        totals: [{"Subtotal", "$106.00"}, {"Shipping", "Free"}],
        name: "Jane",
        order_url: @url,
        delivery_estimate: "October 18 – 20",
        shipping_address: ["Jane Cooper", "100 Main St"],
        payment_method: "Visa ending in 4242",
        support_url: @url
      })
  }

  @templates Map.keys(@required)

  defp all_assigns(template), do: Map.merge(@required[template], @optional[template])

  # Renders the template, checks its MJML is valid and compiles to HTML, and returns the MJML
  defp render(template, assigns) do
    mjml = assigns |> template.render() |> to_string()
    assert :ok = MjmlEEx.validate(mjml)
    assert template.to_html(assigns) =~ "</html>"
    mjml
  end

  defp render(template), do: render(template, all_assigns(template))

  describe "every template" do
    test "renders valid MJML with every assign, and with only the required ones" do
      for template <- @templates do
        assert render(template) =~ "<mjml>"
        assert render(template, @required[template]) =~ "<mjml>"
      end
    end

    test "requires its required assigns" do
      for template <- @templates, name <- Map.keys(@required[template]) do
        assert_raise ArgumentError, ~r/missing required attr #{inspect(name)}/, fn ->
          template.to_html(Map.delete(@required[template], name))
        end
      end
    end

    test "renders the example in its documentation" do
      for template <- @templates do
        {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(template)
        [_, example] = Regex.run(~r/```elixir\n(.*?)```/s, moduledoc)
        {html, _binding} = Code.eval_string(example)

        assert html =~ "</html>", "the example of #{inspect(template)} didn't render"
      end
    end

    test "is styled with the theme" do
      colors = [
        primary: "#0F766E",
        primary_text: "#F0FDFA",
        background: "#E7E5E4",
        surface: "#FFFDF7",
        subtle: "#F5F5F4",
        text: "#44403C",
        heading: "#1C1917",
        muted: "#78716C",
        border: "#D6D3D1",
        info: "#0369A1",
        info_background: "#E0F2FE",
        success: "#047857",
        success_background: "#ECFDF5",
        warning: "#A16207",
        warning_background: "#FEF9C3",
        danger: "#BE123C",
        danger_background: "#FFE4E6"
      ]

      Theme.put([heading_font_family: "Georgia, serif", radius: "2px"] ++ colors)
      default = %Theme{}

      for template <- @templates do
        mjml = render(template)
        assert mjml =~ "#0F766E"
        assert mjml =~ "Georgia, serif"
        assert mjml =~ ~s(border-radius="2px")

        # Every color comes from the theme: none of the default theme's are left
        for {token, _color} <- colors, default_color = Map.fetch!(default, token) do
          refute mjml =~ default_color, "#{inspect(template)} has the default #{token} color"
        end
      end
    end

    test "escapes the assigns" do
      for template <- @templates do
        assigns = Map.put(all_assigns(template), :product_name, "<b>Acme</b>")
        mjml = render(template, assigns)

        refute mjml =~ "<b>Acme</b>"
        assert mjml =~ "&lt;b&gt;Acme&lt;/b&gt;"
      end
    end
  end

  # A new template needs all of these, so they're checked here
  describe "the templates" do
    test "are all tested, documented and screenshotted" do
      {:ok, modules} = :application.get_key(:mjml_eex, :modules)
      templates = Enum.filter(modules, &match?(["MjmlEEx", "Templates", _], Module.split(&1)))

      assert Enum.sort(templates) == Enum.sort(@templates),
             "add the new templates to @required and @optional in this file"

      {%{templates: examples}, _binding} = Code.eval_file("screenshots/examples.exs")

      assert Enum.sort(Enum.map(examples, & &1.module)) == Enum.sort(templates),
             "add the new templates to screenshots/examples.exs"

      assert Enum.sort(Mix.Project.config()[:docs][:groups_for_modules][:"Prebuilt templates"]) ==
               Enum.sort(templates),
             "add the new templates to the Prebuilt templates group in mix.exs"

      guide = File.read!("guides/prebuilt_templates.md")

      for template <- templates do
        image = "images/templates/#{template |> Module.split() |> List.last() |> Macro.underscore()}.jpg"
        {:docs_v1, _, _, _, %{"en" => moduledoc}, _, _} = Code.fetch_docs(template)

        assert File.exists?(Path.join("guides", image)), "run mix mjml_eex.gen.screenshots for #{image}"
        assert moduledoc =~ image, "show #{image} in the documentation of #{inspect(template)}"
        assert guide =~ "`#{inspect(template)}` |", "add #{inspect(template)} to guides/prebuilt_templates.md"
        assert guide =~ "(#{image})", "link #{image} in guides/prebuilt_templates.md"
      end
    end

    test "render their examples for the screenshots" do
      {%{templates: examples}, _binding} = Code.eval_file("screenshots/examples.exs")

      for %{module: module, assigns: assigns} <- examples do
        render(module, Map.new(assigns))
      end
    end
  end

  describe "ForgotPassword" do
    test "links to the reset URL and greets the user" do
      mjml = render(ForgotPassword)

      assert mjml =~ ~s(<mj-button href="#{@url}")
      assert mjml =~ ~s(<span style="word-break: break-all;">#{@url}</span>)
      assert mjml =~ "Hi Jane,"
      assert mjml =~ "This link expires in 2 hours."
      assert mjml =~ "Help center</a>"
    end

    test "leaves out the greeting and the footer when their assigns aren't given" do
      mjml = render(ForgotPassword, @required[ForgotPassword])

      refute mjml =~ "Hi "
      assert mjml =~ "This link expires in 1 hour."
      refute mjml =~ "Help center"
    end
  end

  describe "OneTimePassword" do
    test "shows the code in the preview and the body" do
      mjml = render(OneTimePassword)

      assert mjml =~ "<mj-preview>Your verification code is 482913. It expires in 5 minutes.</mj-preview>"
      assert mjml =~ ">482913</td>"
    end

    test "lists the request's details that are given" do
      mjml = render(OneTimePassword, Map.put(@required[OneTimePassword], :device, "Chrome on macOS"))

      assert mjml =~ "This code was requested from:"
      assert mjml =~ ">Device</td>"
      refute mjml =~ ">Location</td>"

      refute render(OneTimePassword, @required[OneTimePassword]) =~ "This code was requested from:"
    end
  end

  describe "VerifyEmail" do
    test "welcomes the user and shows their address" do
      mjml = render(VerifyEmail)
      assert mjml =~ "Welcome, Jane!"
      assert mjml =~ "<strong>jane@example.com</strong>"

      mjml = render(VerifyEmail, @required[VerifyEmail])
      assert mjml =~ "Welcome to Acme!"
      assert mjml =~ "Click the button below to confirm your email address."
    end
  end

  describe "TrialConversion" do
    test "shows the days left, the usage, the features and the price" do
      mjml = render(TrialConversion)

      assert mjml =~ "3 days left in your trial"
      assert mjml =~ "Your trial so far"
      assert mjml =~ "Teammates</div>"
      assert mjml =~ "Everything in Business"
      assert mjml =~ ~s(<td style="padding:4px 0;vertical-align:top;">SSO</td>)
      assert mjml =~ "<strong>Business</strong> is $24 per user, per month."
      assert mjml =~ "Upgrade to Business</mj-button>"

      assert render(TrialConversion, Map.put(@required[TrialConversion], :days_left, 1)) =~ "1 day left in your trial"
    end

    test "leaves out the sections whose assigns aren't given" do
      mjml = render(TrialConversion, @required[TrialConversion])

      refute mjml =~ "left in your trial"
      refute mjml =~ "Your trial so far"
      refute mjml =~ "Everything in"
      refute mjml =~ "Talk to our team"
      assert mjml =~ "Upgrade to Pro</mj-button>"
    end
  end

  describe "Invoice" do
    test "shows the amount due, the details, the items and the totals" do
      mjml = render(Invoice)

      assert mjml =~ "$108.00</h1>"
      assert mjml =~ "Pay this invoice</mj-button>"
      assert mjml =~ "Download the invoice (PDF)</a>"
      assert mjml =~ ~r/Jane Cooper\s*<br>Globex Corporation/
      assert mjml =~ ~r/>\s*Qty\s*<\/th>/
      assert mjml =~ "Oct 1 – Oct 31</div>"
      assert mjml =~ ~r/>Subtotal<.*>Tax<.*>Amount due</s
    end

    test "leaves out the quantities when no item has one" do
      mjml = render(Invoice, @required[Invoice])

      refute mjml =~ "Qty"
      refute mjml =~ "Pay this invoice"
      refute mjml =~ "Billed to"
    end
  end

  describe "Webinar" do
    test "shows the speakers with their photo or initials" do
      mjml = render(Webinar)

      assert mjml =~ ">MP</span>"
      assert mjml =~ ~s(<img src="#{@url}" alt="Tom Okafor")
      assert mjml =~ "Speakers</h3>"
      assert mjml =~ "Head of Product"
      assert mjml =~ "we'll send you the recording"
      assert mjml =~ ~s(<mj-social-element name="github")

      one = Map.put(@required[Webinar], :speakers, [%{name: "Maya"}])
      assert render(Webinar, one) =~ "Speaker</h3>"
    end

    test "numbers the topics" do
      assert render(Webinar) =~ ~r/>1<\/div>.*Automate reports.*>2<\/div>.*Hand off work/s
    end
  end

  describe "Newsletter" do
    test "shows stories with a thumbnail next to their text, and stories without one on their own" do
      mjml = render(Newsletter)

      assert mjml =~ "Inside the redesign"
      assert mjml =~ ~r/<mj-group>\s*<mj-column width="36%"/
      assert length(String.split(mjml, "<mj-group>")) == 2
      assert mjml =~ "Changelog"
      assert mjml =~ "You're receiving this because you subscribed to The Acme Dispatch."
    end

    test "uses the featured story's title as the preview" do
      assigns = Map.delete(all_assigns(Newsletter), :preview)
      assert render(Newsletter, assigns) =~ "<mj-preview>Inside the redesign</mj-preview>"
      refute render(Newsletter, @required[Newsletter]) =~ "mj-preview"
    end
  end

  describe "ProductLaunch" do
    test "shows three features a row when there are three, and two otherwise" do
      mjml = render(ProductLaunch)
      assert mjml =~ ~s(<mj-column vertical-align="top">)
      assert mjml =~ "Highlights</h2>"
      assert mjml =~ "&ldquo;It replaced three tools.&rdquo;"
      assert mjml =~ ~s(alt="The Insights dashboard")

      features = for n <- 1..4, do: %{title: "Feature #{n}", description: "Feature #{n}."}
      mjml = render(ProductLaunch, Map.put(@required[ProductLaunch], :features, features))
      assert length(String.split(mjml, ~s(<mj-column width="50%" vertical-align="top">))) == 5
    end
  end

  describe "FlashSale" do
    test "shows the hero's background image, the code and the products" do
      mjml = render(FlashSale)

      assert mjml =~ ~s(background-url="https://acme.com/sale.png")
      assert mjml =~ "FLASH40</strong>"
      assert mjml =~ ~r/<s style="[^"]*">\$32<\/s>.*\$19<\/strong>/s
      assert mjml =~ "$68"
      assert mjml =~ "While supplies last."
      assert length(String.split(mjml, "<mj-group>")) == 3
    end

    test "previews the headline and when the sale ends" do
      assigns = Map.delete(all_assigns(FlashSale), :preview)
      assert render(FlashSale, assigns) =~ "<mj-preview>40% off everything. Ends Sunday at midnight</mj-preview>"

      mjml = render(FlashSale, @required[FlashSale])
      assert mjml =~ "<mj-preview>40% off everything</mj-preview>"
      refute mjml =~ "background-url"
      refute mjml =~ "See everything on sale"
    end
  end

  describe "MagicLink" do
    test "links to the sign-in URL and lists where the link was requested from" do
      mjml = render(MagicLink)

      assert mjml =~ ~s(<mj-button href="#{@url}")
      assert mjml =~ "sign in as <strong>jane@example.com</strong>. This link expires in 10 minutes."
      assert mjml =~ ">Device</td>"
      assert mjml =~ ~s(<span style="word-break: break-all;">#{@url}</span>)

      mjml = render(MagicLink, @required[MagicLink])
      assert mjml =~ "Click the button below to sign in. This link expires in 15 minutes."
      refute mjml =~ "This link was requested from:"
    end
  end

  describe "Welcome" do
    test "greets the user on a hero and lists the first steps" do
      mjml = render(Welcome)

      assert mjml =~ ~s(<mj-section background-color="#4F46E5")
      assert mjml =~ ~r/Welcome to Acme, Jane!\s*<\/h1>/
      assert mjml =~ "Go to your dashboard</mj-button>"
      assert mjml =~ ~r/Create a project<\/div>.*Projects hold your work.*Create one &rarr;<\/a>/s
      assert mjml =~ "Invite your team</div>"
      assert mjml =~ "the guides</a>, or"
      assert mjml =~ "Welcome aboard,<br>Maya, CEO of Acme"
    end

    test "leaves out what isn't given" do
      mjml = render(Welcome, @required[Welcome])

      assert mjml =~ ~r/Welcome to Acme!\s*<\/h1>/
      assert mjml =~ "everything you need to get started."
      refute mjml =~ "Your first steps"
      refute mjml =~ "Need a hand?"
      # Only the hero, without an empty card under it
      refute mjml =~ ~s(<mj-column background-color="#FFFFFF")

      assert render(Welcome, Map.put(@required[Welcome], :docs_url, @url)) =~ "Need a hand? Read <a"
      assert render(Welcome, Map.put(@required[Welcome], :support_url, @url)) =~ "Contact our team</a>."
    end
  end

  describe "TeamInvitation" do
    test "shows who sent it, with their note" do
      mjml = render(TeamInvitation)

      assert mjml =~ ~s(<img src="https://acme.com/maya.png" alt="Maya Patel" width="64" height="64")
      assert mjml =~ ~r/Maya Patel invited you to join Globex on Acme\s*<\/h1>/
      assert mjml =~ "You'll join as <strong>Editor</strong>."
      assert mjml =~ "&ldquo;Join us!&rdquo;"
      assert mjml =~ "This invitation expires in 3 days."

      mjml = render(TeamInvitation, @required[TeamInvitation])
      assert mjml =~ ">MP</span>"
      refute mjml =~ "&ldquo;"
    end
  end

  describe "PaymentFailed" do
    test "says what couldn't be charged, and when to update the payment details by" do
      mjml = render(PaymentFailed)

      assert mjml =~
               ~r/We tried to charge \$120.00 <span>to your Visa ending in 4242<\/span> for your\s+Acme Pro subscription/

      assert mjml =~ ">Your card was declined.</td>"
      assert mjml =~ ">Next attempt</td>"
      assert mjml =~ "Please update your payment details by October 22"
      assert mjml =~ "View the invoice</a>"

      mjml = render(PaymentFailed, @required[PaymentFailed])
      assert mjml =~ ~r/for your\s+Acme subscription/
      refute mjml =~ "Please update"
    end
  end

  describe "SecurityAlert" do
    test "describes each event" do
      for {event, title} <- [
            new_sign_in: "New sign-in to your account",
            password_changed: "Your password was changed",
            email_changed: "Your email address was changed",
            two_factor_disabled: "Two-factor authentication was turned off"
          ] do
        assert render(SecurityAlert, Map.put(@required[SecurityAlert], :event, event)) =~
                 "<mj-title>#{title}</mj-title>"
      end

      assert_raise ArgumentError, ~r/attr :event must be one of/, fn ->
        SecurityAlert.to_html(Map.put(@required[SecurityAlert], :event, :new_device))
      end
    end

    test "lists where it happened, when given" do
      assert render(SecurityAlert) =~ ">203.0.113.42</td>"
      refute render(SecurityAlert, @required[SecurityAlert]) =~ ">Device</td>"
    end
  end

  describe "OrderConfirmation" do
    test "shows the items with their pictures, the totals and the shipping address" do
      mjml = render(OrderConfirmation)

      assert mjml =~ ~s(<img src="https://acme.com/mug.png" alt="Mug" width="64" height="64")
      assert mjml =~ ~r/Qty 2\s*<\/div>/
      assert mjml =~ ~r/>Subtotal<.*>Shipping<.*>Total</s
      assert mjml =~ ~r/Jane Cooper\s*<br>100 Main St/
      assert mjml =~ "Estimated delivery"
      assert mjml =~ "View your order</mj-button>"
    end

    test "leaves out the pictures' column when no item has one" do
      mjml = render(OrderConfirmation, @required[OrderConfirmation])

      refute mjml =~ "<img"
      refute mjml =~ ~s(width="64px")
      refute mjml =~ "Shipping to"
    end
  end
end
