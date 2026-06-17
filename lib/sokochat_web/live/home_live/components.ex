defmodule SokochatWeb.HomeLive.Components do
  use SokochatWeb, :html

  def page(assigns) do
    ~H"""
    <div class="bg-n50 text-n800">
      <.landing_header />
      <.hero />
      <.services />
      <.accordion_showcase />
      <.boost_conversions />
      <.streamline_workflow />
      <.best_digital_products />
      <.unlock_potential />
      <.testimonials />
      <.pricing />
      <.faq />
      <.footer />
    </div>
    """
  end

  def landing_header(assigns) do
    assigns =
      assigns
      |> assign(:nav_links, [
        %{label: "Platform", href: "#services"},
        %{label: "Playground", href: "#blog"},
        %{label: "Pricing", href: "#pricing"}
      ])
      |> assign(:company_links, ["About Us", "Contact", "Book a Demo", "Careers"])

    ~H"""
    <header class="sticky top-0 z-50 flex min-h-[72px] flex-col justify-center border-b border-n200 bg-n50/95 backdrop-blur">
      <div class="container-x flex items-center">
        <.brand_mark />

        <nav class="ml-6 mr-auto hidden items-center gap-6 lg:flex">
          <a
            :for={link <- @nav_links}
            href={link.href}
            class="p-2 text-n800 no-underline transition-colors hover:text-primary"
          >
            {link.label}
          </a>

          <div class="group relative">
            <button class="flex items-center gap-1 p-2 text-n800 transition-colors group-hover:text-primary">
              Company
              <svg
                class="h-4 w-4"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                aria-hidden="true"
              >
                <polyline points="6 9 12 15 18 9"></polyline>
              </svg>
            </button>
            <div class="invisible absolute left-0 top-full z-50 flex w-48 translate-y-1 flex-col gap-1 rounded-lg border border-n200 bg-n50 p-2 opacity-0 shadow-[0_8px_24px_rgba(0,0,0,0.08)] transition-all duration-200 group-hover:visible group-hover:translate-y-0 group-hover:opacity-100 group-focus-within:visible group-focus-within:translate-y-0 group-focus-within:opacity-100">
              <a
                :for={label <- @company_links}
                href="#"
                class="rounded p-2 text-n800 no-underline transition-colors hover:bg-n200 hover:text-primary"
              >
                {label}
              </a>
            </div>
          </div>
        </nav>

        <div class="ml-auto hidden items-center gap-4 lg:flex">
          <a href="/users/log_in" class="btn btn-secondary btn-sm">Login</a>
          <a href="/users/register" class="btn btn-primary btn-sm">Get Started</a>
        </div>

        <input type="checkbox" id="nav-toggle" class="peer hidden" />
        <label
          for="nav-toggle"
          class="ml-auto inline-flex h-10 w-10 cursor-pointer items-center justify-center rounded-lg text-n800 lg:hidden"
          aria-label="Open menu"
        >
          <svg
            class="h-6 w-6"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <line x1="3" y1="6" x2="21" y2="6"></line>
            <line x1="3" y1="12" x2="21" y2="12"></line>
            <line x1="3" y1="18" x2="21" y2="18"></line>
          </svg>
        </label>

        <nav class="absolute left-0 top-full hidden w-full flex-col gap-1 border-b border-n200 bg-n50 px-6 py-4 shadow-lg peer-checked:flex lg:hidden">
          <a
            :for={link <- @nav_links}
            href={link.href}
            class="p-2 text-n800 no-underline hover:text-primary"
          >
            {link.label}
          </a>
          <a href="#" class="p-2 text-n800 no-underline hover:text-primary">About Us</a>
          <a href="#" class="p-2 text-n800 no-underline hover:text-primary">Contact</a>
          <a href="#" class="p-2 text-n800 no-underline hover:text-primary">Book a Demo</a>
          <a href="#" class="p-2 text-n800 no-underline hover:text-primary">Careers</a>
          <div class="mt-3 flex flex-col gap-3">
            <a href="#" class="btn btn-secondary btn-sm w-full">Login</a>
            <a href="#" class="btn btn-primary btn-sm w-full">Get Started</a>
          </div>
        </nav>
      </div>
    </header>
    """
  end

  def hero(assigns) do
    ~H"""
    <section class="bg-[linear-gradient(to_bottom,rgba(15,156,92,0.09),rgba(255,255,255,0)_35%)] py-24 lg:py-[156px]">
      <div class="container-x">
        <div class="grid items-center gap-14 lg:grid-cols-[1.25fr_1fr]">
          <div class="flex flex-col items-start gap-6 text-center lg:text-left">
            <div class="section-title w-full lg:w-auto">AI-powered WhatsApp sales assistant</div>
            <h1 class="h1 w-full">
              Turn
              <span class="relative whitespace-nowrap text-primary">
                WhatsApp
                <svg
                  class="absolute -bottom-1 left-0 w-full"
                  height="10"
                  viewBox="0 0 200 10"
                  preserveAspectRatio="none"
                  fill="none"
                  aria-hidden="true"
                >
                  <path
                    d="M2 8C50 2 150 2 198 7"
                    stroke="#0f9c5c"
                    stroke-width="3"
                    stroke-linecap="round"
                  />
                </svg>
              </span>
              Conversations  into
              <span class="relative whitespace-nowrap text-primary">
                SALES
                <svg
                  class="absolute -bottom-1 left-0 w-full"
                  height="10"
                  viewBox="0 0 200 10"
                  preserveAspectRatio="none"
                  fill="none"
                  aria-hidden="true"
                >
                  <path
                    d="M2 8C50 2 150 2 198 7"
                    stroke="#0f9c5c"
                    stroke-width="3"
                    stroke-linecap="round"
                  />
                </svg>
              </span>
              With  Sokochat
            </h1>
            <p class="w-full text-lg font-medium text-n400">
              Sokochat lets any business create and run an AI-powered WhatsApp chatbot without code. Connect your own data source, keep answers current, and test the full WhatsApp experience in the browser before you go live.
            </p>
            <div class="flex w-full flex-wrap items-center justify-center gap-x-6 gap-y-4 lg:justify-start">
              <a href="#pricing" class="btn btn-primary btn-lg">Get Started</a>
              <a href="#services" class="btn btn-secondary btn-lg">See Playground</a>
            </div>
          </div>

          <div class="relative">
            <img
              src={~p"/images/1.png"}
              alt="WhatsApp business network illustration"
              class="h-[500px]"
            />
          </div>
        </div>
      </div>
    </section>
    """
  end

  def services(assigns) do
    assigns =
      assign(assigns, :cards, [
        %{
          title: "Answer buyers instantly",
          body:
            "Reply to repeated questions about prices, availability, location, and next steps without making customers wait."
        },
        %{
          title: "Keep your data live",
          body:
            "Connect your own endpoint so every conversation uses the latest product, pricing, and business information."
        },
        %{
          title: "Guide the next action",
          body:
            "Attach the right CTA at the right time with links, calls, WhatsApp handoff, maps, lists, and quick replies."
        }
      ])

    ~H"""
    <section id="services" class="py-12">
      <div class="container-x">
        <div class="grid gap-14 md:grid-cols-2 lg:grid-cols-3">
          <div
            :for={card <- @cards}
            class="group flex flex-col items-center gap-4 rounded-lg border border-n200 bg-n50 p-12 text-center text-n800 shadow-[0_8px_24px_rgba(0,0,0,0.05)] transition-all duration-300 ease-out hover:-translate-y-1 hover:border-primary/20 hover:bg-primary-light hover:shadow-[0_16px_40px_rgba(15,156,92,0.12)]"
          >
            <h3 class="h5 transition-colors duration-300 group-hover:text-primary">{card.title}</h3>
            <p class="text-n400 transition-colors duration-300 group-hover:text-n600">
              {card.body}
            </p>
          </div>
        </div>
      </div>
    </section>
    """
  end

  def accordion_showcase(assigns) do
    assigns =
      assign(assigns, :items, [
        %{
          title: "Your data stays yours",
          body:
            "The bot reads from your own API or JSON endpoint, so you keep full control over the information it uses in every reply."
        },
        %{
          title: "Playground-first testing",
          body:
            "Simulate the full WhatsApp flow in the browser, tune the bot, and only connect the real number when everything feels right."
        },
        %{
          title: "English and Swahili ready",
          body:
            "Respond in the same language the buyer uses and keep the tone consistent with your brand and sales process."
        }
      ])

    ~H"""
    <section class="py-24">
      <div class="container-x">
        <div class="grid items-center gap-14 lg:grid-cols-2">
          <img
            src={~p"/images/5.png"}
            alt="WhatsApp chatbot reply flow"
            loading="lazy"
            class="w-full rounded-2xl"
          />
          <div class="flex flex-col gap-6">
            <%= for {item, index} <- Enum.with_index(@items) do %>
              <details class="group border-b border-n300 pb-4" open={index == 0}>
                <summary class="flex cursor-pointer list-none items-center justify-between py-2.5 text-xl font-semibold">
                  {item.title}
                  <svg
                    class="h-5 w-5 text-primary transition-transform group-open:rotate-45"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    aria-hidden="true"
                  >
                    <line x1="12" y1="5" x2="12" y2="19"></line>
                    <line x1="5" y1="12" x2="19" y2="12"></line>
                  </svg>
                </summary>
                <p class="pt-2 tracking-[-0.03em] text-n400">{item.body}</p>
              </details>
            <% end %>
          </div>
        </div>
      </div>
    </section>
    """
  end

  def boost_conversions(assigns) do
    ~H"""
    <section class="bg-[linear-gradient(270deg,rgba(15,156,92,0.12),rgba(15,156,92,0)_84%)] py-24">
      <div class="container-x">
        <div class="grid items-center gap-14 lg:grid-cols-2">
          <div class="flex flex-col items-start gap-3">
            <div class="section-title">Features</div>
            <h2 class="h2">Build a better WhatsApp sales flow</h2>
            <p class="mb-6 text-n400">
              Use live data, simple instructions, and smart CTAs to reduce friction and move buyers toward the right next step faster.
            </p>
            <div class="flex flex-wrap items-center gap-x-6 gap-y-4">
              <a href="#pricing" class="btn btn-primary">Open Playground</a>
              <a href="#services" class="btn btn-secondary">View Pricing</a>
            </div>
          </div>
          <img
            src={~p"/images/2.png"}
            alt="WhatsApp conversion analytics dashboard"
            loading="lazy"
            class="w-full rounded-2xl"
          />
        </div>
      </div>
    </section>
    """
  end

  def streamline_workflow(assigns) do
    assigns =
      assign(assigns, :bullets, [
        "Create a workspace and connect a JSON endpoint, Google Sheet export, or other live data source",
        "Write plain-English instructions for tone, language, and conversation behavior",
        "Define CTAs such as links, calls, maps, WhatsApp handoff, quick replies, and product lists"
      ])

    ~H"""
    <section id="products" class="py-24">
      <div class="container-x">
        <div class="grid items-center gap-14 lg:grid-cols-2">
          <img
            src={~p"/images/4.png"}
            alt="Team planning a WhatsApp bot workflow"
            loading="lazy"
            class="w-full rounded-2xl"
          />
          <div class="flex flex-col items-start gap-3">
            <div class="section-title">Features</div>
            <h2 class="h2">Set up one workspace, then launch with confidence</h2>
            <p class="mb-6 text-n400">
              Each workspace can manage a bot for a specific business or product line. Add instructions, connect your endpoint, configure CTAs, and prepare the Meta WhatsApp Business details when you are ready to go live.
            </p>
            <div class="mb-6 flex flex-col gap-3">
              <div :for={bullet <- @bullets} class="flex items-center gap-2">
                <.check_icon class="text-primary" />
                <span class="text-n400">{bullet}</span>
              </div>
            </div>
            <div class="flex flex-wrap items-center gap-x-6 gap-y-4">
              <a href="#pricing" class="btn btn-primary">Get Started</a>
              <a href="#services" class="btn btn-secondary">Learn More</a>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  def best_digital_products(assigns) do
    assigns =
      assign(assigns, :features, [
        %{
          title: "Live answers",
          body:
            "The bot fetches fresh information on every conversation, so buyers see the latest prices, stock, and links."
        },
        %{
          title: "Action-based CTAs",
          body:
            "Send buyers to the right destination with a website link, phone call, map pin, WhatsApp number, or product list."
        }
      ])

    ~H"""
    <section class="py-24">
      <div class="container-x">
        <div class="grid items-center gap-14 lg:grid-cols-2">
          <div class="flex flex-col items-start gap-3">
            <div class="section-title">Features</div>
            <h2 class="h2">Everything you need to ship a production-ready bot</h2>
            <p class="mb-6 text-n400">
              Sokochat is built around the full lifecycle: configure, test, connect, and improve without rebuilding the flow every time your data changes.
            </p>
            <div class="mb-6 grid gap-6 sm:grid-cols-2">
              <div :for={feature <- @features} class="flex flex-col items-start gap-4">
                <div class="flex h-12 w-12 items-center justify-center rounded-lg bg-primary-light text-primary">
                  <svg
                    class="h-6 w-6"
                    viewBox="0 0 24 24"
                    fill="currentColor"
                    stroke="currentColor"
                    stroke-width="1.5"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    aria-hidden="true"
                  >
                    <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2">
                    </polygon>
                  </svg>
                </div>
                <div>
                  <h3 class="text-lg font-medium leading-tight">{feature.title}</h3>
                  <p class="text-n400">{feature.body}</p>
                </div>
              </div>
            </div>
            <div class="flex flex-wrap items-center gap-x-6 gap-y-4">
              <a href="#services" class="btn btn-secondary">Learn More</a>
            </div>
          </div>
          <img
            src={~p"/images/3.png"}
            alt="WhatsApp product discovery conversation"
            loading="lazy"
            class="w-full rounded-2xl"
          />
        </div>
      </div>
    </section>
    """
  end

  def unlock_potential(assigns) do
    assigns =
      assign(assigns, :stats, [
        "buyer replies",
        "languages supported"
      ])

    ~H"""
    <section class="bg-[linear-gradient(to_top,rgba(15,156,92,0.1),rgba(255,255,255,0)_35%)] py-24">
      <div class="container-x">
        <div class="mb-24 grid gap-x-64 gap-y-4 lg:grid-cols-[1.25fr_1fr]">
          <div>
            <div class="section-title">Conversions</div>
            <h2 class="h1 mt-2">Reduce repetitive chats and keep sales moving</h2>
          </div>
          <div class="flex flex-col gap-6">
            <p class="text-lg font-medium text-n400">
              Sokochat helps your team spend less time repeating the same answers and more time handling the conversations that need a human touch.
            </p>
            <div class="grid gap-6 sm:grid-cols-2">
              <div
                :for={label <- @stats}
                class="flex flex-col items-start gap-2 rounded-lg border border-n100 bg-n50 p-6 shadow-[0_8px_24px_rgba(0,0,0,0.05)]"
              >
                <div class="text-[56px] font-bold leading-none">
                  24<span class="text-primary">/7</span>
                </div>
                <h3 class="text-lg font-medium leading-tight">{label}</h3>
              </div>
            </div>
            <div class="flex flex-wrap items-center gap-x-6 gap-y-4">
              <a href="#pricing" class="btn btn-primary btn-lg">Get Started</a>
              <a href="#services" class="btn btn-secondary btn-lg">Learn More</a>
            </div>
          </div>
        </div>
        <div class="flex w-full justify-center">
          <img
            src={~p"/images/6.png"}
            alt="WhatsApp chatbot command center with answers"
            loading="lazy"
            class="w-3/4 rounded-2xl"
          />
        </div>
      </div>
    </section>
    """
  end

  def testimonials(assigns) do
    assigns =
      assign(assigns, :testimonials, [
        %{
          image: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=160&q=80",
          title: "We stopped answering the same question all day",
          body:
            "Sokochat helped us turn repetitive WhatsApp chats into instant answers, and our team now steps in only when a conversation needs a human.",
          author: "Faith Wanjiku",
          role: "Operations Lead @ FreshCart"
        },
        %{
          image: "https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=160&q=80",
          title: "The playground made launch much easier",
          body:
            "We tested the entire conversation flow in the browser, tuned the instructions, and felt confident before connecting our live number.",
          author: "Peter Otieno",
          role: "Founder @ Mkulima Direct"
        },
        %{
          image: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=160&q=80",
          title: "Our product data stays current",
          body:
            "When prices or stock change, the bot already knows because it reads from our live source on every conversation.",
          author: "Amina Hassan",
          role: "Customer Success @ Bazaar Hub"
        }
      ])

    ~H"""
    <section class="py-24">
      <div class="container-x">
        <div class="mx-auto mb-16 flex max-w-[900px] flex-col items-center gap-2 text-center">
          <div class="section-title">Testimonials</div>
          <h2 class="h2">What teams say</h2>
          <p class="text-n400">
            Early teams use Sokochat to remove repetitive WhatsApp support, speed up buyer responses, and keep product information accurate.
          </p>
        </div>
        <div class="grid gap-14 md:grid-cols-2 lg:grid-cols-3">
          <div
            :for={item <- @testimonials}
            class="flex flex-col items-center gap-3 rounded-lg border border-n100 bg-n50 p-8 text-center shadow-[0_8px_24px_rgba(0,0,0,0.05)]"
          >
            <div class="mb-9 flex gap-1 text-[#f5a623]" aria-label="5 out of 5 stars">
              <svg
                :for={_ <- 1..5}
                class="h-6 w-6"
                viewBox="0 0 24 24"
                fill="currentColor"
                aria-hidden="true"
              >
                <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2">
                </polygon>
              </svg>
            </div>
            <div class="flex h-16 w-16 items-center justify-center overflow-hidden rounded-full">
              <img src={item.image} alt="" class="h-full w-full object-cover" />
            </div>
            <div class="flex flex-col items-center">
              <div class="mb-3 font-medium">{item.title}</div>
              <p class="text-sm font-light text-n400">{item.body}</p>
              <div class="mt-4">
                <div class="font-medium text-primary">{item.author}</div>
                <div class="text-sm text-n400">{item.role}</div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
    """
  end

  def pricing(assigns) do
    assigns =
      assigns
      |> assign(:monthly_features, [
        "One workspace",
        "Live data endpoint",
        "Playground testing",
        "WhatsApp integration",
        "CTA rules"
      ])
      |> assign(:yearly_features, [
        "One workspace",
        "Live data endpoint",
        "Playground testing",
        "WhatsApp integration",
        "CTA rules"
      ])

    ~H"""
    <section
      id="pricing"
      class="bg-[linear-gradient(to_top,rgba(15,156,92,0.1),rgba(255,255,255,0)_35%)] py-24"
    >
      <div class="container-x">
        <div class="mx-auto mb-16 flex max-w-[900px] flex-col items-center gap-2 text-center">
          <div class="section-title">Pricing</div>
          <h2 class="h2">Choose the plan that fits your launch</h2>
          <p class="text-n400">
            Start small with one workspace, then expand when your team is ready for more bots and more conversations.
          </p>
        </div>
        <div class="mx-auto grid max-w-[856px] gap-14 md:grid-cols-2">
          <div class="flex flex-col items-start gap-6 rounded-lg border border-n300 bg-n50 p-9 transition-transform duration-300 hover:-translate-y-1">
            <div class="flex flex-col gap-2">
              <div class="text-base font-bold text-primary">Monthly</div>
              <div class="text-4xl font-bold leading-none">$29</div>
              <p class="text-sm font-light text-n400">
                A practical entry point for teams that want to launch one bot, test the flow, and validate the workflow before committing long term.
              </p>
            </div>
            <div class="h-px w-full bg-n300"></div>
            <div class="flex w-full flex-col gap-3">
              <div :for={item <- @monthly_features} class="flex items-center gap-2">
                <.check_icon class="text-primary" />
                <span class="text-n400">{item}</span>
              </div>
            </div>
            <a href="#" class="btn btn-primary w-full">Get Started</a>
          </div>

          <div class="flex flex-col items-start gap-6 rounded-lg border border-primary bg-primary p-9 text-n50 transition-transform duration-300 hover:-translate-y-1">
            <div class="flex flex-col gap-2">
              <div class="text-base font-bold text-white">Yearly</div>
              <div class="text-4xl font-bold leading-none">$290</div>
              <p class="text-sm font-light">
                Best for teams that want to keep building with Sokochat over time and reduce the overhead of monthly billing.
              </p>
            </div>
            <div class="h-px w-full bg-white/30"></div>
            <div class="flex w-full flex-col gap-3">
              <div :for={item <- @yearly_features} class="flex items-center gap-2">
                <.check_icon class="text-white" />
                <span>{item}</span>
              </div>
            </div>
            <a href="#" class="btn btn-secondary w-full">Get Started</a>
          </div>
        </div>
      </div>
    </section>
    """
  end

  defp blog(assigns) do
    assigns =
      assign(assigns, :posts, [
        %{
          image: "https://images.unsplash.com/photo-1551288049-bebda4e38f71?w=800&q=80",
          date: "June 10, 2026",
          title: "How to connect live product data to a WhatsApp bot",
          description:
            "Learn the simplest way to feed your chatbot fresh prices, availability, and product details from an API or JSON endpoint."
        },
        %{
          image: "https://images.unsplash.com/photo-1596526131083-e8c633c948d2?w=800&q=80",
          date: "May 28, 2026",
          title: "Writing better AI instructions for WhatsApp sales",
          description:
            "See how plain-English prompts shape tone, language, and behavior without forcing your team to learn prompt engineering jargon."
        },
        %{
          image: "https://images.unsplash.com/photo-1454165804606-c3d57bc86b40?w=800&q=80",
          date: "May 14, 2026",
          title: "Launching a WhatsApp bot without surprises",
          description:
            "Use the browser playground, tune your CTAs, and prepare your Meta WhatsApp Business credentials before you go live."
        }
      ])

    ~H"""
    <section id="blog" class="py-24">
      <div class="container-x">
        <div class="mb-16 flex flex-col items-start justify-between gap-6 md:flex-row md:items-end">
          <div class="md:w-3/5">
            <div class="section-title">Our Blog</div>
            <h2 class="h2 mt-2">Latest WhatsApp automation insights</h2>
            <p class="mt-3 text-n400">
              Short practical guides for teams building AI sales assistants, live data workflows, and better WhatsApp experiences.
            </p>
          </div>
          <a href="#" class="btn btn-primary mb-3 shrink-0">View All</a>
        </div>
        <div class="grid gap-14 md:grid-cols-2 lg:grid-cols-3">
          <.blog_card
            :for={post <- @posts}
            image={post.image}
            date={post.date}
            title={post.title}
            description={post.description}
          />
        </div>
      </div>
    </section>
    """
  end

  def faq(assigns) do
    assigns =
      assign(assigns, :items, [
        %{
          question: "How does Sokochat work?",
          answer:
            "Create a workspace, connect your data source, write simple instructions for the bot, test it in the playground, and connect your Meta WhatsApp Business credentials when you are ready."
        },
        %{
          question: "Can the bot reply in English and Swahili?",
          answer:
            "Yes. You can instruct the bot to respond in the same language the buyer uses, which makes it easier to support customers across East Africa."
        },
        %{
          question: "What data can I connect?",
          answer:
            "Any source that returns structured live data works well, including a JSON API, an existing business endpoint, or a spreadsheet-style export that your team keeps current."
        }
      ])

    ~H"""
    <section class="py-24">
      <div class="container-x">
        <div class="mx-auto mb-16 flex max-w-[900px] flex-col items-center gap-2 text-center">
          <div class="section-title">Frequently Asked Questions</div>
          <h2 class="h2">FAQs</h2>
          <p class="text-n400">
            Find answers to common questions about setup, data sources, languages, and going live on WhatsApp.
          </p>
        </div>
        <div class="mx-auto flex max-w-[564px] flex-col gap-6">
          <%= for {item, index} <- Enum.with_index(@items, 1) do %>
            <details
              class="group cursor-pointer rounded-lg border border-n300 bg-n50 p-6 transition-transform duration-300"
              open={index == 1}
            >
              <summary class="flex list-none items-center justify-between gap-4">
                <span class="flex items-center gap-2">
                  <span class="text-base text-primary">{index}.</span>
                  <span class="text-lg font-medium leading-[1.4]">{item.question}</span>
                </span>
                <span class="flex h-8 w-8 shrink-0 items-center justify-center text-primary">
                  <svg
                    class="h-5 w-5 transition-transform group-open:rotate-45"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    aria-hidden="true"
                  >
                    <line x1="12" y1="5" x2="12" y2="19"></line>
                    <line x1="5" y1="12" x2="19" y2="12"></line>
                  </svg>
                </span>
              </summary>
              <p class="pt-4 tracking-[-0.03em] text-n400">{item.answer}</p>
            </details>
          <% end %>
        </div>
      </div>
    </section>
    """
  end

  def footer(assigns) do
    assigns =
      assigns
      |> assign(:website_links, [
        %{label: "Home", href: "#"},
        %{label: "About Us", href: "#"},
        %{label: "Platform", href: "#services"},
        %{label: "Playground", href: "#blog"},
        %{label: "Pricing", href: "#pricing"},
        %{label: "Contact", href: "#"},
        %{label: "Book Demo", href: "#"}
      ])
      |> assign(:admin_links, ["Instructions", "Style Guide", "Licenses", "Changelog"])
      |> assign(:social_links, [
        %{label: "X", href: "https://www.x.com", icon: :x},
        %{label: "Instagram", href: "https://instagram.com", icon: :instagram},
        %{label: "LinkedIn", href: "https://linkedin.com", icon: :linkedin},
        %{label: "YouTube", href: "https://youtube.com", icon: :youtube},
        %{label: "Facebook", href: "https://facebook.com", icon: :facebook}
      ])

    ~H"""
    <footer class="py-16">
      <div class="container-x">
        <div class="border-t border-n200 pt-10">
          <div class="grid gap-12 lg:grid-cols-[1fr_1.35fr] lg:items-start">
            <div class="flex max-w-md flex-col gap-4">
              <.brand_mark />
              <div class="space-y-2">
                <p class="text-sm font-medium text-n900">
                  WhatsApp automation for modern teams.
                </p>
                <p class="text-sm leading-6 text-n500">
                  Sokochat helps teams launch AI WhatsApp assistants with live data and simple testing.
                </p>
              </div>
            </div>

            <div class="grid gap-10 sm:grid-cols-2 xl:grid-cols-3">
              <div class="flex flex-col gap-3">
                <div class="text-xs font-semibold uppercase tracking-[0.18em] text-n400">
                  Website
                </div>
                <nav class="flex flex-col gap-2 text-sm">
                  <a
                    :for={link <- @website_links}
                    href={link.href}
                    class="w-fit text-n800 no-underline transition-colors hover:text-primary"
                  >
                    {link.label}
                  </a>
                </nav>
              </div>

              <div class="flex flex-col gap-3">
                <div class="text-xs font-semibold uppercase tracking-[0.18em] text-n400">
                  Admin Pages
                </div>
                <nav class="flex flex-col gap-2 text-sm">
                  <a
                    :for={label <- @admin_links}
                    href="#"
                    class="w-fit text-n800 no-underline transition-colors hover:text-primary"
                  >
                    {label}
                  </a>
                </nav>
              </div>

              <div class="flex flex-col gap-3 sm:col-span-2 xl:col-span-1">
                <div class="text-xs font-semibold uppercase tracking-[0.18em] text-n400">
                  Follow Us
                </div>
                <nav class="flex flex-wrap gap-2">
                  <a
                    :for={link <- @social_links}
                    href={link.href}
                    target="_blank"
                    rel="noopener"
                    class="inline-flex items-center gap-2 rounded-md border border-n200 px-3 py-2 text-sm text-n800 no-underline transition-colors hover:border-primary/20 hover:text-primary"
                  >
                    <.social_icon icon={link.icon} />
                    <span>{link.label}</span>
                  </a>
                </nav>
              </div>
            </div>
          </div>

          <div class="mt-10 flex flex-col gap-3 border-t border-n200 pt-6 text-sm text-n500 md:flex-row md:items-center md:justify-between">
            <div>&copy; 2026 Sokochat.</div>
            <div class="flex items-center gap-6">
              <a href="#" class="text-sm text-n500 no-underline transition-colors hover:text-primary">
                Privacy Policy
              </a>
              <a href="#" class="text-sm text-n500 no-underline transition-colors hover:text-primary">
                Terms &amp; Conditions
              </a>
            </div>
          </div>
        </div>
      </div>
    </footer>
    """
  end

  attr :image, :string, required: true
  attr :date, :string, required: true
  attr :title, :string, required: true
  attr :description, :string, required: true

  defp blog_card(assigns) do
    ~H"""
    <a
      href="#"
      class="group flex flex-col gap-4 rounded-lg border border-n100 bg-n50 p-6 no-underline shadow-[0_8px_24px_rgba(0,0,0,0.05)] transition-transform duration-300 hover:-translate-y-1"
    >
      <div class="relative h-[274px] w-full overflow-hidden rounded-lg">
        <img
          src={@image}
          alt=""
          loading="lazy"
          class="h-full w-full object-cover transition-transform duration-500 group-hover:scale-105"
        />
        <div class="absolute right-4 top-4 flex h-9 w-9 items-center justify-center rounded-full bg-n50 text-primary opacity-0 shadow transition-opacity duration-300 group-hover:opacity-100">
          <svg
            class="h-4 w-4"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            aria-hidden="true"
          >
            <line x1="7" y1="17" x2="17" y2="7"></line>
            <polyline points="7 7 17 7 17 17"></polyline>
          </svg>
        </div>
      </div>
      <div>
        <div class="text-sm text-n400">{@date}</div>
        <div class="h5 mt-2 text-n900">{@title}</div>
      </div>
      <p class="text-sm text-n400">{@description}</p>
    </a>
    """
  end

  attr :class, :string, default: "text-primary"

  defp check_icon(assigns) do
    ~H"""
    <svg
      class={"h-5 w-5 shrink-0 #{@class}"}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      aria-hidden="true"
    >
      <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"></path>
      <polyline points="22 4 12 14.01 9 11.01"></polyline>
    </svg>
    """
  end

  defp brand_mark(assigns) do
    ~H"""
    <a href="#" class="flex items-center gap-2 no-underline">
      <img src={~p"/images/logo.png"} alt="Sokochat" class="h-10 w-auto object-contain" />
      <span class="sr-only">Sokochat</span>
    </a>
    """
  end

  attr :icon, :atom, required: true

  defp social_icon(assigns) do
    ~H"""
    <%= case @icon do %>
      <% :x -> %>
        <svg class="h-5 w-5" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true">
          <path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24h-6.66l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25h6.83l4.713 6.231 5.447-6.231zm-1.161 17.52h1.833L7.084 4.126H5.117l11.966 15.644z">
          </path>
        </svg>
      <% :instagram -> %>
        <svg
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <rect x="2" y="2" width="20" height="20" rx="5" ry="5"></rect>
          <path d="M16 11.37A4 4 0 1 1 12.63 8 4 4 0 0 1 16 11.37z"></path>
          <line x1="17.5" y1="6.5" x2="17.51" y2="6.5"></line>
        </svg>
      <% :linkedin -> %>
        <svg
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <path d="M16 8a6 6 0 0 1 6 6v7h-4v-7a2 2 0 0 0-2-2 2 2 0 0 0-2 2v7h-4v-7a6 6 0 0 1 6-6z">
          </path>
          <rect x="2" y="9" width="4" height="12"></rect>
          <circle cx="4" cy="4" r="2"></circle>
        </svg>
      <% :youtube -> %>
        <svg
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <path d="M22.54 6.42a2.78 2.78 0 0 0-1.94-2C18.88 4 12 4 12 4s-6.88 0-8.6.46a2.78 2.78 0 0 0-1.94 2A29 29 0 0 0 1 11.75a29 29 0 0 0 .46 5.33A2.78 2.78 0 0 0 3.4 19c1.72.46 8.6.46 8.6.46s6.88 0 8.6-.46a2.78 2.78 0 0 0 1.94-2 29 29 0 0 0 .46-5.25 29 29 0 0 0-.46-5.33z">
          </path>
          <polygon points="9.75 15.02 15.5 11.75 9.75 8.48 9.75 15.02"></polygon>
        </svg>
      <% :facebook -> %>
        <svg
          class="h-5 w-5"
          viewBox="0 0 24 24"
          fill="none"
          stroke="currentColor"
          stroke-width="2"
          stroke-linecap="round"
          stroke-linejoin="round"
          aria-hidden="true"
        >
          <path d="M18 2h-3a5 5 0 0 0-5 5v3H7v4h3v8h4v-8h3l1-4h-4V7a1 1 0 0 1 1-1h3z"></path>
        </svg>
    <% end %>
    """
  end
end
