# Sokochat Styling Guide

This guide documents the visual system used on the landing page
([components.ex](lib/sokochat_web/live/home_live/components.ex),
[app.css](assets/css/app.css),
[tailwind.config.js](assets/tailwind.config.js)). Use it to build new
pages/components that match the existing look and feel.

The stack is **Phoenix LiveView + TailwindCSS**, with a small set of custom
component classes and a neutral/green color scale defined in the Tailwind config.

---

## 1. Color Tokens

All colors are defined in [tailwind.config.js](assets/tailwind.config.js). Use
these tokens — never hard-code hex values except in gradients (see §7).

| Token | Hex | Typical use |
| --- | --- | --- |
| `primary` | `#0f9c5c` | Brand green: buttons, links on hover, accents, highlights |
| `primary-light` | `#ecfcf2` | Soft green backgrounds, icon tiles, card hover background |
| `n50` | `#fefefd` | Page background, card surfaces, text on dark/primary |
| `n100` | `#fbfbfb` | Subtle card borders |
| `n200` | `#f7f9fa` | Header/footer borders, dropdown hover bg |
| `n300` | `#e3e8ee` | Dividers, card borders, accordion borders |
| `n400` | `#9ea7b4` | Body/secondary text, muted labels |
| `n500` | `#707b8a` | Footer copy, finer secondary text |
| `n600` | `#535d6b` | Hover state for muted text |
| `n700` | `#3f4a59` | (reserved, darker text) |
| `n800` | `#2a3341` | Default body text, nav links |
| `n900` | `#1d242f` | Headings/strong text |

**Conventions**
- Default text is `text-n800` on a `bg-n50` surface (set globally in
  [app.css](assets/css/app.css) `body`, and on the page wrapper
  `bg-n50 text-n800`).
- Muted/supporting copy: `text-n400`.
- Strong headings: `text-n900` (default heading inherits n800; bump to n900 for
  emphasis like blog titles/footer headline).
- Brand accents and interactive hover: `text-primary` / `hover:text-primary`.
- On `primary` backgrounds, text is `text-n50` / `text-white`, dividers
  `bg-white/30`.

---

## 2. Typography

Font family: **Poppins** (`font-sans`), configured in the Tailwind config and
loaded in the root layout. Base body: `text-base leading-[1.5]`, antialiased.

Use the custom heading classes from [app.css](assets/css/app.css) rather than
ad-hoc font sizes for page-level headings:

| Class | Definition | Use |
| --- | --- | --- |
| `.h1` | `text-[42px] font-bold leading-[1.2] md:text-[48px] lg:text-[56px]` | Hero / page hero headlines |
| `.h2` | `text-[36px] font-semibold leading-[1.2] md:text-[42px] lg:text-[48px]` | Section headings |
| `.h5` | `text-2xl font-semibold leading-[1.2]` | Card titles |
| `.section-title` | `text-[20px] font-semibold uppercase text-primary` | Small green eyebrow label above section headings |

**Inline patterns**
- Eyebrow + heading + lead is the standard section header:
  ```heex
  <div class="section-title">Features</div>
  <h2 class="h2">Section heading</h2>
  <p class="text-n400">Supporting lead paragraph.</p>
  ```
- Lead paragraphs near heroes: `text-lg font-medium text-n400`.
- Smaller body within cards: `text-sm font-light text-n400`.
- Card sub-titles / feature titles (non-`.h5`): `text-lg font-medium leading-tight`.
- Uppercase footer column labels: `text-xs font-semibold uppercase tracking-[0.18em] text-n400`.
- Highlighted words in headings use `text-primary` with an underline SVG swoosh
  (see hero in [components.ex](lib/sokochat_web/live/home_live/components.ex)).

---

## 3. Buttons

Defined in [app.css](assets/css/app.css). Compose a base `.btn` with a variant
and optional size.

| Class | Role |
| --- | --- |
| `.btn` | Base: `inline-flex min-h-[48px] items-center justify-center gap-2 rounded-lg border px-4 py-3 text-base font-normal`, with `hover:-translate-y-1` lift on a 300ms transition |
| `.btn-primary` | Solid green: `border-primary bg-primary text-n50` |
| `.btn-secondary` | Light/outline: `border-n100 bg-n50 text-n800` + soft shadow, `hover:border-primary` |
| `.btn-sm` | Compact: `min-h-[40px] px-3 py-2` (used in header) |
| `.btn-lg` | Large: `min-h-[56px] px-6 py-4` (hero/CTA sections) |

Usage:
```heex
<a href="#pricing" class="btn btn-primary btn-lg">Get Started</a>
<a href="#services" class="btn btn-secondary">Learn More</a>
```

- Primary + secondary appear as a pair in CTA rows.
- Full-width in cards/mobile: add `w-full`.
- Button rows: `flex flex-wrap items-center gap-x-6 gap-y-4`.

---

## 4. Layout & Spacing

- **Page width**: wrap section content in `.container-x`
  (`mx-auto w-full max-w-container px-6`); `max-w-container` = **1312px**.
- **Section rhythm**: standard vertical padding is `py-24`. Smaller bands use
  `py-12`; the hero uses `py-24 lg:py-[156px]`; footer uses `py-16`.
- **Two-column sections**: `grid items-center gap-14 lg:grid-cols-2`
  (or asymmetric `lg:grid-cols-[1.25fr_1fr]`). Alternate image/text sides for
  rhythm.
- **Card grids**: `grid gap-14 md:grid-cols-2 lg:grid-cols-3`.
- **Centered section header block**:
  `mx-auto mb-16 flex max-w-[900px] flex-col items-center gap-2 text-center`.
