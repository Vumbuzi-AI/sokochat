# WhatsappBot — UI/UX Redesign Specification

> Hand this file to Claude Code and say: **"Implement this redesign spec."**  
> Every section maps 1-to-1 to a screen or component already in the app.

---

## Design Philosophy

The current UI is functional but generic — it could be any SaaS tool. This redesign  
gives it a visual identity rooted in *WhatsApp itself*: the familiar dark teal header,  
warm chat-bubble background, and the feel of messaging — but elevated for a professional  
dashboard. Clean, fast, trustworthy.

**One sentence:** *WhatsApp's warmth, a product manager's clarity.*

---

## Token System

### Colors

```
--color-brand-dark:     #075E54   /* WhatsApp dark teal — nav, CTAs */
--color-brand-mid:      #128C7E   /* hover states, accents */
--color-brand-light:    #25D366   /* success, online dot, primary buttons */
--color-brand-pale:     #DCF8C6   /* outgoing message bubbles */
--color-chat-bg:        #ECE5DD   /* chat area background — WhatsApp linen */
--color-surface:        #FFFFFF   /* cards, panels */
--color-surface-2:      #F7F8FA   /* page background */
--color-ink-primary:    #111B21   /* headings, body text */
--color-ink-secondary:  #54656F   /* subtext, timestamps, labels */
--color-ink-tertiary:   #8696A0   /* placeholders, disabled */
--color-border:         #E9EDEF   /* card borders, dividers */
--color-error:          #FF3B30   /* error states */
--color-error-bg:       #FFF2F2   /* error banner background */
--color-warning:        #FF9500   /* "not configured" badge */
--color-code-bg:        #1E2A32   /* JSON preview, system prompt panels */
```

### Typography

```
Font stack:
  Display / Nav:  "Inter", system-ui, sans-serif  (weight 600–700)
  Body:           "Inter", system-ui, sans-serif  (weight 400–500)
  Monospace:      "JetBrains Mono", "Fira Code", monospace  (code panels)

Scale:
  --text-xs:    11px / 1.4   (timestamps, badge labels)
  --text-sm:    13px / 1.5   (secondary labels, captions)
  --text-base:  15px / 1.6   (body, chat messages)
  --text-md:    17px / 1.4   (card titles, section headers)
  --text-lg:    22px / 1.3   (page titles)
  --text-xl:    30px / 1.2   (hero / workspace name)
```

### Spacing & Radius

```
--radius-sm:   8px    (badges, code blocks, input)
--radius-md:   12px   (cards, panels)
--radius-lg:   18px   (chat bubbles outgoing)
--radius-xl:   18px   (chat bubbles incoming — square top-left)
--radius-full: 9999px (buttons, pill badges, send button)

Spacing scale: 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40 / 48 / 64px
```

### Shadows

```
--shadow-card:   0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04)
--shadow-panel:  0 4px 16px rgba(0,0,0,0.08)
--shadow-float:  0 8px 32px rgba(0,0,0,0.12)   (toasts, dropdowns)
```

---

## Global Navigation

### Current problems
- Plain white bar with no visual hierarchy
- User email shown raw, no avatar
- No indication of which section is active

### Redesigned nav

```
Layout: fixed top, full-width, height 56px
Background: linear-gradient(135deg, #075E54 0%, #128C7E 100%)
Box-shadow: 0 2px 8px rgba(7,94,84,0.3)
```

**Left cluster:**
- Logo mark: white rounded-square icon with a "W" chat bubble SVG, 28×28px
- "WhatsappBot" wordmark: white, Inter 600, 16px, letter-spacing -0.3px
- Nav links: "Workspaces" and "New workspace" — white/80 opacity, 14px, 500 weight  
  Active link: white/100, with a 2px underline in `--color-brand-light`

**Right cluster:**
- Avatar circle: 32px, gradient background `#128C7E → #25D366`, white initial "M"
- Name: "Michael" in white, 14px 500
- "Settings" link: white/70, 13px
- "Log out" button: white border, transparent fill, white text, pill shape, 13px —  
  on hover: white fill, `--color-brand-dark` text

