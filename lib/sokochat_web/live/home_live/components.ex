defmodule SokochatWeb.HomeLive.Components do
  use SokochatWeb, :html

  def page(assigns) do
    ~H"""
    <div class="marketing-home scroll-smooth bg-white font-body text-dim antialiased">
      <.svg_defs />

      <header role="banner" class="navbar my-[15px]">
        <div class="container mx-auto max-w-[1400px] px-[30px]">
          <div class="grid grid-cols-[.5fr_1fr] items-center gap-[30px] lg:grid-cols-[.75fr_2.75fr_2fr]">
            <a href="#" aria-label="Sokochat home" class="flex items-center gap-2 no-underline">
              <span class="grid h-9 w-9 place-items-center rounded-lg bg-primary font-head text-lg font-extrabold text-white">
                S
              </span>
              <span class="font-head text-2xl font-extrabold text-dark">Sokochat</span>
            </a>

            <input type="checkbox" id="nav-toggle" class="peer hidden" />
            <nav class="order-last col-span-2 hidden flex-col gap-1 peer-checked:flex lg:order-none lg:col-span-1 lg:flex lg:flex-row lg:items-center lg:justify-center">
              <a
                href="#"
                class="px-5 py-[10px] font-medium text-primary no-underline transition-colors"
              >
                Home
              </a>
              <a
                href="#about"
                class="px-5 py-[10px] text-dark no-underline transition-colors hover:text-primary"
              >
                How It Works
              </a>
              <div class="group relative px-5 py-[10px]">
                <div class="flex cursor-pointer items-center gap-2 text-dark transition-colors group-hover:text-primary">
                  <div>Pages</div>
                  <svg
                    class="h-3 w-3"
                    viewBox="0 0 24 24"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="3"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <polyline points="6 9 12 15 18 9" />
                  </svg>
                </div>
                <nav class="left-0 top-full z-50 mt-[15px] hidden w-[250px] flex-col rounded-[10px] bg-lavender py-[10px] shadow-[0_0_15px_5px_#8484841a] group-hover:flex group-focus-within:flex lg:absolute">
                  <a href="#" class="w-full px-5 py-2 text-primary no-underline transition-colors">
                    Home
                  </a>
                  <a
                    href="#about"
                    class="w-full px-5 py-2 text-dark no-underline transition-colors hover:text-primary"
                  >
                    How It Works
                  </a>
                  <a
                    href="#features"
                    class="w-full px-5 py-2 text-dark no-underline transition-colors hover:text-primary"
                  >
                    Features
                  </a>
                  <a
                    href="#cases"
                    class="w-full px-5 py-2 text-dark no-underline transition-colors hover:text-primary"
                  >
                    Use Cases
                  </a>
                  <a
                    href="#services"
                    class="w-full px-5 py-2 text-dark no-underline transition-colors hover:text-primary"
                  >
                    Services
                  </a>
                  <a
                    href="#blog"
                    class="w-full px-5 py-2 text-dark no-underline transition-colors hover:text-primary"
                  >
                    Ready to Launch
                  </a>
                  <a
                    href="#contact"
                    class="w-full px-5 py-2 text-dark no-underline transition-colors hover:text-primary"
                  >
                    Contact
                  </a>
                  <a
                    href="#contact"
                    class="w-full px-5 py-2 text-dark no-underline transition-colors hover:text-primary"
                  >
                    Privacy Policy
                  </a>
                  <a
                    href="#contact"
                    class="w-full px-5 py-2 text-dark no-underline transition-colors hover:text-primary"
                  >
                    Terms
                  </a>
                </nav>
              </div>
              <a
                href="#cases"
                class="px-5 py-[10px] text-dark no-underline transition-colors hover:text-primary"
              >
                Use Cases
              </a>
              <a
                href="#contact"
                class="px-5 py-[10px] text-dark no-underline transition-colors hover:text-primary"
              >
                Contact
              </a>
            </nav>

            <div class="flex items-center justify-end gap-5 lg:justify-center">
              <a href="tel:+254700000000" class="hidden text-dark no-underline md:block">
                +254 700 000 000
              </a>
              <a
                href="#contact"
                class="hidden flex-none rounded-[10px] border border-primary bg-primary px-[30px] py-[15px] text-center text-smoke no-underline shadow-[0_24px_55px_-19px_#5956e966] transition-all hover:bg-dark hover:text-white sm:block"
              >
                Book a demo
              </a>
              <label
                for="nav-toggle"
                class="flex cursor-pointer items-center rounded-[10px] bg-primary p-[15px] text-white lg:hidden"
                aria-label="Toggle menu"
              >
                <svg
                  class="h-5 w-5"
                  viewBox="0 0 24 24"
                  fill="none"
                  stroke="currentColor"
                  stroke-width="2"
                  stroke-linecap="round"
                >
                  <line x1="3" y1="6" x2="21" y2="6" />
                  <line x1="3" y1="12" x2="21" y2="12" />
                  <line x1="3" y1="18" x2="21" y2="18" />
                </svg>
              </label>
            </div>
          </div>
        </div>
      </header>

      <section class="hero-section pt-[30px] md:pt-[80px]">
        <div class="container mx-auto max-w-[1400px] px-[15px] md:px-[30px]">
          <div class="relative mb-[30px] text-center md:mb-[70px]">
            <div class="mx-auto mb-[15px] inline-flex items-center justify-center gap-[8px] rounded-full border border-white/70 bg-white/80 px-4 py-2 text-sm font-semibold shadow-[0_16px_36px_-24px_rgba(21,63,51,0.45)] backdrop-blur">
              <svg class="h-5 w-5"><use href="#i-smile" /></svg>
              <div class="text-dark">Your always-on WhatsApp sales team</div>
            </div>
            <div class="relative">
              <h1 class="relative z-[1]">
                Turn WhatsApp conversations into <span class="text-primary">sales</span> with
                Sokochat
              </h1>
              <div class="absolute right-[182px] top-[35px] -z-[2] h-[30px] w-[440px] rounded-full bg-primary blur-[50px]">
              </div>
            </div>
            <p class="mx-auto mt-5 max-w-[850px] text-[17px] leading-[1.8em] text-dim md:text-[18px]">
              Sokochat helps businesses answer buyer questions instantly using live product data,
              simple AI instructions, and a WhatsApp-style playground you can test before going
              live.
            </p>
            <div class="mt-6 flex flex-wrap items-center justify-center gap-4">
              <a
                href="#contact"
                class="rounded-[10px] border border-primary bg-primary px-[30px] py-[15px] text-center font-semibold text-smoke no-underline shadow-[0_24px_55px_-19px_#5956e966] transition-all hover:bg-dark hover:text-white"
              >
                Start free
              </a>
              <a
                href="#about"
                class="rounded-[10px] border border-[#d7e1db] bg-white px-[30px] py-[15px] text-center font-semibold text-dark no-underline transition-all hover:border-primary hover:text-primary"
              >
                See how it works
              </a>
            </div>
            <div class="mt-5 text-[15px] font-medium text-dim">
              Built for merchants, marketplaces, and growing teams across East Africa
            </div>
            <svg class="absolute bottom-[-42px] left-[56px] hidden h-10 w-10 md:left-[160px] md:block">
              <use href="#i-wa" />
            </svg>
            <svg class="absolute left-0 top-[-29px] h-[30px] w-[30px] md:top-[-23px] md:h-[50px] md:w-[50px]">
              <use href="#i-fb" />
            </svg>
            <svg class="absolute right-[3px] top-0 hidden h-10 w-10 md:block">
              <use href="#i-ig" />
            </svg>
            <svg class="absolute bottom-[-85px] right-[247px] hidden h-[50px] w-[50px] md:block">
              <use href="#i-tw" />
            </svg>
          </div>
          <div class="grid grid-cols-1 gap-[30px] md:grid-cols-3 lg:gap-[60px]">
            <img
              src="https://images.unsplash.com/photo-1573497019940-1c28c88b4f3e?w=1080&q=80"
              alt="Sales team supporting customers"
              class="h-full w-full rounded-[10px] object-cover"
            />
            <div class="md:mt-[81px]">
              <img
                src="https://images.unsplash.com/photo-1611162617474-5b21e879e113?w=1080&q=80"
                alt="WhatsApp-style chat experience"
                class="h-full w-full rounded-[10px] object-cover shadow-[0_0_15px_5px_#8484841a]"
              />
            </div>
            <img
              src="https://images.unsplash.com/photo-1521737604893-d14cc237f11d?w=1080&q=80"
              alt="Commerce team collaborating"
              class="h-full w-full rounded-[10px] object-cover"
            />
          </div>
        </div>
      </section>

      <section class="py-[40px] md:py-[80px]">
        <div class="container mx-auto max-w-[1200px] px-[15px] md:px-[30px]">
          <div class="mx-auto mb-[30px] max-w-full text-center md:mb-[50px] md:max-w-[80%]">
            <h2 class="text-[20px] font-semibold leading-[1.2em]">
              Built for modern commerce teams that sell where customers already chat
            </h2>
          </div>
          <div class="relative">
            <div class="absolute inset-y-0 left-0 z-[1] h-full w-[100px] bg-gradient-to-r from-white to-transparent">
            </div>
            <div class="absolute inset-y-0 right-0 z-[1] h-full w-[100px] bg-gradient-to-l from-white to-transparent">
            </div>
            <div class="overflow-hidden">
              <div class="client-track text-[#758696]">
                <svg height="34" viewBox="0 0 190 34" class="flex-none">
                  <circle cx="14" cy="17" r="9" fill="none" stroke="currentColor" stroke-width="3" />
                  <text
                    x="30"
                    y="24"
                    font-family="Montserrat,Arial"
                    font-size="18"
                    font-weight="700"
                    fill="currentColor"
                  >
                    Marketplace Operators
                  </text>
                </svg>
                <svg height="34" viewBox="0 0 150 34" class="flex-none">
                  <path
                    d="M6 24c4-12 10-12 14 0 4-12 10-12 14 0"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="3"
                  />
                  <text
                    x="42"
                    y="24"
                    font-family="Montserrat,Arial"
                    font-size="18"
                    font-weight="700"
                    fill="currentColor"
                  >
                    Retail Brands
                  </text>
                </svg>
                <svg height="34" viewBox="0 0 135 34" class="flex-none">
                  <polygon
                    points="14,5 23,26 5,26"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="3"
                  />
                  <text
                    x="30"
                    y="24"
                    font-family="Montserrat,Arial"
                    font-size="18"
                    font-weight="700"
                    fill="currentColor"
                  >
                    Distributors
                  </text>
                </svg>
                <svg height="34" viewBox="0 0 185 34" class="flex-none">
                  <circle cx="14" cy="17" r="8" fill="currentColor" />
                  <text
                    x="30"
                    y="24"
                    font-family="Montserrat,Arial"
                    font-size="18"
                    font-weight="700"
                    fill="currentColor"
                  >
                    Service Businesses
                  </text>
                </svg>
                <svg height="34" viewBox="0 0 155 34" class="flex-none">
                  <rect
                    x="6"
                    y="9"
                    width="16"
                    height="16"
                    rx="4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="3"
                  />
                  <text
                    x="30"
                    y="24"
                    font-family="Montserrat,Arial"
                    font-size="18"
                    font-weight="700"
                    fill="currentColor"
                  >
                    Local Merchants
                  </text>
                </svg>
                <svg height="34" viewBox="0 0 190 34" class="flex-none">
                  <circle cx="14" cy="17" r="9" fill="none" stroke="currentColor" stroke-width="3" />
                  <text
                    x="30"
                    y="24"
                    font-family="Montserrat,Arial"
                    font-size="18"
                    font-weight="700"
                    fill="currentColor"
                  >
                    Marketplace Operators
                  </text>
                </svg>
                <svg height="34" viewBox="0 0 150 34" class="flex-none">
                  <path
                    d="M6 24c4-12 10-12 14 0 4-12 10-12 14 0"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="3"
                  />
                  <text
                    x="42"
                    y="24"
                    font-family="Montserrat,Arial"
                    font-size="18"
                    font-weight="700"
                    fill="currentColor"
                  >
                    Retail Brands
                  </text>
                </svg>
                <svg height="34" viewBox="0 0 135 34" class="flex-none">
                  <polygon
                    points="14,5 23,26 5,26"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="3"
                  />
                  <text
                    x="30"
                    y="24"
                    font-family="Montserrat,Arial"
                    font-size="18"
                    font-weight="700"
                    fill="currentColor"
                  >
                    Distributors
                  </text>
                </svg>
                <svg height="34" viewBox="0 0 185 34" class="flex-none">
                  <circle cx="14" cy="17" r="8" fill="currentColor" />
                  <text
                    x="30"
                    y="24"
                    font-family="Montserrat,Arial"
                    font-size="18"
                    font-weight="700"
                    fill="currentColor"
                  >
                    Service Businesses
                  </text>
                </svg>
                <svg height="34" viewBox="0 0 155 34" class="flex-none">
                  <rect
                    x="6"
                    y="9"
                    width="16"
                    height="16"
                    rx="4"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="3"
                  />
                  <text
                    x="30"
                    y="24"
                    font-family="Montserrat,Arial"
                    font-size="18"
                    font-weight="700"
                    fill="currentColor"
                  >
                    Local Merchants
                  </text>
                </svg>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section id="features" class="pb-[40px] md:pb-[80px]">
        <div class="container mx-auto max-w-[1400px] px-[15px] md:px-[30px]">
          <div class="mb-[30px] max-w-full md:mb-[50px] md:max-w-[70%]">
            <div class="mb-[15px] flex items-center justify-start gap-[5px] font-semibold">
              <svg class="h-5 w-5"><use href="#i-smile" /></svg>
              <div class="text-primary">What you get</div>
            </div>
            <h2>Everything you need to launch a WhatsApp sales bot</h2>
            <p class="max-w-[760px]">
              From setup to live conversations, Sokochat gives your team the tools to automate
              replies without losing context or control.
            </p>
          </div>
          <div class="grid grid-cols-1 gap-5 md:gap-[30px] lg:grid-cols-2">
            <div class="grid grid-cols-1 items-center gap-5 rounded-[10px] border border-[#6f737a33] bg-white p-5 shadow-[0_0_15px_5px_#8484841a] md:grid-cols-[.75fr_1fr] md:gap-[30px]">
              <div class="grid h-[120px] w-full place-items-center rounded-[10px] bg-lavender text-primary">
                <svg class="h-14 w-14"><use href="#i-target" /></svg>
              </div>
              <div>
                <h3 class="text-[20px]">Live product answers</h3>
                <p>
                  Connect a JSON endpoint and let Sokochat answer using your latest prices, stock,
                  links, and business details.
                </p>
              </div>
            </div>
            <div class="grid grid-cols-1 items-center gap-5 rounded-[10px] border border-[#6f737a33] bg-white p-5 shadow-[0_0_15px_5px_#8484841a] md:grid-cols-[.75fr_1fr] md:gap-[30px]">
              <div class="grid h-[120px] w-full place-items-center rounded-[10px] bg-lavender text-primary">
                <svg class="h-14 w-14"><use href="#i-compass" /></svg>
              </div>
              <div>
                <h3 class="text-[20px]">Simple AI instructions</h3>
                <p>
                  Describe your tone, sales approach, and language rules in plain English instead
                  of building complex workflows.
                </p>
              </div>
            </div>
            <div class="grid grid-cols-1 items-center gap-5 rounded-[10px] border border-[#6f737a33] bg-white p-5 shadow-[0_0_15px_5px_#8484841a] md:grid-cols-[.75fr_1fr] md:gap-[30px]">
              <div class="grid h-[120px] w-full place-items-center rounded-[10px] bg-lavender text-primary">
                <svg class="h-14 w-14"><use href="#i-zap" /></svg>
              </div>
              <div>
                <h3 class="text-[20px]">Smart action prompts</h3>
                <p>
                  Show the right next step at the right moment with links, click-to-call actions,
                  WhatsApp handoff, maps, or product lists.
                </p>
              </div>
            </div>
            <div class="grid grid-cols-1 items-center gap-5 rounded-[10px] border border-[#6f737a33] bg-white p-5 shadow-[0_0_15px_5px_#8484841a] md:grid-cols-[.75fr_1fr] md:gap-[30px]">
              <div class="grid h-[120px] w-full place-items-center rounded-[10px] bg-lavender text-primary">
                <svg class="h-14 w-14"><use href="#i-bulb" /></svg>
              </div>
              <div>
                <h3 class="text-[20px]">Playground testing</h3>
                <p>
                  Preview the full chat experience in the browser before connecting your number, so
                  you can tune replies with confidence.
                </p>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section id="about" class="overflow-hidden pb-[40px] md:pb-[80px]">
        <div class="container mx-auto max-w-[1400px] px-[15px] md:px-[30px]">
          <div class="grid grid-cols-1 items-center gap-[50px] lg:grid-cols-2 lg:gap-[100px]">
            <div>
              <div class="mb-[15px] flex items-center justify-start gap-[5px] font-semibold">
                <svg class="h-5 w-5"><use href="#i-smile" /></svg>
                <div class="text-primary">Why Sokochat</div>
              </div>
              <h2>Built for businesses that already sell on WhatsApp</h2>
              <p>
                Most businesses do not need another complicated support tool. They need a fast way
                to answer buyer questions, share accurate information, and keep sales moving inside
                the channel customers already use every day.
              </p>
              <p class="mb-[40px] mt-5">
                Sokochat was designed for that exact workflow. It combines live business data,
                AI-generated replies, and no-code setup so teams can automate common conversations
                without giving up control of the customer experience.
              </p>
              <div class="grid grid-cols-1 gap-5">
                <div class="about-item">
                  <div class="mb-5 flex h-[50px] w-[50px] items-center justify-center rounded-[10px] bg-dark text-white">
                    <svg class="h-6 w-6"><use href="#i-target" /></svg>
                  </div>
                  <div>
                    <h3 class="text-[20px]">Fast setup</h3>
                    <p>
                      Create a workspace, connect your data source, write a few instructions, and
                      start testing in minutes.
                    </p>
                  </div>
                </div>
                <div class="about-item">
                  <div class="mb-5 flex h-[50px] w-[50px] items-center justify-center rounded-[10px] bg-dark text-white">
                    <svg class="h-6 w-6"><use href="#i-check" /></svg>
                  </div>
                  <div>
                    <h3 class="text-[20px]">Always current</h3>
                    <p>
                      Because Sokochat reads live endpoint data, your bot responds using the latest
                      availability, pricing, and business information.
                    </p>
                  </div>
                </div>
              </div>
            </div>
            <div class="relative flex flex-col items-center lg:block">
              <div class="relative">
                <div class="ml-auto h-[320px] w-[320px] overflow-hidden rounded-full border-[5px] border-white shadow-[0_24px_55px_-19px_#5956e966] md:h-[380px] md:w-[380px]">
                  <img
                    src="https://images.unsplash.com/photo-1600880292203-757bb62b4baf?w=1080&q=80"
                    alt="Team strategy meeting"
                    class="h-full w-full object-cover"
                  />
                </div>
                <div class="absolute right-[-27px] top-[5px] md:right-[-25px]">
                  <img
                    src="https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=200&q=80"
                    alt=""
                    class="h-10 rounded-[60px] shadow-[0_0_15px_5px_#8484841a] md:h-[60px]"
                  />
                  <svg class="absolute left-0 top-0 h-6 w-6 -translate-x-[29px] -translate-y-[18px] md:-translate-y-[24px]">
                    <use href="#i-like" />
                  </svg>
                </div>
              </div>
              <div class="relative ml-[-80px] mt-[-116px] hidden lg:block">
                <div class="h-[230px] w-[370px] overflow-hidden rounded-[164px] border-[5px] border-white md:h-[250px] md:w-[410px]">
                  <img
                    src="https://images.unsplash.com/photo-1556761175-5973dc0f32e7?w=1080&q=80"
                    alt="Marketing team collaborating"
                    class="h-full w-full object-cover"
                  />
                </div>
                <div class="absolute bottom-[20px] left-[-10px]">
                  <img
                    src="https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&q=80"
                    alt=""
                    class="h-10 rounded-[60px] shadow-[0_0_15px_5px_#8484841a] md:h-[60px]"
                  />
                  <svg class="absolute left-0 top-0 h-6 w-6 -translate-x-[29px] -translate-y-[18px] md:-translate-y-[24px]">
                    <use href="#i-heart" />
                  </svg>
                </div>
              </div>
              <svg class="absolute bottom-[81px] right-[6px] h-[60px] w-[60px] md:right-[17px]">
                <use href="#i-yt" />
              </svg>
              <svg class="absolute left-[-5px] top-[25px] h-[60px] w-[60px]">
                <use href="#i-li" />
              </svg>
            </div>
          </div>
        </div>
      </section>

      <section class="relative overflow-hidden bg-dark py-[50px] md:py-[70px]">
        <div class="container mx-auto max-w-[1200px] px-[15px] md:px-[30px]">
          <div class="mb-[70px] grid grid-cols-1 items-center gap-[30px] md:grid-cols-[.5fr_1fr] md:gap-[50px] lg:gap-[100px]">
            <div class="relative">
              <div class="absolute left-[-24px] top-[80px] z-[2] hidden md:block">
                <img
                  src="https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=200&q=80"
                  alt=""
                  class="h-10 rounded-[60px] shadow-[0_0_15px_5px_#8484841a] md:h-[60px]"
                />
                <svg class="absolute left-0 top-0 h-6 w-6 -translate-x-[29px] -translate-y-[18px] md:-translate-y-[24px]">
                  <use href="#i-heart" />
                </svg>
              </div>
              <img
                src="https://images.unsplash.com/photo-1567446537708-ac4aa75c9c28?w=1080&q=80"
                alt="Happy client"
                class="rounded-[10px] shadow-[0_0_15px_5px_#8484841a]"
              />
              <svg class="absolute bottom-[2px] left-[-5px] h-[30px] w-[30px] md:left-[-20px] md:h-10 md:w-10">
                <use href="#i-smile" />
              </svg>
              <svg class="absolute left-[-14px] top-[200px] h-10 w-10 md:left-[-24px] md:h-[50px] md:w-[50px]">
                <use href="#i-fb" />
              </svg>
              <svg class="absolute bottom-[-12px] right-[15px] h-10 w-10"><use href="#i-yt" /></svg>
              <svg class="absolute right-[-7px] top-[130px] h-10 w-10"><use href="#i-ig" /></svg>
              <svg class="absolute right-[-7px] top-[-18px] h-10 w-10 md:right-[-20px] md:top-[-30px] md:h-[60px] md:w-[60px]">
                <use href="#i-heart" />
              </svg>
            </div>

            <div>
              <input type="radio" name="ttab" id="t1" class="hidden" />
              <input type="radio" name="ttab" id="t2" class="hidden" />
              <input type="radio" name="ttab" id="t3" class="hidden" />
              <input type="radio" name="ttab" id="t4" class="hidden" checked />
              <div class="t-content">
                <div class="t-pane t-pane-1">
                  <svg class="mb-5 h-[60px] w-[60px]"><use href="#i-quote" /></svg>
                  <p class="mb-[50px] text-[22px] font-semibold leading-[1.5em] text-white md:text-[24px]">
                    Sokochat helped us stop repeating the same answers all day on WhatsApp. Our
                    buyers now get instant replies, and our team only steps in when a conversation
                    needs a human touch.
                  </p>
                  <div class="relative z-[2] ml-auto max-w-[60%] text-right md:max-w-[30%]">
                    <div class="text-[16px] font-semibold text-white">Amina Njoroge</div>
                    <div class="mt-1 text-[14px] text-white/80">Marketplace Operations Lead</div>
                  </div>
                </div>
                <div class="t-pane t-pane-2">
                  <svg class="mb-5 h-[60px] w-[60px]"><use href="#i-quote" /></svg>
                  <p class="mb-[50px] text-[22px] font-semibold leading-[1.5em] text-white md:text-[24px]">
                    Sokochat helped us stop repeating the same answers all day on WhatsApp. Our
                    buyers now get instant replies, and our team only steps in when a conversation
                    needs a human touch.
                  </p>
                  <div class="relative z-[2] ml-auto max-w-[60%] text-right md:max-w-[30%]">
                    <div class="text-[16px] font-semibold text-white">Amina Njoroge</div>
                    <div class="mt-1 text-[14px] text-white/80">Marketplace Operations Lead</div>
                  </div>
                </div>
                <div class="t-pane t-pane-3">
                  <svg class="mb-5 h-[60px] w-[60px]"><use href="#i-quote" /></svg>
                  <p class="mb-[50px] text-[22px] font-semibold leading-[1.5em] text-white md:text-[24px]">
                    Sokochat helped us stop repeating the same answers all day on WhatsApp. Our
                    buyers now get instant replies, and our team only steps in when a conversation
                    needs a human touch.
                  </p>
                  <div class="relative z-[2] ml-auto max-w-[60%] text-right md:max-w-[30%]">
                    <div class="text-[16px] font-semibold text-white">Amina Njoroge</div>
                    <div class="mt-1 text-[14px] text-white/80">Marketplace Operations Lead</div>
                  </div>
                </div>
                <div class="t-pane t-pane-4">
                  <svg class="mb-5 h-[60px] w-[60px]"><use href="#i-quote" /></svg>
                  <p class="mb-[50px] text-[22px] font-semibold leading-[1.5em] text-white md:text-[24px]">
                    Sokochat helped us stop repeating the same answers all day on WhatsApp. Our
                    buyers now get instant replies, and our team only steps in when a conversation
                    needs a human touch.
                  </p>
                  <div class="relative z-[2] ml-auto max-w-[60%] text-right md:max-w-[30%]">
                    <div class="text-[16px] font-semibold text-white">Amina Njoroge</div>
                    <div class="mt-1 text-[14px] text-white/80">Marketplace Operations Lead</div>
                  </div>
                </div>
              </div>
              <div class="t-menu mt-[-60px] flex items-center justify-start">
                <label
                  for="t1"
                  class="t-tab-1 -ml-5 cursor-pointer overflow-hidden rounded-full border-[3px] border-white first:ml-0"
                >
                  <img
                    src="https://images.unsplash.com/photo-1438761681033-6461ffad8d80?w=140&q=80"
                    alt="Amina Njoroge"
                    class="h-[50px] w-[50px] rounded-full object-cover md:h-[70px] md:w-[70px]"
                  />
                </label>
                <label
                  for="t2"
                  class="t-tab-2 -ml-5 cursor-pointer overflow-hidden rounded-full border-[3px] border-white"
                >
                  <img
                    src="https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=140&q=80"
                    alt="Amina Njoroge"
                    class="h-[50px] w-[50px] rounded-full object-cover md:h-[70px] md:w-[70px]"
                  />
                </label>
                <label
                  for="t3"
                  class="t-tab-3 -ml-5 cursor-pointer overflow-hidden rounded-full border-[3px] border-white"
                >
                  <img
                    src="https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=140&q=80"
                    alt="Amina Njoroge"
                    class="h-[50px] w-[50px] rounded-full object-cover md:h-[70px] md:w-[70px]"
                  />
                </label>
                <label
                  for="t4"
                  class="t-tab-4 -ml-5 cursor-pointer overflow-hidden rounded-full border-[3px] border-white"
                >
                  <img
                    src="https://images.unsplash.com/photo-1492562080023-ab3db95bfbce?w=140&q=80"
                    alt="Amina Njoroge"
                    class="h-[50px] w-[50px] rounded-full object-cover md:h-[70px] md:w-[70px]"
                  />
                </label>
              </div>
            </div>
          </div>

          <div class="grid grid-cols-2 justify-items-start gap-5 md:grid-cols-3 md:justify-items-center md:gap-[40px]">
            <div class="flex items-center gap-5">
              <div class="flex h-[80px] w-[80px] flex-none items-center justify-center rounded-full bg-white text-primary">
                <svg class="h-9 w-9"><use href="#i-users" /></svg>
              </div>
              <div>
                <h4 class="mb-0 font-semibold text-primary">24/7</h4>
                <h5 class="text-[20px] text-white">Buyer replies</h5>
              </div>
            </div>
            <div class="flex items-center gap-5">
              <div class="flex h-[80px] w-[80px] flex-none items-center justify-center rounded-full bg-white text-primary">
                <svg class="h-9 w-9"><use href="#i-usercheck" /></svg>
              </div>
              <div>
                <h4 class="mb-0 font-semibold text-primary">2</h4>
                <h5 class="text-[20px] text-white">Languages supported</h5>
              </div>
            </div>
            <div class="flex items-center gap-5">
              <div class="flex h-[80px] w-[80px] flex-none items-center justify-center rounded-full bg-white text-primary">
                <svg class="h-9 w-9"><use href="#i-award" /></svg>
              </div>
              <div>
                <h4 class="mb-0 font-semibold text-primary">0</h4>
                <h5 class="text-[20px] text-white">Code required</h5>
              </div>
            </div>
          </div>
        </div>
      </section>

      <section id="services" class="py-[40px] md:py-[80px]">
        <div class="container mx-auto max-w-[1200px] px-[15px] md:px-[30px]">
          <div class="mx-auto mb-[30px] max-w-full text-center md:mb-[50px] md:max-w-[80%]">
            <div class="mb-[15px] flex items-center justify-center gap-[5px] font-semibold">
              <svg class="h-5 w-5"><use href="#i-smile" /></svg>
              <div class="text-primary">How Sokochat helps</div>
            </div>
            <h2>Practical tools for real WhatsApp sales workflows</h2>
          </div>
          <div class="grid grid-cols-1 gap-[40px] md:grid-cols-2">
            <a
              href="#services"
              class="group flex flex-col items-start rounded-[10px] bg-lavender p-[30px] no-underline transition-transform duration-300 hover:translate-y-[10px] md:p-[40px]"
            >
              <div class="mb-[30px] grid h-[150px] w-[150px] place-items-center rounded-[20px] bg-white text-primary">
                <svg class="h-16 w-16"><use href="#i-share" /></svg>
              </div>
              <h3 class="text-[27px] text-primary">WhatsApp automation</h3>
              <p class="mb-[30px] md:mb-[40px]">
                Answer common buyer questions instantly and consistently, even outside business
                hours.
              </p>
              <div class="flex items-center justify-center gap-[10px] rounded-[10px] border border-white bg-white px-5 py-[15px] md:py-[18px]">
                <div class="text-primary">Learn more</div>
                <svg class="h-5 w-5 text-primary"><use href="#i-arrow" /></svg>
              </div>
            </a>
            <a
              href="#services"
              class="group flex flex-col items-start rounded-[10px] bg-lavender p-[30px] no-underline transition-transform duration-300 hover:translate-y-[10px] md:p-[40px]"
            >
              <div class="mb-[30px] grid h-[150px] w-[150px] place-items-center rounded-[20px] bg-white text-primary">
                <svg class="h-16 w-16"><use href="#i-megaphone" /></svg>
              </div>
              <h3 class="text-[27px] text-primary">Live data sync</h3>
              <p class="mb-[30px] md:mb-[40px]">
                Pull fresh product and business information from your existing endpoint on every
                conversation.
              </p>
              <div class="flex items-center justify-center gap-[10px] rounded-[10px] border border-white bg-white px-5 py-[15px] md:py-[18px]">
                <div class="text-primary">Learn more</div>
                <svg class="h-5 w-5 text-primary"><use href="#i-arrow" /></svg>
              </div>
            </a>
            <a
              href="#services"
              class="group flex flex-col items-start rounded-[10px] bg-lavender p-[30px] no-underline transition-transform duration-300 hover:translate-y-[10px] md:p-[40px]"
            >
              <div class="mb-[30px] grid h-[150px] w-[150px] place-items-center rounded-[20px] bg-white text-primary">
                <svg class="h-16 w-16"><use href="#i-trend" /></svg>
              </div>
              <h3 class="text-[27px] text-primary">AI instruction builder</h3>
              <p class="mb-[30px] md:mb-[40px]">
                Set the bot's tone, language, and sales behavior with simple written guidance.
              </p>
              <div class="flex items-center justify-center gap-[10px] rounded-[10px] border border-white bg-white px-5 py-[15px] md:py-[18px]">
                <div class="text-primary">Learn more</div>
                <svg class="h-5 w-5 text-primary"><use href="#i-arrow" /></svg>
              </div>
            </a>
            <a
              href="#services"
              class="group flex flex-col items-start rounded-[10px] bg-lavender p-[30px] no-underline transition-transform duration-300 hover:translate-y-[10px] md:p-[40px]"
            >
              <div class="mb-[30px] grid h-[150px] w-[150px] place-items-center rounded-[20px] bg-white text-primary">
                <svg class="h-16 w-16"><use href="#i-edit" /></svg>
              </div>
              <h3 class="text-[27px] text-primary">Smart CTA rules</h3>
              <p class="mb-[30px] md:mb-[40px]">
                Guide buyers to the right next action with links, calls, maps, lists, and direct
                WhatsApp handoff.
              </p>
              <div class="flex items-center justify-center gap-[10px] rounded-[10px] border border-white bg-white px-5 py-[15px] md:py-[18px]">
                <div class="text-primary">Learn more</div>
                <svg class="h-5 w-5 text-primary"><use href="#i-arrow" /></svg>
              </div>
            </a>
          </div>
        </div>
      </section>

      <section
        id="cases"
        class="bg-dark pb-[50px] pt-[50px] md:mb-[174px] md:pb-0 md:pt-[90px] lg:mb-0 lg:pb-[70px] xl:mb-[174px] xl:pb-0"
      >
        <div class="container mx-auto max-w-[1400px] px-[15px] md:px-[30px]">
          <div class="mb-[30px] max-w-full md:mb-[50px] md:max-w-[70%]">
            <div class="mb-[15px] flex items-center justify-start gap-[5px] font-semibold">
              <svg class="h-5 w-5"><use href="#i-smile" /></svg>
              <div class="text-white">Use cases</div>
            </div>
            <h2 class="text-white">Where Sokochat fits best</h2>
          </div>
          <div class="grid grid-cols-1 gap-[30px] md:grid-cols-2 xl:mb-[-172px] xl:grid-cols-3">
            <a
              href="#cases"
              class="group relative block h-[360px] overflow-hidden rounded-[10px] no-underline transition-shadow hover:shadow-[0_24px_55px_-19px_#5956e966] md:h-[440px]"
            >
              <img
                src="https://images.unsplash.com/photo-1533750349088-cd871a92f312?w=1080&q=80"
                alt="Marketplace seller support"
                class="h-full w-full object-cover"
              />
              <div class="absolute inset-x-5 bottom-5 rounded-[10px] bg-white p-5 text-center">
                <h3 class="mb-[10px] text-[20px] md:text-[22px]">Marketplace seller support</h3>
                <div class="text-dim">
                  Help buyers discover products, compare options, and reach the right seller faster.
                </div>
              </div>
            </a>
            <a
              href="#cases"
              class="group relative block h-[360px] overflow-hidden rounded-[10px] no-underline transition-shadow hover:shadow-[0_24px_55px_-19px_#5956e966] md:h-[440px]"
            >
              <img
                src="https://images.unsplash.com/photo-1542744173-8e7e53415bb0?w=1080&q=80"
                alt="Retail product enquiries"
                class="h-full w-full object-cover"
              />
              <div class="absolute inset-x-5 bottom-5 rounded-[10px] bg-white p-5 text-center">
                <h3 class="mb-[10px] text-[20px] md:text-[22px]">Retail product enquiries</h3>
                <div class="text-dim">
                  Answer questions about price, stock, delivery, and location without making
                  customers wait.
                </div>
              </div>
            </a>
            <a
              href="#cases"
              class="group relative block h-[360px] overflow-hidden rounded-[10px] no-underline transition-shadow hover:shadow-[0_24px_55px_-19px_#5956e966] md:col-span-2 md:h-[440px] xl:col-span-1"
            >
              <img
                src="https://images.unsplash.com/photo-1611926653458-09294b3142bf?w=1080&q=80"
                alt="Lead qualification on WhatsApp"
                class="h-full w-full object-cover"
              />
              <div class="absolute inset-x-5 bottom-5 rounded-[10px] bg-white p-5 text-center">
                <h3 class="mb-[10px] text-[20px] md:text-[22px]">Lead qualification on WhatsApp</h3>
                <div class="text-dim">
                  Handle repeated pre-sales questions automatically so your team can focus on serious
                  buyers.
                </div>
              </div>
            </a>
          </div>
        </div>
      </section>

      <section class="relative overflow-hidden pt-[50px] md:pt-[70px]">
        <div class="container mx-auto max-w-[1400px] px-[15px] md:px-[30px]">
          <div class="grid grid-cols-1 items-center gap-[50px] lg:grid-cols-[.75fr_1fr] lg:gap-[70px]">
            <div class="relative">
              <img
                src="https://images.unsplash.com/photo-1531746020798-e6953c6e8e04?w=1080&q=80"
                alt="Customer browsing WhatsApp offers"
                class="aspect-square w-full rounded-full object-cover"
              />
              <svg class="absolute bottom-[86px] left-[-8px] h-[60px] w-[60px] md:left-[-24px]">
                <use href="#i-tw" />
              </svg>
              <svg class="absolute bottom-[110px] right-0 h-[60px] w-[60px]">
                <use href="#i-like" />
              </svg>
              <svg class="absolute right-[120px] top-[9px] h-[50px] w-[50px]">
                <use href="#i-heart" />
              </svg>
            </div>
            <div class="flex flex-wrap items-center justify-center gap-[15px]">
              <a
                href="#services"
                class="rounded-[10px] bg-lavender p-[15px] text-center no-underline transition-shadow hover:shadow-[0_24px_55px_-19px_#5956e966]"
              >
                <svg class="mx-auto mb-[30px] h-[60px] w-[60px]"><use href="#i-fb" /></svg>
                <h4 class="text-[20px] text-primary">Links</h4>
              </a>
              <a
                href="#services"
                class="rounded-[10px] bg-lavender p-[15px] text-center no-underline transition-shadow hover:shadow-[0_24px_55px_-19px_#5956e966]"
              >
                <svg class="mx-auto mb-[30px] h-[60px] w-[60px]"><use href="#i-ig" /></svg>
                <h4 class="text-[20px] text-primary">Click-to-call</h4>
              </a>
              <a
                href="#services"
                class="rounded-[10px] bg-lavender p-[15px] text-center no-underline transition-shadow hover:shadow-[0_24px_55px_-19px_#5956e966]"
              >
                <svg class="mx-auto mb-[30px] h-[60px] w-[60px]"><use href="#i-li" /></svg>
                <h4 class="text-[20px] text-primary">WhatsApp handoff</h4>
              </a>
              <a
                href="#services"
                class="rounded-[10px] bg-lavender p-[15px] text-center no-underline transition-shadow hover:shadow-[0_24px_55px_-19px_#5956e966]"
              >
                <svg class="mx-auto mb-[30px] h-[60px] w-[60px]"><use href="#i-tw" /></svg>
                <h4 class="text-[20px] text-primary">Maps</h4>
              </a>
              <a
                href="#services"
                class="rounded-[10px] bg-lavender p-[15px] text-center no-underline transition-shadow hover:shadow-[0_24px_55px_-19px_#5956e966]"
              >
                <svg class="mx-auto mb-[30px] h-[60px] w-[60px]"><use href="#i-yt" /></svg>
                <h4 class="text-[20px] text-primary">Product lists</h4>
              </a>
            </div>
          </div>
        </div>
      </section>

      <section id="blog" class="relative overflow-hidden py-[40px] md:py-[80px]">
        <div class="container mx-auto max-w-[1400px] px-[15px] md:px-[30px]">
          <div class="mb-[30px] max-w-full md:mb-[50px] md:max-w-[70%]">
            <div class="mb-[15px] flex items-center justify-start gap-[5px] font-semibold">
              <svg class="h-5 w-5"><use href="#i-smile" /></svg>
              <div class="text-primary">Ready to launch</div>
            </div>
            <h2>Create your first Sokochat workspace in minutes</h2>
          </div>
          <div class="grid grid-cols-1 gap-[40px] md:grid-cols-2">
            <a href="#contact" class="block no-underline">
              <div class="mb-5 overflow-hidden rounded-[10px]">
                <img
                  src="https://images.unsplash.com/photo-1626785774573-4b799315345d?w=1080&q=80"
                  alt="Create account"
                  class="h-full w-full object-cover"
                />
              </div>
              <h3 class="mb-0 text-[20px] font-semibold leading-[1.3em] text-dark lg:text-[22px]">
                Start with one WhatsApp number, one live data source, and one bot your team can test
                before going live.
              </h3>
              <div class="mt-[15px] flex flex-wrap justify-between gap-[15px]">
                <div class="flex items-center gap-[5px] text-[14px]">
                  <svg class="h-5 w-5 text-primary"><use href="#i-calendar" /></svg>
                  <div>Create account</div>
                </div>
                <div class="flex items-center gap-[5px] text-[14px]">
                  <svg class="h-5 w-5 text-primary"><use href="#i-tag" /></svg>
                  <div>Start building</div>
                </div>
              </div>
            </a>
            <div class="flex flex-col items-start gap-5">
              <a
                href="#contact"
                class="grid w-full grid-cols-2 gap-5 no-underline md:grid-cols-[.5fr_1fr] md:gap-[30px]"
              >
                <div class="overflow-hidden rounded-[10px]">
                  <img
                    src="https://images.unsplash.com/photo-1432888622747-4eb9a8efeb07?w=700&q=80"
                    alt="Talk to sales"
                    class="h-full w-full object-cover"
                  />
                </div>
                <div>
                  <h4 class="mb-0 text-[20px] font-semibold leading-[1.3em] text-dark">
                    Talk to sales
                  </h4>
                  <div class="mt-[10px] flex flex-wrap gap-[10px] md:mt-[15px] md:gap-[15px]">
                    <div class="flex items-center gap-[5px] text-[14px]">
                      <svg class="h-4 w-4 text-primary"><use href="#i-calendar" /></svg>
                      <div>Book a walkthrough</div>
                    </div>
                    <div class="flex items-center gap-[5px] text-[14px]">
                      <svg class="h-4 w-4 text-primary"><use href="#i-tag" /></svg>
                      <div>Open playground</div>
                    </div>
                  </div>
                </div>
              </a>
              <a
                href="mailto:hello@sokochat.com"
                class="grid w-full grid-cols-2 gap-5 no-underline md:grid-cols-[.5fr_1fr] md:gap-[30px]"
              >
                <div class="overflow-hidden rounded-[10px]">
                  <img
                    src="https://images.unsplash.com/photo-1460925895917-afdab827c52f?w=700&q=80"
                    alt="Email Sokochat"
                    class="h-full w-full object-cover"
                  />
                </div>
                <div>
                  <h4 class="mb-0 text-[20px] font-semibold leading-[1.3em] text-dark">
                    hello@sokochat.com
                  </h4>
                  <div class="mt-[10px] flex flex-wrap gap-[10px] md:mt-[15px] md:gap-[15px]">
                    <div class="flex items-center gap-[5px] text-[14px]">
                      <svg class="h-4 w-4 text-primary"><use href="#i-calendar" /></svg>
                      <div>+254 700 000 000</div>
                    </div>
                    <div class="flex items-center gap-[5px] text-[14px]">
                      <svg class="h-4 w-4 text-primary"><use href="#i-tag" /></svg>
                      <div>Nairobi, Kenya</div>
                    </div>
                  </div>
                </div>
              </a>
              <a
                href="#contact"
                class="grid w-full grid-cols-2 gap-5 no-underline md:grid-cols-[.5fr_1fr] md:gap-[30px]"
              >
                <div class="overflow-hidden rounded-[10px]">
                  <img
                    src="https://images.unsplash.com/photo-1542435503-956c469947f6?w=700&q=80"
                    alt="Launch your bot"
                    class="h-full w-full object-cover"
                  />
                </div>
                <div>
                  <h4 class="mb-0 text-[20px] font-semibold leading-[1.3em] text-dark">
                    Launch your bot
                  </h4>
                  <div class="mt-[10px] flex flex-wrap gap-[10px] md:mt-[15px] md:gap-[15px]">
                    <div class="flex items-center gap-[5px] text-[14px]">
                      <svg class="h-4 w-4 text-primary"><use href="#i-calendar" /></svg>
                      <div>Get started</div>
                    </div>
                    <div class="flex items-center gap-[5px] text-[14px]">
                      <svg class="h-4 w-4 text-primary"><use href="#i-tag" /></svg>
                      <div>Launch your bot</div>
                    </div>
                  </div>
                </div>
              </a>
            </div>
          </div>
        </div>
      </section>

      <footer id="contact" class="bg-dark pb-[20px] pt-[60px] md:pb-[40px]">
        <div class="container mx-auto max-w-[1400px] px-[15px] md:px-[30px]">
          <div class="mb-5 grid grid-cols-1 gap-[40px] md:mb-[40px] lg:grid-cols-[.5fr_1fr] xl:grid-cols-[.25fr_1fr]">
            <div class="relative text-center">
              <img
                src="https://images.unsplash.com/photo-1611605698335-8b1569810432?w=600&q=80"
                alt=""
                class="rounded-[10px]"
              />
              <svg class="absolute left-[-3px] top-[-5px] h-10 w-10"><use href="#i-fb" /></svg>
              <svg class="absolute right-[-8px] top-[89px] h-10 w-10"><use href="#i-wa" /></svg>
              <svg class="absolute bottom-[-24px] right-[103px] h-10 w-10 md:bottom-[62px]">
                <use href="#i-li" />
              </svg>
            </div>
            <div>
              <a
                href="#"
                aria-label="Sokochat home"
                class="mb-2 inline-flex items-center gap-2 no-underline"
              >
                <span class="grid h-9 w-9 place-items-center rounded-lg bg-primary font-head text-lg font-extrabold text-white">
                  S
                </span>
                <span class="font-head text-2xl font-extrabold text-white">Sokochat</span>
              </a>
              <p class="my-[40px] text-smoke">
                Sokochat helps businesses automate WhatsApp sales conversations using live data and
                no-code AI setup.
              </p>
              <div class="mb-[40px] flex gap-5">
                <a
                  href="https://www.facebook.com/"
                  target="_blank"
                  rel="noopener"
                  aria-label="Facebook"
                >
                  <svg class="h-[30px] w-[30px]"><use href="#i-fb" /></svg>
                </a>
                <a
                  href="https://www.instagram.com/"
                  target="_blank"
                  rel="noopener"
                  aria-label="Instagram"
                >
                  <svg class="h-[30px] w-[30px]"><use href="#i-ig" /></svg>
                </a>
                <a
                  href="https://www.linkedin.com/"
                  target="_blank"
                  rel="noopener"
                  aria-label="LinkedIn"
                >
                  <svg class="h-[30px] w-[30px]"><use href="#i-li" /></svg>
                </a>
                <a href="https://twitter.com/" target="_blank" rel="noopener" aria-label="Twitter">
                  <svg class="h-[30px] w-[30px]"><use href="#i-tw" /></svg>
                </a>
              </div>
              <div class="grid grid-cols-1 gap-[30px] md:grid-cols-2 lg:gap-[70px]">
                <div>
                  <h6 class="mb-[15px] text-[20px] text-white">Pages</h6>
                  <div class="grid grid-cols-2 gap-[30px] sm:grid-cols-2 lg:gap-[70px]">
                    <div class="flex flex-col gap-[15px]">
                      <a href="#" class="text-smoke no-underline transition-colors hover:text-primary">
                        Home
                      </a>
                      <a
                        href="#features"
                        class="text-smoke no-underline transition-colors hover:text-primary"
                      >
                        Features
                      </a>
                      <a
                        href="#cases"
                        class="text-smoke no-underline transition-colors hover:text-primary"
                      >
                        Use Cases
                      </a>
                    </div>
                    <div class="flex flex-col gap-[15px]">
                      <a
                        href="#contact"
                        class="text-smoke no-underline transition-colors hover:text-primary"
                      >
                        Contact
                      </a>
                      <a
                        href="#contact"
                        class="text-smoke no-underline transition-colors hover:text-primary"
                      >
                        Privacy Policy
                      </a>
                      <a
                        href="#contact"
                        class="text-smoke no-underline transition-colors hover:text-primary"
                      >
                        Terms
                      </a>
                    </div>
                  </div>
                </div>
                <div>
                  <h6 class="mb-[15px] text-[20px] text-white">Contact</h6>
                  <div class="grid grid-cols-1 gap-[15px]">
                    <a
                      href="mailto:hello@sokochat.com"
                      class="text-smoke no-underline transition-colors hover:text-primary"
                    >
                      hello@sokochat.com
                    </a>
                    <a
                      href="tel:+254700000000"
                      class="text-smoke no-underline transition-colors hover:text-primary"
                    >
                      +254 700 000 000
                    </a>
                    <div class="text-smoke">Nairobi, Kenya</div>
                  </div>
                </div>
              </div>
            </div>
          </div>
          <div class="flex flex-wrap justify-between gap-5 border-t border-white/10 pt-[30px] text-white">
            <p class="mb-0">AI-powered WhatsApp sales assistants</p>
            <p class="mb-0">
              Built for merchants, marketplaces, and growing teams across East Africa
            </p>
          </div>
        </div>
      </footer>
    </div>
    """
  end

  defp svg_defs(assigns) do
    ~H"""
    <svg width="0" height="0" class="hidden" aria-hidden="true">
      <symbol id="i-smile" viewBox="0 0 24 24">
        <circle cx="12" cy="12" r="11" fill="#FFC83D" />
        <circle cx="8.5" cy="9.5" r="1.4" fill="#7A4A00" />
        <circle cx="15.5" cy="9.5" r="1.4" fill="#7A4A00" />
        <path
          d="M7 14a5 5 0 0 0 10 0"
          fill="none"
          stroke="#7A4A00"
          stroke-width="1.6"
          stroke-linecap="round"
        />
      </symbol>
      <symbol id="i-fb" viewBox="0 0 24 24">
        <rect width="24" height="24" rx="6" fill="#1877F2" />
        <path
          d="M15.4 12.5h-2v7h-3v-7H8.9V10h1.5V8.3c0-1.9 1.1-2.9 2.8-2.9.8 0 1.6.1 1.6.1v2h-.9c-.9 0-1.2.5-1.2 1.1V10h2.1l-.4 2.5Z"
          fill="#fff"
        />
      </symbol>
      <symbol id="i-ig" viewBox="0 0 24 24">
        <rect width="24" height="24" rx="6" fill="#E1306C" />
        <rect
          x="5.5"
          y="5.5"
          width="13"
          height="13"
          rx="4"
          fill="none"
          stroke="#fff"
          stroke-width="1.7"
        />
        <circle cx="12" cy="12" r="3.2" fill="none" stroke="#fff" stroke-width="1.7" />
        <circle cx="16.2" cy="7.8" r="1.1" fill="#fff" />
      </symbol>
      <symbol id="i-tw" viewBox="0 0 24 24">
        <rect width="24" height="24" rx="6" fill="#1DA1F2" />
        <path
          d="M18.5 8.3c-.5.2-1 .4-1.5.4.5-.3.9-.8 1.1-1.4-.5.3-1.1.5-1.7.6a2.6 2.6 0 0 0-4.5 1.8c0 .2 0 .4.1.6-2.2-.1-4.2-1.2-5.5-2.8-.2.4-.3.8-.3 1.3 0 .9.5 1.7 1.2 2.2-.4 0-.8-.1-1.2-.3 0 1.3.9 2.4 2.1 2.6-.2.1-.5.1-.7.1h-.5c.3 1 1.3 1.8 2.4 1.8a5.3 5.3 0 0 1-3.9 1.1c1.1.7 2.5 1.1 3.9 1.1 4.7 0 7.2-3.9 7.2-7.2v-.3c.5-.4.9-.8 1.2-1.3Z"
          fill="#fff"
        />
      </symbol>
      <symbol id="i-yt" viewBox="0 0 24 24">
        <rect width="24" height="24" rx="6" fill="#FF0000" />
        <path d="M10 9l5 3-5 3V9Z" fill="#fff" />
      </symbol>
      <symbol id="i-li" viewBox="0 0 24 24">
        <rect width="24" height="24" rx="6" fill="#0A66C2" />
        <path
          d="M8.1 9.8H6V18h2.1V9.8ZM7 6.4a1.2 1.2 0 1 0 0 2.4 1.2 1.2 0 0 0 0-2.4ZM18 18h-2.1v-4.3c0-1-.4-1.7-1.3-1.7-.7 0-1.1.5-1.3 1-.1.2-.1.4-.1.7V18H11s0-7.4 0-8.2h2.1v1.2c.3-.5.8-1.2 2-1.2 1.5 0 2.6 1 2.6 3V18Z"
          fill="#fff"
        />
      </symbol>
      <symbol id="i-wa" viewBox="0 0 24 24">
        <rect width="24" height="24" rx="6" fill="#25D366" />
        <path
          d="M12 6.2A5.8 5.8 0 0 0 7 15l-.8 2.8 2.9-.8A5.8 5.8 0 1 0 12 6.2Zm0 1.4a4.4 4.4 0 0 1 3.7 6.8l.1.1-.5 1.6-1.6-.5A4.4 4.4 0 1 1 12 7.6Zm-1.7 2c-.1 0-.3 0-.4.2-.2.2-.6.5-.6 1.3s.6 1.5.7 1.6c.1.1 1.2 1.9 3 2.5 1.4.5 1.7.4 2 .4.4 0 1-.4 1.1-.8.1-.4.1-.7.1-.8 0-.1-.2-.1-.3-.2l-1.1-.5c-.1-.1-.3-.1-.4.1l-.4.5c-.1.1-.2.1-.3.1-.2-.1-.7-.3-1.4-.9-.5-.5-.9-1-1-1.2-.1-.2 0-.3 0-.4l.3-.3c.1-.1.1-.2.2-.3 0-.1 0-.2 0-.3l-.5-1.2c-.1-.3-.2-.3-.4-.3h-.4Z"
          fill="#fff"
        />
      </symbol>
      <symbol id="i-heart" viewBox="0 0 24 24">
        <path
          d="M12 21s-7-4.5-9.5-9C1 9 2.5 5.5 6 5.5c2 0 3.2 1.2 4 2.3.8-1.1 2-2.3 4-2.3 3.5 0 5 3.5 3.5 6.5C19 16.5 12 21 12 21Z"
          fill="#FF4D67"
        />
      </symbol>
      <symbol id="i-like" viewBox="0 0 24 24">
        <path
          d="M7 10H4v9h3v-9Zm2 0 3.2-6.4c.6 0 1.8.4 1.8 2V8h4.3c1 0 1.8.9 1.6 1.9l-1.3 6.6c-.2.9-1 1.5-1.9 1.5H9V10Z"
          fill="#1877F2"
        />
      </symbol>
      <symbol
        id="i-target"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <circle cx="12" cy="12" r="9" /><circle cx="12" cy="12" r="5" /><circle
          cx="12"
          cy="12"
          r="1.5"
        />
      </symbol>
      <symbol
        id="i-check"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path d="M22 11.1V12a10 10 0 1 1-5.9-9.1" /><path d="M22 4 12 14l-3-3" />
      </symbol>
      <symbol
        id="i-users"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="M23 21v-2a4 4 0 0 0-3-3.9" /><path d="M16 3.1a4 4 0 0 1 0 7.8" />
      </symbol>
      <symbol
        id="i-usercheck"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" /><circle cx="9" cy="7" r="4" /><path d="m16 11 2 2 4-4" />
      </symbol>
      <symbol
        id="i-award"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <circle cx="12" cy="8" r="6" /><path d="m8.2 13.9-1.2 7 5-3 5 3-1.2-7" />
      </symbol>
      <symbol
        id="i-arrow"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <line x1="5" y1="12" x2="19" y2="12" /><polyline points="12 5 19 12 12 19" />
      </symbol>
      <symbol
        id="i-calendar"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <rect x="3" y="4" width="18" height="18" rx="2" /><line x1="16" y1="2" x2="16" y2="6" /><line
          x1="8"
          y1="2"
          x2="8"
          y2="6"
        /><line x1="3" y1="10" x2="21" y2="10" />
      </symbol>
      <symbol
        id="i-tag"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path d="M20.6 13.4 12 22l-9-9V3h10l8.6 8.6a1 1 0 0 1 0 1.4Z" /><circle
          cx="7.5"
          cy="7.5"
          r="1.2"
          fill="currentColor"
          stroke="none"
        />
      </symbol>
      <symbol
        id="i-share"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <circle cx="18" cy="5" r="3" /><circle cx="6" cy="12" r="3" /><circle cx="18" cy="19" r="3" /><line
          x1="8.6"
          y1="13.5"
          x2="15.4"
          y2="17.5"
        /><line x1="15.4" y1="6.5" x2="8.6" y2="10.5" />
      </symbol>
      <symbol
        id="i-megaphone"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path d="m3 11 14-6v14L3 13v-2Z" /><path d="M3 11v2a3 3 0 0 0 3 3h1" /><path d="M8 16v3a1 1 0 0 0 1 1h2" /><path d="M20 9a3 3 0 0 1 0 6" />
      </symbol>
      <symbol
        id="i-trend"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <polyline points="22 7 13.5 15.5 8.5 10.5 2 17" /><polyline points="16 7 22 7 22 13" />
      </symbol>
      <symbol
        id="i-edit"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path d="M12 20h9" /><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4 12.5-12.5Z" />
      </symbol>
      <symbol
        id="i-zap"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2" />
      </symbol>
      <symbol
        id="i-compass"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <circle cx="12" cy="12" r="10" /><polygon points="16.2 7.8 14 14 7.8 16.2 10 10 16.2 7.8" />
      </symbol>
      <symbol
        id="i-bulb"
        viewBox="0 0 24 24"
        fill="none"
        stroke="currentColor"
        stroke-width="2"
        stroke-linecap="round"
        stroke-linejoin="round"
      >
        <path d="M9 18h6" /><path d="M10 21h4" /><path d="M12 3a6 6 0 0 0-4 10.5c.7.7 1 1.3 1 2.5h6c0-1.2.3-1.8 1-2.5A6 6 0 0 0 12 3Z" />
      </symbol>
      <symbol id="i-quote" viewBox="0 0 24 24">
        <path
          d="M7 7H4v6h3c0 2-1 3-3 3v2c3.3 0 5-2.2 5-5.5V7H7Zm9 0h-3v6h3c0 2-1 3-3 3v2c3.3 0 5-2.2 5-5.5V7h-2Z"
          fill="#5956e9"
        />
      </symbol>
      <symbol id="stars" viewBox="0 0 120 24">
        <g fill="#FFC83D">
          <path d="M12 2l2.9 6 6.6.5-5 4.3 1.6 6.4L12 16.3 5.9 19.2 7.5 12.8l-5-4.3L9.1 8z" />
          <path d="M36 2l2.9 6 6.6.5-5 4.3 1.6 6.4L36 16.3 29.9 19.2 31.5 12.8l-5-4.3L33.1 8z" />
          <path d="M60 2l2.9 6 6.6.5-5 4.3 1.6 6.4L60 16.3 53.9 19.2 55.5 12.8l-5-4.3L57.1 8z" />
          <path d="M84 2l2.9 6 6.6.5-5 4.3 1.6 6.4L84 16.3 77.9 19.2 79.5 12.8l-5-4.3L81.1 8z" />
          <path d="M108 2l2.9 6 6.6.5-5 4.3 1.6 6.4L108 16.3 101.9 19.2 103.5 12.8l-5-4.3L105.1 8z" />
        </g>
      </symbol>
    </svg>
    """
  end
end
