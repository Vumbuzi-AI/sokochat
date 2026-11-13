defmodule SokochatWeb.HomeLive.LandingSections do
  @moduledoc "Landing sections from Doop frame Wd4XKF8zcx."
  use SokochatWeb, :html

  attr :current_user, :map, default: nil

  def page(assigns) do
    ~H"""
    <div class="soko-landing">
      <section id="features" class="landing-features" style="padding:96px 0 64px">
        <div class="wrap" style="display:flex;flex-direction:column;gap:40px">
          <header style="display:flex;flex-direction:column;gap:12px;align-items:center;text-align:center">
            <h2 class="h2">From the first message to a paid order</h2>
            <p class="lead" style="max-width:none">
              Tools for the conversations, products and orders behind your store.
            </p>
          </header>
          <div style="display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:24px">
            <article style="position:relative;height:480px;overflow:hidden;border-radius:24px;background:#8b9284">
              <div class="fphone">
                <div class="fscreen">
                  <div class="fstatus">
                    <span>9:41</span><span style="display:flex;gap:4px;align-items:center"><svg
                      width="15"
                      height="11"
                      viewBox="0 0 20 14"
                      fill="currentColor"
                      aria-hidden="true"
                    ><rect x="0" y="9" width="3" height="5" rx=".6" /><rect
                      x="5"
                      y="6"
                      width="3"
                      height="8"
                      rx=".6"
                    /><rect x="10" y="3" width="3" height="11" rx=".6" /><rect
                      x="15"
                      width="3"
                      height="14"
                      rx=".6"
                    /></svg><svg
                      width="14"
                      height="11"
                      viewBox="0 0 20 15"
                      fill="currentColor"
                      aria-hidden="true"
                    ><path d="M0 4a16 16 0 0 1 20 0l-2.4 2.5a12.5 12.5 0 0 0-15.2 0Zm4.1 4.2a9 9 0 0 1 11.8 0l-2.4 2.5a5.5 5.5 0 0 0-7 0Zm3.5 3.6a3.5 3.5 0 0 1 4.8 0L10 15Z" /></svg><svg
                      width="22"
                      height="11"
                      viewBox="0 0 30 14"
                      aria-hidden="true"
                    ><rect
                      x=".5"
                      y="1"
                      width="25"
                      height="12"
                      rx="3"
                      fill="none"
                      stroke="currentColor"
                      opacity=".4"
                    /><rect x="2.5" y="3" width="21" height="8" rx="1.5" fill="currentColor" /><path
                      d="M27 4v6c2 0 2-6 0-6"
                      fill="currentColor"
                      opacity=".4"
                    /></svg></span>
                  </div>
                  <div class="fchat">
                    <span class="fdate">Today</span>
                    <div class="fb fout">
                      <span>Hi! Can I see the Nike Shox?</span><span class="fmeta">9:41 <svg
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="2.2"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        aria-hidden="true"
                      ><path d="m2 12 4 4L16 6m-4 9 2 2L24 7" /></svg></span>
                    </div>
                    <div class="fb fin">
                      <span>Yes. Here is the pair.</span><span class="fmeta">9:41</span>
                    </div>
                    <div class="fprod">
                      <img src={~p"/images/nike-shox.webp"} loading="lazy" alt="" />
                      <div><strong>Nike Shox</strong><span>KES 8,500 · EU 40 to 43</span></div>
                    </div>
                  </div>
                </div>
                <img class="fbezel" src={~p"/images/iphone-15.png"} loading="lazy" alt="" />
              </div>
              <div class="fblur" aria-hidden="true">
                <span></span><span></span><span></span><span></span>
              </div>
              <div style="position:absolute;inset:auto 0 0;z-index:1;padding:32px;color:#fff">
                <h3 style="font-size:28px;font-weight:600;letter-spacing:-.03em;line-height:1.15">
                  A storefront on WhatsApp
                </h3>
                <p style="margin-top:8px;max-width:40ch;font-size:16px;line-height:1.5;color:rgb(255 255 255 / .82)">
                  Buyers browse the catalogue and place the order in the chat.
                </p>
              </div>
            </article>
            <article style="position:relative;height:480px;overflow:hidden;border-radius:24px;background:#171717">
              <img
                src={~p"/images/landing-vendor.webp"}
                loading="lazy"
                alt="A vendor working at a laptop"
                style="position:absolute;inset:0;width:100%;height:100%;object-fit:cover;object-position:50% 30%"
              />
              <div style="position:absolute;inset:auto 0 0;padding:32px;color:#fff;background:linear-gradient(to top,rgb(0 0 0 / .62),rgb(0 0 0 / 0) 100%)">
                <h3 style="font-size:28px;font-weight:600;letter-spacing:-.03em;line-height:1.15">
                  Keep your catalog current
                </h3>
                <p style="margin-top:8px;max-width:40ch;font-size:16px;line-height:1.5;color:rgb(255 255 255 / .82)">
                  Manage products, prices and stock from your vendor workspace.
                </p>
              </div>
            </article>
            <article style="position:relative;height:480px;overflow:hidden;border-radius:24px;background:#171717">
              <img
                src={~p"/images/landing-customer.webp"}
                loading="lazy"
                alt="A customer smiling at a message"
                style="position:absolute;inset:0;width:100%;height:100%;object-fit:cover;object-position:50% 6%"
              />
              <div style="position:absolute;inset:auto 0 0;padding:32px;color:#fff;background:linear-gradient(to top,rgb(0 0 0 / .62),rgb(0 0 0 / 0) 100%)">
                <h3 style="font-size:28px;font-weight:600;letter-spacing:-.03em;line-height:1.15">
                  Reach customers again
                </h3>
                <p style="margin-top:8px;max-width:40ch;font-size:16px;line-height:1.5;color:rgb(255 255 255 / .82)">
                  Send targeted campaigns and broadcasts with message templates.
                </p>
              </div>
            </article>
            <article style="position:relative;height:480px;overflow:hidden;border-radius:24px;background:#e7e4dc">
              <div class="fphone">
                <div class="fscreen">
                  <div class="fstatus">
                    <span>9:41</span><span style="display:flex;gap:4px;align-items:center"><svg
                      width="15"
                      height="11"
                      viewBox="0 0 20 14"
                      fill="currentColor"
                      aria-hidden="true"
                    ><rect x="0" y="9" width="3" height="5" rx=".6" /><rect
                      x="5"
                      y="6"
                      width="3"
                      height="8"
                      rx=".6"
                    /><rect x="10" y="3" width="3" height="11" rx=".6" /><rect
                      x="15"
                      width="3"
                      height="14"
                      rx=".6"
                    /></svg><svg
                      width="14"
                      height="11"
                      viewBox="0 0 20 15"
                      fill="currentColor"
                      aria-hidden="true"
                    ><path d="M0 4a16 16 0 0 1 20 0l-2.4 2.5a12.5 12.5 0 0 0-15.2 0Zm4.1 4.2a9 9 0 0 1 11.8 0l-2.4 2.5a5.5 5.5 0 0 0-7 0Zm3.5 3.6a3.5 3.5 0 0 1 4.8 0L10 15Z" /></svg><svg
                      width="22"
                      height="11"
                      viewBox="0 0 30 14"
                      aria-hidden="true"
                    ><rect
                      x=".5"
                      y="1"
                      width="25"
                      height="12"
                      rx="3"
                      fill="none"
                      stroke="currentColor"
                      opacity=".4"
                    /><rect x="2.5" y="3" width="21" height="8" rx="1.5" fill="currentColor" /><path
                      d="M27 4v6c2 0 2-6 0-6"
                      fill="currentColor"
                      opacity=".4"
                    /></svg></span>
                  </div>
                  <div class="fchat">
                    <span class="fdate">Today</span>
                    <div class="fb fout">
                      <span>I did not finish my order yesterday.</span><span class="fmeta">9:41 <svg
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="2.2"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        aria-hidden="true"
                      ><path d="m2 12 4 4L16 6m-4 9 2 2L24 7" /></svg></span>
                    </div>
                    <div class="fb fin">
                      <span>Your Adidas Spezial is still here. Ready to continue?</span><span class="fmeta">9:41</span>
                    </div>
                    <div class="fprod">
                      <img src={~p"/images/adidas-spezial.webp"} loading="lazy" alt="" />
                      <div><strong>Adidas Spezial</strong><span>KES 6,500 · EU 42</span></div>
                    </div>
                  </div>
                </div>
                <img class="fbezel" src={~p"/images/iphone-15.png"} loading="lazy" alt="" />
              </div>
              <div class="fblur" aria-hidden="true">
                <span></span><span></span><span></span><span></span>
              </div>
              <div style="position:absolute;inset:auto 0 0;z-index:1;padding:32px;color:#fff">
                <h3 style="font-size:28px;font-weight:600;letter-spacing:-.03em;line-height:1.15">
                  Recover an unfinished order
                </h3>
                <p style="margin-top:8px;max-width:40ch;font-size:16px;line-height:1.5;color:rgb(255 255 255 / .82)">
                  The pair is still in the chat when the buyer comes back.
                </p>
              </div>
            </article>
            <article style="position:relative;height:480px;overflow:hidden;border-radius:24px;background:#8b9284">
              <div class="fphone">
                <div class="fscreen">
                  <div class="fstatus">
                    <span>9:41</span><span style="display:flex;gap:4px;align-items:center"><svg
                      width="15"
                      height="11"
                      viewBox="0 0 20 14"
                      fill="currentColor"
                      aria-hidden="true"
                    ><rect x="0" y="9" width="3" height="5" rx=".6" /><rect
                      x="5"
                      y="6"
                      width="3"
                      height="8"
                      rx=".6"
                    /><rect x="10" y="3" width="3" height="11" rx=".6" /><rect
                      x="15"
                      width="3"
                      height="14"
                      rx=".6"
                    /></svg><svg
                      width="14"
                      height="11"
                      viewBox="0 0 20 15"
                      fill="currentColor"
                      aria-hidden="true"
                    ><path d="M0 4a16 16 0 0 1 20 0l-2.4 2.5a12.5 12.5 0 0 0-15.2 0Zm4.1 4.2a9 9 0 0 1 11.8 0l-2.4 2.5a5.5 5.5 0 0 0-7 0Zm3.5 3.6a3.5 3.5 0 0 1 4.8 0L10 15Z" /></svg><svg
                      width="22"
                      height="11"
                      viewBox="0 0 30 14"
                      aria-hidden="true"
                    ><rect
                      x=".5"
                      y="1"
                      width="25"
                      height="12"
                      rx="3"
                      fill="none"
                      stroke="currentColor"
                      opacity=".4"
                    /><rect x="2.5" y="3" width="21" height="8" rx="1.5" fill="currentColor" /><path
                      d="M27 4v6c2 0 2-6 0-6"
                      fill="currentColor"
                      opacity=".4"
                    /></svg></span>
                  </div>
                  <div class="fchat">
                    <span class="fdate">Today</span>
                    <div class="fb fout">
                      <span>What would you suggest?</span><span class="fmeta">9:41 <svg
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="2.2"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        aria-hidden="true"
                      ><path d="m2 12 4 4L16 6m-4 9 2 2L24 7" /></svg></span>
                    </div>
                    <div class="fb fin">
                      <span>The Onitsuka Tigers. KES 7,500, five EU sizes.</span><span class="fmeta">9:41</span>
                    </div>
                    <div class="fprod">
                      <img src={~p"/images/onitsuka-tigers.webp"} loading="lazy" alt="" />
                      <div><strong>Onitsuka Tigers</strong><span>KES 7,500 · EU 38 to 42</span></div>
                    </div>
                  </div>
                </div>
                <img class="fbezel" src={~p"/images/iphone-15.png"} loading="lazy" alt="" />
              </div>
              <div class="fblur" aria-hidden="true">
                <span></span><span></span><span></span><span></span>
              </div>
              <div style="position:absolute;inset:auto 0 0;z-index:1;padding:32px;color:#fff">
                <h3 style="font-size:28px;font-weight:600;letter-spacing:-.03em;line-height:1.15">
                  Answer product questions
                </h3>
                <p style="margin-top:8px;max-width:40ch;font-size:16px;line-height:1.5;color:rgb(255 255 255 / .82)">
                  Sokochat replies with the product and the KES price from the catalogue.
                </p>
              </div>
            </article>
            <article style="position:relative;height:480px;overflow:hidden;border-radius:24px;background:#171717">
              <img
                src={~p"/images/landing-fulfillment.webp"}
                loading="lazy"
                alt="A customer checking an order on her phone"
                style="position:absolute;inset:0;width:100%;height:100%;object-fit:cover;object-position:50% 30%"
              />
              <div style="position:absolute;inset:auto 0 0;padding:32px;color:#fff;background:linear-gradient(to top,rgb(0 0 0 / .62),rgb(0 0 0 / 0) 100%)">
                <h3 style="font-size:28px;font-weight:600;letter-spacing:-.03em;line-height:1.15">
                  Track the sale through fulfillment
                </h3>
                <p style="margin-top:8px;max-width:40ch;font-size:16px;line-height:1.5;color:rgb(255 255 255 / .82)">
                  Manage orders, payments and store performance from one dashboard.
                </p>
              </div>
            </article>
          </div>
        </div>
      </section>
      <section class="landing-desk" style="padding:48px 48px 48px">
        <div style="display:grid;grid-template-columns:1fr 560px;gap:48px;align-items:center;padding:64px;border-radius:28px;background:var(--color-soko-stage)">
          <div style="display:flex;flex-direction:column;gap:16px;align-items:flex-start">
            <span class="eye">The desk</span>
            <h2 class="h2">Run the shop from one place.</h2>
            <p class="lead">
              Products, Inbox and the playground sit together. The count on Inbox is the requests still waiting.
            </p>
            <.button
              navigate={if @current_user, do: ~p"/workspaces", else: ~p"/users/register"}
              tone="secondary"
              size="lg"
            >
              Open your desk
            </.button>
          </div>
          <div style="background:var(--color-soko-white);border:1px solid var(--color-soko-line);border-radius:14px;overflow:hidden">
            <div style="display:flex;align-items:center;justify-content:space-between;height:48px;padding:0 16px;border-bottom:1px solid var(--color-soko-line)">
              <strong style="font-size:14px;font-weight:500">Inbox</strong>
            </div>
            <div style="display:flex;gap:12px;align-items:center;padding:14px 16px;border-bottom:1px solid var(--color-soko-line)">
              <img
                src={~p"/images/nike-shox.webp"}
                loading="lazy"
                alt="Nike Shox"
                style="width:48px;height:48px;object-fit:cover;border-radius:10px;flex:none"
              />
              <span style="flex:1;min-width:0">
                <strong style="display:block;font-size:14px;font-weight:500">+254 712 345 678</strong><span style="display:block;font-size:12px;color:var(--color-soko-ink-2)">Nike Shox · EU 43</span>
              </span>
              <.badge tone="waiting">New request</.badge>
            </div>
            <div style="display:flex;gap:12px;align-items:center;padding:14px 16px">
              <.avatar seed={2} label="Customer" />
              <span style="flex:1;min-width:0">
                <strong style="display:block;font-size:14px;font-weight:500">+254 798 765 432</strong><span style="display:block;font-size:12px;color:var(--color-soko-ink-2)">Adidas Spezial · EU 42</span>
              </span>
              <.badge tone="neutral">Contacted</.badge>
            </div>
          </div>
        </div>
      </section>
      <section id="get-started" class="landing-start" style="padding:80px 0">
        <div class="wrap" style="display:flex;flex-direction:column;gap:40px;align-items:center">
          <header style="display:flex;flex-direction:column;gap:12px;align-items:center;text-align:center">
            <span class="eye">Get started</span>
            <h2 class="h2">Three things, then the shop is live</h2>
          </header>
          <div style="display:grid;grid-template-columns:repeat(3,1fr);gap:16px;width:100%">
            <article style="display:flex;flex-direction:column;gap:12px;padding:24px;border:1px solid var(--color-soko-line);border-radius:14px">
              <span class="eye">01</span>
              <h3 style="font-family:var(--font-sans);font-weight:600;font-size:24px;letter-spacing:var(--tracking-soko-display)">
                Catalogue
              </h3>
              <p style="font-size:14px;line-height:1.5;color:var(--color-soko-ink-2)">
                A name, a cover, and a KES price for each variant.
              </p>
            </article>
            <article style="display:flex;flex-direction:column;gap:12px;padding:24px;border:1px solid var(--color-soko-forest);border-radius:14px;background:var(--color-soko-mint-wash)">
              <span class="eye">02</span>
              <h3 style="font-family:var(--font-sans);font-weight:600;font-size:24px;letter-spacing:var(--tracking-soko-display)">
                WhatsApp
              </h3>
              <p style="font-size:14px;line-height:1.5;color:var(--color-soko-ink-2)">
                Connect the number you already use, or the shared Sokochat line.
              </p>
            </article>
            <article style="display:flex;flex-direction:column;gap:12px;padding:24px;border:1px solid var(--color-soko-line);border-radius:14px">
              <span class="eye">03</span>
              <h3 style="font-family:var(--font-sans);font-weight:600;font-size:24px;letter-spacing:var(--tracking-soko-display)">
                Desk
              </h3>
              <p style="font-size:14px;line-height:1.5;color:var(--color-soko-ink-2)">
                Confirm requests, clear them when you have replied, and try replies in the playground.
              </p>
            </article>
          </div>
          <.button
            navigate={if @current_user, do: ~p"/workspaces", else: ~p"/users/register"}
            tone="primary"
            size="lg"
          >
            List your shop
          </.button>
        </div>
      </section>
      <section id="faq" class="landing-faq" style="padding:32px 0 96px">
        <div style="width:720px;margin:0 auto;display:flex;flex-direction:column;gap:32px">
          <h2 class="h2" style="text-align:center">Before you connect</h2>
          <div style="border-top:1px solid var(--color-soko-line)">
            <details class="landing-question" open>
              <summary>
                <strong style="font-size:16px;font-weight:500">Can I keep my WhatsApp number?</strong>
                <.icon name="plus" class="landing-faq-icon" />
              </summary>
              <p style="margin-top:8px;padding-right:40px;font-size:16px;line-height:1.6;color:var(--color-soko-ink-2)">
                Yes. Connect the number you already use, or use the shared Sokochat line.
              </p>
            </details>
            <details class="landing-question" open>
              <summary>
                <strong style="font-size:16px;font-weight:500">
                  Does Sokochat take the buyer's payment?
                </strong>
                <.icon name="plus" class="landing-faq-icon" />
              </summary>
              <p style="margin-top:8px;padding-right:40px;font-size:16px;line-height:1.6;color:var(--color-soko-ink-2)">
                Sokochat quotes the KES price from the catalogue. You confirm the order on the desk.
              </p>
            </details>
            <details class="landing-question" open>
              <summary>
                <strong style="font-size:16px;font-weight:500">
                  Do I write the AI instructions myself?
                </strong>
                <.icon name="plus" class="landing-faq-icon" />
              </summary>
              <p style="margin-top:8px;padding-right:40px;font-size:16px;line-height:1.6;color:var(--color-soko-ink-2)">
                Paste your website when you create the shop. Sokochat reads it into AI content, and you can edit what it wrote.
              </p>
            </details>
            <details class="landing-question" open>
              <summary>
                <strong style="font-size:16px;font-weight:500">
                  Can one size have its own photo?
                </strong>
                <.icon name="plus" class="landing-faq-icon" />
              </summary>
              <p style="margin-top:8px;padding-right:40px;font-size:16px;line-height:1.6;color:var(--color-soko-ink-2)">
                Yes. Add a photo on that variant. Leave it empty and buyers see the cover.
              </p>
            </details>
            <details class="landing-question" open>
              <summary>
                <strong style="font-size:16px;font-weight:500">
                  Can I read a reply before it sends?
                </strong>
                <.icon name="plus" class="landing-faq-icon" />
              </summary>
              <p style="margin-top:8px;padding-right:40px;font-size:16px;line-height:1.6;color:var(--color-soko-ink-2)">
                Yes. Choose Approve first, and the draft waits in Inbox until you send it.
              </p>
            </details>
          </div>
          <a
            href="mailto:info@gs1kenya.org"
            style="display:flex;align-items:center;justify-content:space-between;gap:16px;padding:16px 20px;border:1px solid var(--color-soko-line);border-radius:12px;color:inherit;text-decoration:none"
          >
            <span style="display:grid;gap:2px;font-size:14px">
              <strong style="font-weight:500">Still have a question?</strong><span style="color:var(--color-soko-ink-2)">Write to Sokochat.</span>
            </span>
            <svg width="18" height="18" viewBox="0 0 24 24" aria-hidden="true">
              <path
                d="M5 12h14M13 6l6 6-6 6"
                fill="none"
                stroke="currentColor"
                stroke-width="1.75"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          </a>
        </div>
      </section>
    </div>
    """
  end
end