---

## Page: Workspaces

### Current problems
- Flat grey background, no visual weight
- Workspace cards lack hierarchy — name, slug, description all same visual level
- No clear empty-state affordance
- "New workspace" in header and as button feels redundant

### Redesigned layout

**Page wrapper:** `background: --color-surface-2`, padding 40px 48px

**Page header:**
```
Eyebrow: "WORKSPACES" — brand-light color, 11px, 700, letter-spacing 1.2px
Title: "Your bots" — ink-primary, 30px, 700
Subtitle: "Each bot connects one business to WhatsApp." — ink-secondary, 15px
```

**Workspace card grid:** 3-column on desktop, 2 on tablet, 1 on mobile  
Gap: 20px

**Workspace card:**
```
Background: white
Border: 1px solid --color-border
Border-radius: --radius-md (12px)
Padding: 20px 24px
Shadow: --shadow-card
Hover: shadow --shadow-panel, translateY(-1px), transition 180ms ease
```

Card anatomy (top to bottom):
1. **Status row:** language badge (pill, `#E8FFF3` background, `#128C7E` text, 11px) + dot if active
2. **Bot name:** 17px, 600, ink-primary, margin-top 10px
3. **Slug:** `/test-bot` — code font, 12px, ink-tertiary, `#F7F8FA` bg, padding 2px 6px, radius 4px
4. **Description:** one line, 14px, ink-secondary, margin-top 8px, line-clamp 2
5. **Divider:** 1px `--color-border`, margin 16px 0
6. **Footer row:** "Updated Jun 12, 2026" left (13px, ink-tertiary) + **Open** button right

**Open button:**
```
Background: --color-brand-dark
Color: white
Border-radius: --radius-full
Padding: 8px 20px
Font: 13px, 600
Hover: --color-brand-mid
```

**"New workspace" card:** same grid slot, dashed border `2px dashed --color-border`,  
centered `+` icon (32px, ink-tertiary) and "New workspace" label, ink-secondary.  
Hover: border `--color-brand-light`, icon and text turn `--color-brand-dark`.

---

## Page: Workspace Detail (Test Bot)

### Current problems
- Four tiles feel equal — they're not (Playground is where most time is spent)
- "Not configured" badge on Meta Connection doesn't guide the user on what to do
- No visual progress/status summary

### Redesigned layout

**Breadcrumb:** `Workspaces / Test Bot` — ink-tertiary, 13px, with chevron separator

**Header row:**
- Bot name "Test Bot" — 30px, 700
- Slug badge: `/test-bot` inline code style (see card spec above)
- Right: **Edit workspace** — ghost button (border `--color-border`, ink-primary, hover bg surface-2)

**Subtitle:** "Configure your data, rules, playground, and WhatsApp connection." — ink-secondary

**Setup progress bar** (NEW):
```
A thin 4px track across full width, radius-full
3 of 4 sections configured = 75% fill
Gradient fill: #25D366 → #128C7E
Label right of bar: "3 of 4 steps complete" — 13px, ink-secondary
```

**Card grid:** 2×2 on desktop, stacked on mobile, gap 20px

Each card:
```
Background: white
Border: 1px solid --color-border
Border-radius: 12px
Padding: 24px
```

Card header row: **Title** (17px, 600) + **status badge** right-aligned  
Status badge styles:
- Configured: `background #E8FFF3, color #128C7E, border 1px solid #B7EBCF`
- Not configured: `background #FFF8ED, color #FF9500, border 1px solid #FFD9A0`

Card description: 14px, ink-secondary, margin-top 6px, max 2 lines

**CTA link** at bottom: `--color-brand-dark` color, 14px, 600, with → arrow on hover  
No underline by default; underline on hover.

**Highlight: Playground card** gets a subtle left border accent:
```
border-left: 3px solid --color-brand-light
```
…to indicate it's the primary testing surface.

---

## Page: Playground

