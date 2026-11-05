# The content that `mix mjml_eex.gen.screenshots` takes the screenshots of the prebuilt
# templates with. See screenshots/README.md.
#
# `art` is the example images, drawn in HTML and CSS in screenshots/art/. Each one is
# screenshotted at its size in CSS pixels, at 2x, to art/<name>.png next to the emails, which
# is how the templates' assigns refer to them. `transparent: true` keeps the page's
# background transparent, for the logo.
#
# `templates` is an example of each template, in the order of the gallery, with the label the
# gallery shows. The screenshot of `MjmlEEx.Templates.FlashSale` is flash_sale.jpg.

brand = [product_name: "Acme", logo: "art/logo.png", product_url: "https://acme.com"]
address = "Acme Inc., 1 Market St, San Francisco, CA 94105"
help = "https://acme.com/help"
unsubscribe = "https://acme.com/unsubscribe"

%{
  art: [
    %{name: "logo", width: 120, height: 32, transparent: true},
    %{name: "launch", width: 600, height: 360},
    %{name: "featured", width: 600, height: 300},
    %{name: "story1", width: 240, height: 180},
    %{name: "story2", width: 240, height: 180},
    %{name: "story3", width: 240, height: 180},
    %{name: "sale_bg", width: 600, height: 440},
    %{name: "mug", width: 280, height: 280},
    %{name: "vase", width: 280, height: 280},
    %{name: "bowl", width: 280, height: 280},
    %{name: "planter", width: 280, height: 280}
  ],
  templates: [
    %{
      module: MjmlEEx.Templates.Welcome,
      label: "Welcome",
      assigns:
        brand ++
          [
            name: "Jane",
            cta_url: "https://acme.com/dashboard",
            cta_label: "Go to your dashboard",
            steps: [
              %{
                title: "Create your first project",
                description: "Projects keep your team's plans, tasks and files in one place.",
                url: "https://acme.com/projects/new",
                action: "Create a project"
              },
              %{
                title: "Invite your team",
                description: "Plan together, assign work and see what's next.",
                url: "https://acme.com/team",
                action: "Invite people"
              },
              %{title: "Connect your tools", description: "Bring in issues and messages from GitHub, Slack and more."}
            ],
            docs_url: "https://acme.com/docs",
            support_url: help,
            sign_off: "Maya Patel, CEO of Acme",
            address: address
          ]
    },
    %{
      module: MjmlEEx.Templates.VerifyEmail,
      label: "Verify email",
      assigns:
        brand ++
          [
            name: "Jane",
            email: "jane@example.com",
            verify_url: "https://acme.com/confirm/SFMyNTY.g2gDbQAAABBqYW5lQGV4YW1wbGUuY29t",
            support_url: help,
            address: address
          ]
    },
    %{
      module: MjmlEEx.Templates.MagicLink,
      label: "Magic link",
      assigns:
        brand ++
          [
            email: "jane@example.com",
            sign_in_url: "https://acme.com/users/log-in/SFMyNTY.g2gDbQAAABBqYW5lQGV4YW1wbGUuY29t",
            device: "Safari on iPhone",
            location: "Toronto, Canada",
            requested_at: "October 12, 2026 at 9:41 AM UTC",
            support_url: help,
            address: address
          ]
    },
    %{
      module: MjmlEEx.Templates.OneTimePassword,
      label: "One-time password",
      assigns:
        brand ++
          [
            code: "482913",
            device: "Chrome on macOS",
            location: "Lisbon, Portugal",
            requested_at: "October 12, 2026 at 9:41 AM UTC",
            support_url: help,
            address: address
          ]
    },
    %{
      module: MjmlEEx.Templates.ForgotPassword,
      label: "Forgot password",
      assigns:
        brand ++
          [
            name: "Jane",
            reset_url: "https://acme.com/reset-password/SFMyNTY.g2gDbQAAAAhqYW5lQGFjbWU",
            support_url: help,
            address: address
          ]
    },
    %{
      module: MjmlEEx.Templates.TeamInvitation,
      label: "Team invitation",
      assigns:
        brand ++
          [
            inviter_name: "Maya Patel",
            team_name: "Globex",
            accept_url: "https://acme.com/invitations/SFMyNTY.g2gDbQAAAAhnbG9iZXg",
            message: "We're planning Q4 in Acme now, and I'd love your input on the roadmap. See you there!",
            role: "Editor",
            support_url: help,
            address: address
          ]
    },
    %{
      module: MjmlEEx.Templates.SecurityAlert,
      label: "Security alert",
      assigns:
        brand ++
          [
            event: :new_sign_in,
            name: "Jane",
            device: "Firefox on Windows",
            location: "Berlin, Germany",
            ip_address: "203.0.113.42",
            occurred_at: "October 12, 2026 at 9:41 AM UTC",
            secure_url: "https://acme.com/account/security",
            support_url: help,
            address: address
          ]
    },
    %{
      module: MjmlEEx.Templates.TrialConversion,
      label: "Free trial conversion",
      assigns:
        brand ++
          [
            name: "Jane",
            trial_ends: "October 15",
            days_left: 3,
            upgrade_url: "https://acme.com/billing/upgrade",
            plan: "Pro",
            price: "$12 per user, per month",
            usage: [
              %{value: "12", label: "Projects"},
              %{value: "5", label: "Teammates"},
              %{value: "148", label: "Tasks done"}
            ],
            features: [
              "Unlimited projects and guests",
              "Advanced reports and dashboards",
              "SSO and audit logs",
              "Priority support"
            ],
            contact_url: "https://acme.com/sales",
            support_url: help,
            unsubscribe_url: unsubscribe,
            address: address
          ]
    },
    %{
      module: MjmlEEx.Templates.PaymentFailed,
      label: "Payment failed",
      assigns:
        brand ++
          [
            name: "Jane",
            amount: "$120.00",
            payment_method: "Visa ending in 4242",
            plan: "Pro",
            reason: "Your card was declined.",
            retry_on: "October 15, 2026",
            pay_by: "October 22, 2026",
            update_url: "https://acme.com/billing/payment-method",
            invoice_url: "https://acme.com/invoices/INV-2026-0042",
            support_url: "mailto:billing@acme.com",
            address: address
          ]
    },
    %{
      module: MjmlEEx.Templates.Invoice,
      label: "Invoice",
      assigns:
        brand ++
          [
            invoice_number: "INV-2026-0042",
            amount_due: "$1,286.40",
            due_date: "October 31, 2026",
            issued_on: "October 1, 2026",
            billed_to: ["Jane Cooper", "Globex Corporation", "100 Main St, Springfield, IL 62701"],
            items: [
              %{description: "Pro plan", detail: "Oct 1 – Oct 31, 2026", quantity: 10, amount: "$1,080.00"},
              %{
                description: "Extra storage (500 GB)",
                detail: "Oct 1 – Oct 31, 2026",
                quantity: 1,
                amount: "$120.00"
              }
            ],
            totals: [{"Subtotal", "$1,200.00"}, {"Tax (7.2%)", "$86.40"}],
            pay_url: "https://acme.com/invoices/INV-2026-0042/pay",
            pdf_url: "https://acme.com/invoices/INV-2026-0042.pdf",
            support_url: "mailto:billing@acme.com",
            address: address
          ]
    },
    %{
      module: MjmlEEx.Templates.OrderConfirmation,
      label: "Order confirmation",
      assigns:
        brand ++
          [
            name: "Jane",
            order_number: "#1042",
            items: [
              %{name: "Stoneware mug", detail: "Rust", quantity: 2, price: "$38.00", image: "art/mug.png"},
              %{name: "Glazed bottle vase", detail: "Sage", quantity: 1, price: "$68.00", image: "art/vase.png"},
              %{name: "Terracotta planter", detail: "Medium", quantity: 1, price: "$45.00", image: "art/planter.png"}
            ],
            totals: [{"Subtotal", "$151.00"}, {"Shipping", "Free"}, {"Tax", "$12.08"}],
            total: "$163.08",
            delivery_estimate: "Thursday, October 18 – Saturday, October 20",
            shipping_address: ["Jane Cooper", "100 Main St", "Springfield, IL 62701"],
            payment_method: "Visa ending in 4242",
            order_url: "https://acme.com/orders/1042",
            support_url: help,
            address: address
          ]
    },
    %{
      module: MjmlEEx.Templates.Webinar,
      label: "Webinar",
      assigns:
        brand ++
          [
            name: "Jane",
            title: "Ship faster with Acme workflows",
            date: "Thursday, November 6, 2026",
            time: "10:00 AM PT / 1:00 PM ET",
            duration: "45 minutes",
            description:
              "Join our product team for a live walkthrough of Acme workflows. We'll build three real automations " <>
                "from scratch and answer your questions as we go.",
            topics: [
              "Automate your weekly status reports",
              "Hand off work between teams without losing context",
              "Measure what your automations save you"
            ],
            speakers: [
              %{name: "Maya Patel", role: "Head of Product, Acme"},
              %{name: "Tom Okafor", role: "Solutions Engineer, Acme"}
            ],
            register_url: "https://acme.com/webinars/workflows",
            recording: true,
            unsubscribe_url: unsubscribe,
            address: address,
            social: [
              linkedin: "https://linkedin.com/company/acme",
              x: "https://x.com/acme",
              youtube: "https://youtube.com/@acme"
            ]
          ]
    },
    %{
      module: MjmlEEx.Templates.Newsletter,
      label: "Newsletter",
      assigns:
        brand ++
          [
            title: "The Acme Dispatch",
            issue: "Issue 42 · October 2026",
            intro:
              "This month we shipped our biggest release yet, talked to forty teams about how they plan their week, " <>
                "and learned a lot along the way. Here's what's worth your time.",
            sign_off: "Maya, editor of the Dispatch",
            featured: %{
              label: "Product",
              title: "Inside the redesign of Acme Insights",
              summary: "How we rebuilt our analytics from the ground up, and why we threw away the first two versions.",
              image: "art/featured.png",
              url: "https://acme.com/blog/insights"
            },
            stories: [
              %{
                label: "Guides",
                title: "Five reports every team should automate",
                summary: "Stop copying numbers into slides. These take ten minutes to set up.",
                image: "art/story1.png",
                url: "https://acme.com/blog/reports"
              },
              %{
                label: "Customers",
                title: "How Globex plans a quarter in one afternoon",
                summary: "Their head of operations walks us through the process, step by step.",
                image: "art/story2.png",
                url: "https://acme.com/blog/globex"
              },
              %{
                label: "Engineering",
                title: "Making search ten times faster",
                summary: "What we learned moving our search index to a new storage engine.",
                image: "art/story3.png",
                url: "https://acme.com/blog/search"
              }
            ],
            links: [
              %{title: "Acme 4.2 release notes", url: "https://acme.com/changelog", source: "Changelog"},
              %{title: "Join our community meetup in Berlin", url: "https://acme.com/events", source: "Events"},
              %{title: "We're hiring product designers", url: "https://acme.com/careers", source: "Careers"}
            ],
            unsubscribe_url: unsubscribe,
            address: address,
            social: [
              x: "https://x.com/acme",
              linkedin: "https://linkedin.com/company/acme",
              github: "https://github.com/acme"
            ]
          ]
    },
    %{
      module: MjmlEEx.Templates.ProductLaunch,
      label: "Product launch",
      assigns:
        brand ++
          [
            headline: "Introducing Acme Insights",
            description: "See how your team works, in real time, with dashboards that build themselves.",
            cta_url: "https://acme.com/insights",
            learn_more_url: "https://acme.com/blog/insights",
            image: "art/launch.png",
            features: [
              %{title: "Live dashboards", description: "Every chart updates the moment work happens."},
              %{title: "Smart alerts", description: "Hear about changes before they become problems."},
              %{title: "Shareable reports", description: "Send a link to anyone, no account needed."}
            ],
            quote: %{
              text: "Insights replaced three tools for us. Our Monday meeting now takes ten minutes.",
              author: "Sam Lee",
              role: "COO, Globex"
            },
            unsubscribe_url: unsubscribe,
            address: address,
            social: [
              x: "https://x.com/acme",
              linkedin: "https://linkedin.com/company/acme",
              youtube: "https://youtube.com/@acme"
            ]
          ]
    },
    %{
      module: MjmlEEx.Templates.FlashSale,
      label: "Flash sale",
      assigns:
        brand ++
          [
            headline: "40% off everything",
            description: "Our biggest sale of the season. Two days only.",
            code: "FLASH40",
            ends: "Ends Sunday at midnight",
            shop_url: "https://acme.com/sale",
            background_image: "art/sale_bg.png",
            products: [
              %{
                name: "Stoneware mug",
                price: "$32",
                sale_price: "$19",
                image: "art/mug.png",
                url: "https://acme.com/mug"
              },
              %{
                name: "Glazed bottle vase",
                price: "$68",
                sale_price: "$40",
                image: "art/vase.png",
                url: "https://acme.com/vase"
              },
              %{
                name: "Cobalt serving bowl",
                price: "$54",
                sale_price: "$32",
                image: "art/bowl.png",
                url: "https://acme.com/bowl"
              },
              %{
                name: "Terracotta planter",
                price: "$45",
                sale_price: "$27",
                image: "art/planter.png",
                url: "https://acme.com/planter"
              }
            ],
            terms:
              "Offer valid until October 19, 2026 at 11:59 PM PT on full-price items. " <>
                "Can't be combined with other offers.",
            unsubscribe_url: unsubscribe,
            address: address,
            social: [
              instagram: "https://instagram.com/acme",
              pinterest: "https://pinterest.com/acme",
              facebook: "https://facebook.com/acme"
            ]
          ]
    }
  ]
}