- **Standard gap scale**: `gap-2`, `gap-3`, `gap-4`, `gap-6` within components;
  `gap-14` between grid items.

---

## 5. Cards & Surfaces

Surfaces sit on `bg-n50` with a thin neutral border and a soft shadow.

**Standard card**
```heex
<div class="rounded-lg border border-n100 bg-n50 p-8 shadow-[0_8px_24px_rgba(0,0,0,0.05)]">
```
- Border radius: `rounded-lg` for cards/buttons/inputs; `rounded-2xl` for large
  feature images; `rounded-full` for avatars/pills; `rounded-md` for small chips.
- Card borders: `border-n100` (subtle) or `border-n200`/`border-n300` (more
  defined, e.g. pricing).
- **Soft shadow** (cards): `shadow-[0_8px_24px_rgba(0,0,0,0.05)]`.
- **Dropdown shadow**: `shadow-[0_8px_24px_rgba(0,0,0,0.08)]`.
- **Button-secondary shadow**: `shadow-[0_4px_8px_rgba(0,0,0,0.1)]`.
- **Green hover glow** (interactive feature cards):
  `hover:shadow-[0_16px_40px_rgba(15,156,92,0.12)]`.

**Icon tile** (feature icon container):
```heex
<div class="flex h-12 w-12 items-center justify-center rounded-lg bg-primary-light text-primary">
```

**Pricing highlight card**: invert to `bg-primary text-n50` with `border-primary`,
white dividers (`bg-white/30`) and `text-white` content.

---

## 6. Interactions & Motion

Motion is subtle and consistent:
- **Lift on hover**: `transition-transform duration-300 hover:-translate-y-1`
  (cards, buttons, blog cards).
- **Color transition**: `transition-colors` on links/nav
  (`text-n800 ... hover:text-primary`).
- **Feature card hover**: `transition-all duration-300 ease-out` combining lift,
  `hover:border-primary/20`, `hover:bg-primary-light`, and green glow shadow;
  inner text shifts color via `group`/`group-hover:`.
- **Image zoom**: `transition-transform duration-500 group-hover:scale-105`
  inside an `overflow-hidden` wrapper.
- **Group pattern**: put `group` on the card, then `group-hover:` /
  `group-open:` on children (used for hover color shifts and accordion icons).
- **Accordion / FAQ**: native `<details>`/`<summary>` with
  `list-none`; the plus icon rotates via `group-open:rotate-45`. First item
  `open`.
- **Links**: always `no-underline` (this design avoids underlines).

---

## 7. Gradients

Section background gradients use the brand green at low opacity. Reuse these
exact patterns:
- Top-down fade (hero):
  `bg-[linear-gradient(to_bottom,rgba(15,156,92,0.09),rgba(255,255,255,0)_35%)]`
- Bottom-up fade (pricing/conversions):
  `bg-[linear-gradient(to_top,rgba(15,156,92,0.1),rgba(255,255,255,0)_35%)]`
- Left fade (feature band):
  `bg-[linear-gradient(270deg,rgba(15,156,92,0.12),rgba(15,156,92,0)_84%)]`

`#0f9c5c` is the `primary` hex; keep it in these `rgba()` gradient strings.

---

## 8. Header & Navigation

- Sticky header: `sticky top-0 z-50 ... border-b border-n200 bg-n50/95 backdrop-blur`,
  min height `min-h-[72px]`.
- Nav links: `p-2 text-n800 no-underline transition-colors hover:text-primary`.
- Desktop nav hidden on mobile (`hidden lg:flex`); mobile menu uses a
  checkbox-`peer` toggle (`peer-checked:flex`) — no JS.
- Dropdown menus: `group` + `group-hover:`/`group-focus-within:` to reveal.

---

## 9. Icons

- Inline SVGs use `viewBox="0 0 24 24"`, `stroke="currentColor"`,
  `stroke-width="2"`, round caps/joins, and `aria-hidden="true"`.
- Standard sizes: `h-5 w-5` (inline/UI), `h-6 w-6` (feature/star), `h-4 w-4`
  (small).
- Color via `currentColor` + a text color class (`text-primary`, etc.).
- Star rating accent: `text-[#f5a623]`.
- **Heroicons** are available via the `hero-*` Tailwind classes (config plugin),
  e.g. `<.icon name="hero-check" />` through CoreComponents — prefer these for
  generic UI icons.

---

## 10. Accessibility

- Decorative SVGs: `aria-hidden="true"`. Meaningful icons get an adjacent
  `<span class="sr-only">` or `aria-label`.
- Images: meaningful `alt` text; decorative images use `alt=""`.
- Below-the-fold images: `loading="lazy"`.
- Interactive groups support keyboard via `group-focus-within:`.

---

## Quick-Start Snippet

A new section that matches the base style:

```heex
<section class="py-24">
  <div class="container-x">
    <div class="mx-auto mb-16 flex max-w-[900px] flex-col items-center gap-2 text-center">
      <div class="section-title">Eyebrow</div>
      <h2 class="h2">Section heading</h2>
      <p class="text-n400">Supporting description for the section.</p>
    </div>

    <div class="grid gap-14 md:grid-cols-2 lg:grid-cols-3">
      <div class="rounded-lg border border-n100 bg-n50 p-8 shadow-[0_8px_24px_rgba(0,0,0,0.05)] transition-transform duration-300 hover:-translate-y-1">
        <h3 class="h5">Card title</h3>
        <p class="mt-2 text-n400">Card body copy.</p>
        <a href="#" class="btn btn-primary mt-6 w-full">Get Started</a>
      </div>
    </div>
  </div>
</section>
```