### Current problems
- Error banner sits in top-right corner, floating and easy to miss
- Session insights panel header is low contrast
- Code panels (endpoint preview, system prompt) blend into page background
- Chat area is functional but lacks WhatsApp polish
- The send input has no visual separation from the chat

### Layout

```
Main split: chat panel (flex 1, min-width 0) | sidebar (320px fixed)
Gap between: 24px
Page background: --color-surface-2
Padding: 24px
```

---

### Error / Toast Banner (REDESIGNED)

**Position:** fixed, top 16px, right 16px, max-width 400px  
**Background:** `--color-error-bg` (`#FFF2F2`)  
**Border:** `1px solid #FFCDD2`, `border-left: 4px solid --color-error`  
**Border-radius:** `--radius-md`  
**Shadow:** `--shadow-float`  
**Icon:** red circle-exclamation, 18px, left-aligned  
**Title:** "Something went wrong" — 14px, 600, `--color-error`  
**Body:** error message in 13px, ink-secondary — truncate long API messages to 2 lines with "Show more" toggle  
**Close:** ×, ink-tertiary, top-right, hover ink-primary

Replace raw OpenAI/API error strings with human-readable messages:
- "Invalid schema" → "The bot's response format has a configuration error. Check your CTA rules."
- Always show a documentation-style hint below the error text in italic, 12px.

---

### Chat Panel

**Outer wrapper:**
```
Background: white
Border: 1px solid --color-border
Border-radius: 16px
Shadow: --shadow-card
Display: flex flex-col
Height: calc(100vh - 112px)
Overflow: hidden
```

**Chat header:**
```
Background: linear-gradient(135deg, #075E54, #128C7E)
Padding: 14px 20px
Border-radius: 16px 16px 0 0
Display: flex, align-items center, gap 12px
```
- Avatar: 36px circle, white bg, brand-dark initial "T", font 15px 600
- Online dot: 10px `--color-brand-light`, bottom-right of avatar, border 2px white
- Name: "Test Bot" — white, 15px, 600
- Sub: "Connected to: localhost" — white/60, 12px
- Right: **Clear chat** — ghost icon-button, trash icon, white/60, hover white/100

**Chat messages area:**
```
Background: --color-chat-bg  (#ECE5DD)
Background-image: subtle WhatsApp-style dot pattern (CSS radial-gradient, very faint)
  background-image: radial-gradient(circle, rgba(0,0,0,0.04) 1px, transparent 1px)
  background-size: 20px 20px
Flex: 1, overflow-y: auto
Padding: 16px
```

**Empty state (no messages yet):**
```
Centered vertically and horizontally
Icon: chat bubble SVG, 48px, ink-tertiary/40
Headline: "Send a message to test your bot" — 14px, ink-secondary
Subtext: "Responses mirror the live WhatsApp experience." — 13px, ink-tertiary
```

**Outgoing message bubble (user):**
```
Background: --color-brand-pale  (#DCF8C6)
Color: --color-ink-primary
Border-radius: 12px 12px 0 12px
Max-width: 72%
Padding: 10px 14px
Margin-left: auto
Font: 15px, 400
```
Timestamp: 11px, ink-tertiary, text-align right, margin-top 3px  
Show single ✓ (sent) or double ✓✓ (delivered)

**Incoming message bubble (bot):**
```
Background: white
Color: --color-ink-primary
Border-radius: 12px 12px 12px 0
Max-width: 78%
Padding: 10px 14px
Shadow: 0 1px 2px rgba(0,0,0,0.08)
Font: 15px, 400
```

**Product card CTA inside bot bubble:**
```
Border: 1px solid --color-border
Border-radius: 10px
Overflow: hidden
Margin-top: 8px

  Image zone: aspect-ratio 16/9, object-fit cover
  Body: padding 10px 12px
    Product name: 14px, 600, ink-primary
    Price: 13px, ink-secondary
  Footer: border-top 1px --color-border, padding 8px 12px
    Link text: --color-brand-dark, 13px, 600, chain-link icon left
```

