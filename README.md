# WhatsappBot

## What is this?

WhatsappBot is a Phoenix LiveView application that lets any business create and run
an AI-powered WhatsApp chatbot without writing code. A business owner signs up,
connects their own data source, and gets a bot that can answer buyer questions
around the clock — in English or Swahili — directly inside WhatsApp.

The whole thing is built around three ideas: your data stays yours (the bot reads
from your own API or endpoint), the AI stays current (it fetches live data on every
conversation), and you can test everything before going live (the playground simulates
the full WhatsApp experience in the browser).

---

## The problem it solves

Most small and medium businesses in Kenya and across East Africa run their sales
through WhatsApp. Buyers message to ask about prices, availability, and location.
Sellers spend hours every day answering the same questions manually.

WhatsappBot handles those conversations automatically. A buyer messages the business
number, the AI reads the latest product data, and replies instantly with the right
answer — including a direct link to the website, a click-to-call button, or the
seller's WhatsApp number depending on what makes sense.

---

## Who it is for

- **Marketplace operators** like Sokopawa who want to give their member sellers a
  ready-made AI sales presence on WhatsApp
- **Individual merchants** who want to automate buyer enquiries without hiring staff
- **Any business** that already has a product catalogue, pricing sheet, or inventory
  API and wants to surface it conversationally

---

## How it works

### 1. Create an account

Sign up with an email and password. Each account can manage multiple bots
(called workspaces) — one per business or product line.

### 2. Connect your data

Paste the URL of any endpoint that returns JSON. This could be your own API,
a Google Sheets export, an Airtable base, or anything similar. The bot fetches
this data and uses it to answer questions. When your prices change, the bot
automatically knows.

### 3. Write your instructions

Tell the bot who it is and how to behave in a few plain-English sentences —
something like "You are the sales assistant for Sokopawa. Be friendly and concise.
Always respond in the same language the buyer uses."

### 4. Configure your CTAs

A CTA (Call to Action) is what happens at the end of a bot reply. You define
rules in plain English: "If the buyer wants to buy, show them a link to the
checkout page." The bot evaluates these rules at runtime and attaches the right
button or link to its response. Supported CTA types include:

- Link to a website or product page
- Click-to-call a phone number
- Open a specific WhatsApp number (e.g. connect buyer directly to a seller)
- A map pin with the business location
- Quick-reply buttons for common choices
- A scrollable list of products or options

### 5. Test in the Playground

Before connecting to real WhatsApp, test everything in the browser. The Playground
is a chat interface that looks and behaves like WhatsApp. Type messages as if you
are a buyer and see exactly what the bot replies, including how buttons and lists
render. Adjust your instructions and CTA rules until it feels right.

### 6. Go live on WhatsApp

Enter your Meta WhatsApp Business credentials (Phone Number ID, Business Account ID,
access token). Copy the webhook URL shown on screen and paste it into the Meta
Developer Console. The system verifies the connection automatically. From that point,
real buyer messages are handled by the same AI engine the playground tested.

---

## Tech stack

Built with Elixir and Phoenix LiveView, PostgreSQL for storage, Oban for background
jobs, and Anthropic's Claude as the AI model. All sensitive credentials (API keys,
access tokens) are encrypted at rest. The Meta webhook integration uses the official
WhatsApp Business Cloud API.

---

## Key design decisions

**One WhatsApp number, one bot, one data source per workspace.** Keeping the scope
tight means the setup is fast and the behaviour is predictable. Multi-source and
multi-number support can come later.

**The AI reads live data, not a static knowledge base.** There is no training step
and no manual sync. The bot is always as current as the endpoint it points at.

**The playground is not an afterthought.** It is the primary way owners tune their
bot. Everything that works in the playground works identically in production. There
are no surprises when you go live.

**CTA rules are written in plain English.** Owners should not need to understand
JSON or regular expressions to configure when a phone button appears. The AI
interprets the rules at runtime.

---

## What is not in v1

- Payments or checkout processing
- Human agent handoff (taking over a conversation from the bot)
- Voice message handling
- Image recognition from buyer-sent photos
- Analytics and reporting dashboard
- Team members or role-based access