**CTA buttons inside bubbles:**
```
Background: white
Border: 1px solid --color-border
Border-radius: 8px
Padding: 10px 16px
Font: 14px, 500, --color-brand-dark
Width: 100%
Text-align: center
Hover: background #F0FBF8, border-color --color-brand-light
Gap between buttons: 6px
```

**Message input bar:**
```
Background: #F0F2F5
Border-top: 1px solid --color-border
Padding: 10px 16px
Display: flex, align-items center, gap 10px
Border-radius: 0 0 16px 16px
```

Input field:
```
Background: white
Border: 1px solid --color-border
Border-radius: 22px
Padding: 10px 16px
Font: 15px
Flex: 1
Focus: border-color --color-brand-mid, box-shadow 0 0 0 3px rgba(18,140,126,0.12)
```

Send button:
```
Background: --color-brand-dark
Width: 44px, height: 44px
Border-radius: 50%
Icon: white send arrow SVG, 18px
Hover: --color-brand-mid
Active: scale(0.95)
Disabled: opacity 0.4, cursor not-allowed
```

---

### Sidebar (Session Insights + Data Preview + System Prompt)

```
Width: 320px
Display: flex flex-col
Gap: 16px
```

**Sidebar panel component (shared):**
```
Background: white
Border: 1px solid --color-border
Border-radius: 12px
Overflow: hidden
```

Panel header:
```
Padding: 14px 16px
Border-bottom: 1px solid --color-border
Display: flex, justify-content space-between, align-items center
```
- Title: 14px, 600, ink-primary
- Collapse chevron: ink-tertiary, rotates on open/close, transition 200ms

Panel body: `padding: 0` (children own their padding)

---

**Session Insights panel:**

Token counter block:
```
Padding: 16px
Display: flex, align-items baseline, gap 8px
```
- Label: "TOKENS USED" — 10px, 700, letter-spacing 1px, ink-tertiary
- Number: 32px, 700, ink-primary (animates on change with a brief scale-up)
- Refresh button: icon-only, ink-tertiary, circle hover, top-right of panel header

---

**Endpoint Data Preview panel:**

Header includes a live status indicator:
- Green dot + "Live" if endpoint responds
- Red dot + "Error" if endpoint fails
- Grey dot + "No endpoint" if not configured

Code block:
```
Background: --color-code-bg  (#1E2A32)
Color: #A8C4D0   (muted blue-white for JSON keys)
String values: #98D4A3  (soft green)
Numbers: #E9D58A  (warm yellow)
Font: JetBrains Mono, 12px
Padding: 14px 16px
Max-height: 220px
Overflow-y: auto
Border-radius: 0 0 12px 12px
```

Custom scrollbar:
```css
::-webkit-scrollbar { width: 4px }
::-webkit-scrollbar-track { background: transparent }
::-webkit-scrollbar-thumb { background: #3D5A6B; border-radius: 2px }
```

---

**Last System Prompt panel:**

Same code block style as above.  
Empty state: `"No prompt sent yet."` — centre-aligned, ink-tertiary, italic, 13px

---

## Component: Badge

Pill-shaped, no hard border-radius corners.

```
Variants:
  configured:     bg #E8FFF3, text #128C7E, border #B7EBCF
  not-configured: bg #FFF8ED, text #C77700, border #FFD9A0
  language:       bg #EAF4FF, text #0A6EBD, border #B3D4F5
  live:           bg #E8FFF3, text #128C7E — with 6px green animated pulse dot
  error:          bg #FFF2F2, text #D32F2F, border #FFCDD2

Padding: 3px 10px
Font: 11px, 600, letter-spacing 0.3px
Border-radius: 9999px
```

---

## Component: Buttons

**Primary (filled):**
```
Background: --color-brand-dark
Color: white
Border-radius: 9999px
Padding: 10px 24px
Font: 14px, 600
Hover: --color-brand-mid + shadow 0 4px 12px rgba(7,94,84,0.25)
Active: scale(0.98)
Disabled: opacity 0.45
```

**Secondary (ghost):**
```
Background: transparent
Border: 1.5px solid --color-border
Color: --color-ink-primary
Border-radius: 9999px
Padding: 9px 22px
Font: 14px, 500
Hover: background --color-surface-2, border-color ink-secondary
```

**Destructive (ghost):**
```
Same as ghost but color --color-error
Hover: background #FFF2F2, border-color --color-error
```

**Icon button:**
```
Width/height: 36px
Border-radius: 8px
Background: transparent
Color: ink-tertiary
Hover: background --color-surface-2, color ink-primary
```

---

## Micro-interactions & Motion

Keep all transitions under 200ms. Use `cubic-bezier(0.4, 0, 0.2, 1)` (Material standard easing).

| Element | Trigger | Effect |
|---|---|---|
| Nav links | hover | opacity 0.7 → 1, 150ms |
| Workspace card | hover | shadow lift + translateY(-1px), 180ms |
| Send button | hover | background shift, 150ms |
| Send button | click | scale(0.95), 80ms |
| Chat bubble | appear | opacity 0 → 1 + translateY(6px → 0), 200ms |
| Token counter | change | scale 1 → 1.08 → 1, 300ms |
| Error toast | appear | slide in from right, 250ms |
| Error toast | dismiss | fade + slide out, 200ms |
| Sidebar panels | collapse | height animates, 200ms |
| Badges | — | no animation (static status) |
| Progress bar fill | page load | width animates from 0, 600ms, ease-out |

Respect `prefers-reduced-motion`: when set, disable all transforms and use opacity-only fades.

---

## Responsive Breakpoints

```
Mobile:   < 640px   — single column, sidebar collapses to accordion below chat
Tablet:   640–1024px — chat full width, sidebar hidden (toggle via "Insights" tab)
Desktop:  > 1024px  — two-column layout as described
```

On mobile, the chat input sticks to the bottom of the viewport (`position: sticky; bottom: 0`).

---

## Accessibility

- All interactive elements meet 4.5:1 contrast on their background
- Focus rings: `outline: 2px solid --color-brand-light; outline-offset: 2px` (replaces browser default)
- All icon-only buttons have `aria-label`
- Error messages have `role="alert"` so screen readers announce them immediately
- Chat messages: bot replies have `aria-live="polite"` region
- Colour is never the sole differentiator (e.g. status badges also use text labels)

---

## Page-by-page Implementation Checklist

Use this as a task list in Claude Code:

### Global
- [ ] Replace all colours with CSS custom properties from the token system above
- [ ] Add Inter and JetBrains Mono to the font stack (Google Fonts or self-hosted)
- [ ] Implement the new nav gradient and avatar cluster
- [ ] Create shared `Badge`, `Button`, `Card`, and `CodeBlock` components/classes

### Workspaces page
- [ ] Apply new page header (eyebrow + title + subtitle)
- [ ] Build workspace card with status row, slug chip, divider footer
- [ ] Add "New workspace" dashed card
- [ ] Wire hover animations

### Workspace detail page
- [ ] Add breadcrumb
- [ ] Build setup progress bar (count configured sections, animate fill)
- [ ] Apply card grid with highlighted Playground card (left border accent)
- [ ] Update status badge styles

### Playground page
- [ ] Redesign chat panel with WhatsApp gradient header
- [ ] Apply `--color-chat-bg` + dot pattern to message area
- [ ] Style outgoing vs incoming bubbles as spec'd
- [ ] Redesign message input bar + send button
- [ ] Redesign product card CTAs inside bubbles
- [ ] Redesign error toast (position, copy, collapsible detail)
- [ ] Style all three sidebar panels (insights, endpoint preview, system prompt)
- [ ] Apply syntax highlighting colours to code blocks
- [ ] Wire token counter animation
- [ ] Add empty chat state

---

## What NOT to Change

- The underlying Phoenix LiveView architecture and routing
- The workspace/bot data model
- The Meta webhook integration flow
- Any business logic in the AI engine
- The CTA rules configuration (only style the UI shell around it)

---

*End of redesign spec. All measurements in px unless noted. All colours as CSS hex values.*
