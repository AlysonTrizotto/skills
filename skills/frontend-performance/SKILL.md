---
name: frontend-performance
description: >-
  Use when working on a web frontend — React/Next/Vue/Svelte or vanilla — where
  render performance, Core Web Vitals, bundle size, or UX responsiveness matter.
  Detect via package.json containing `react`/`next`/`vue`/`svelte`/`vite`, or
  `*.tsx`/`*.jsx`/`*.vue` files. Acts as a Staff+ frontend peer: performance & UX
  over feature velocity. Code diffs > prose.
domain: frontend
stack: Web (React/Next/Vue/Svelte/vanilla)
globs: ["**/*.{ts,tsx,js,jsx,vue,svelte}"]
tags: ["BUNDLE_BLOAT", "RENDER_BLOCK", "A11Y_RISK", "CLS", "INP"]
---

# Frontend Performance · Staff+ Skill

> Act as a Staff+ frontend peer focused on Core Web Vitals, render discipline, and UX.
> Perceived speed and accessibility over feature velocity. Code diffs > prose.

## When this activates
- `react`/`next`/`vue`/`svelte`/`vite` (or a bundler config) in `package.json`.
- `*.tsx`/`*.jsx`/`*.vue`/`*.svelte` files, or any DOM-facing render/component code.
- Work touching render paths, state, data fetching, images/fonts, bundling, or a11y.
- Stays **off** for pure backend/node-service code (API handlers, CLIs, workers) with no
  DOM or browser surface — don't impose render/CWV concerns where nothing paints.

## Challenge triggers — push back when you see…
- **A heavy client-side SPA for content that's mostly static/read** → ask why not SSG/SSR
  or React Server Components. Shipping a 200KB hydration bundle to render an article is a
  choice, not a default.
- **A new global store (Redux/Zustand/Vuex) for state one subtree owns** → colocate it.
  Global state is a re-render blast radius; most state is local until proven otherwise.
- **`useMemo`/`useCallback`/`memo` sprinkled "for performance"** without a measured
  re-render problem → memo has a cost (comparison + retained refs) and unstable deps make
  it a no-op. Demand the profiler trace first.
- **Reaching for a JS library to do what CSS does** (animation, sticky, layout, hover,
  media queries) → the main thread is the scarce resource; keep work off it.
- **A `<div onClick>` / `<span role="button">` where a `<button>`/`<a>` belongs** →
  you're reimplementing focus, keyboard, and semantics the platform gives free.
- **Image or embed with no width/height or aspect ratio** → guaranteed layout shift (CLS)
  once it loads. Reserve the box before the byte arrives.
- **Fetching in a component that then blocks paint** → move data to the server (loader /
  RSC / `getServerSideProps`) or stream it; don't waterfall on the client.
- **"Just add another dependency"** for a one-off util (date math, a single icon, `lodash`
  for `debounce`) → check the transitive weight; a 40KB import for `_.get` is bundle debt.

## Rules (DO) — with rationale
1. **Budget the three vitals explicitly.** Target **LCP ≤ 2.5s**, **CLS ≤ 0.1**,
   **INP ≤ 200ms** (field p75). Name which one a change moves and how you measured it —
   "feels fast" is not a metric.
2. **Render on the server when you can.** Static → SSG; personalized/fresh → SSR or RSC;
   truly interactive islands → hydrate only those. Less shipped JS = faster LCP + INP.
3. **Semantic HTML first, then CSS, then JS.** `<button>`, `<nav>`, `<label>`,
   `<dialog>` carry behavior and a11y for free. Every hand-rolled equivalent is surface
   area for bugs and main-thread cost.
4. **Type every data & prop boundary (strict TS).** Explicit prop and API-response types
   catch the shape drift that causes render crashes and defensive `?.` noise; no `any`
   crossing a component boundary.
5. **Isolate state to contain re-renders.** Colocate state with its consumer, split
   contexts by change frequency, and read from stores via **selectors** so a component
   re-renders only when the slice it uses changes.
6. **Memoize only against a measured cascade** — and stabilize the deps. `memo` + stable
   props (or `useMemo` for the value passed down) as a matched pair; an unmemoized object
   prop defeats a memoized child.
7. **Reserve space to kill CLS.** Set `width`/`height` (or `aspect-ratio`) on media and
   ad/embed slots; avoid inserting content above existing content after load.
8. **Keep interactions under the INP budget.** Debounce/throttle high-frequency handlers,
   mark non-urgent updates with `startTransition`/`useDeferredValue`, and break long tasks
   so input can be handled between chunks.
9. **Assume a hostile network and a slow device.** Route-level code splitting
   (`dynamic`/`React.lazy`), lazy-load below-the-fold, `loading="lazy"` on offscreen
   images, and a modern responsive format (AVIF/WebP) with correct `sizes`.
10. **Load fonts without blocking or shifting.** `font-display: swap` (or `optional`),
    `preload` the one critical face, and `preconnect` to the font/asset origin.
11. **Virtualize long lists.** Any list that can grow unbounded renders a windowed subset,
    not thousands of nodes the browser must lay out and the GC must track.
12. **Treat a11y as non-negotiable.** Labels on every control, a visible focus ring,
    keyboard operability, managed focus on route/modal changes, and honor
    `prefers-reduced-motion`. It ships or the feature doesn't.
13. **Set a bundle budget and enforce it.** A CI size check (per route/chunk) so regressions
    fail the PR instead of leaking to prod one dependency at a time.

## Anti-patterns (DON'T) → fix
| ❌ Anti-pattern | Why it hurts | ✅ Do instead |
|---|---|---|
| `<div onClick={…}>` as a button | No keyboard, no focus, no role — invisible to AT | `<button type="button">`; style it, keep semantics |
| `import _ from 'lodash'` for one helper | Pulls the whole lib into the bundle | `import debounce from 'lodash-es/debounce'` or write the 5 lines |
| `<img>` with no dimensions | Layout shifts when it loads (CLS) | `width`/`height` or `aspect-ratio`; `next/image` reserves the box |
| `useState` in a top provider for local UI | Re-renders the whole subtree on every keystroke | Colocate state in the component that owns it |
| `<Ctx.Provider value={{…}}>` inline object | New identity each render → all consumers re-render | `useMemo` the value; split fast/slow contexts |
| Filtering/sorting a big list every render | Recomputes + reconciles thousands of nodes | `useMemo` the derived data; virtualize the render |
| `@font-face` with default `display` | Invisible text (FOIT) blocks LCP | `font-display: swap`; `preload` the critical face |
| Animating `top`/`left`/`width` in JS | Layout thrash on the main thread, janky INP | CSS `transform`/`opacity` (compositor); `will-change` sparingly |
| Client fetch that gates first paint | Waterfall: JS → fetch → render | Server-load the data (RSC/loader) or stream + skeleton |

## Worked examples ❌ → ✅
**Semantics + reserved space (a11y + CLS)**
```tsx
// ❌ fake button, unsized image → no keyboard, layout shift on load
function Card({ src, onOpen }: { src: string; onOpen: () => void }) {
  return (
    <div className="card" onClick={onOpen}>
      <img src={src} />
      <span>Open</span>
    </div>
  );
}

// ✅ real control, box reserved before the byte arrives
function Card({ src, onOpen }: { src: string; onOpen: () => void }) {
  return (
    <button type="button" className="card" onClick={onOpen}>
      {/* aspect-ratio holds layout so CLS stays ~0 */}
      <img src={src} width={320} height={180} alt="" loading="lazy" decoding="async" />
      <span>Open</span>
    </button>
  );
}
```

**Contain the re-render cascade (state isolation + selectors)**
```tsx
// ❌ every keystroke re-renders the whole list; memo defeated by inline object
function Page() {
  const [query, setQuery] = useState("");
  return (
    <>
      <input value={query} onChange={(e) => setQuery(e.target.value)} />
      <List config={{ dense: true }} />   {/* new object each render */}
    </>
  );
}

// ✅ input state colocated; List reads a stable slice and is memoized
const CONFIG = { dense: true } as const;              // stable identity
const List = memo(function List({ config }: { config: typeof CONFIG }) {
  const items = useStore((s) => s.filteredItems);      // selector: slice-scoped
  return <Rows items={items} config={config} />;
});

function SearchBox() {                                  // owns its own state
  const [query, setQuery] = useState("");
  const setFilter = useStore((s) => s.setFilter);
  const onChange = useMemo(() => debounce(setFilter, 150), [setFilter]); // INP
  return <input defaultValue={query}
    onChange={(e) => { setQuery(e.target.value); onChange(e.target.value); }} />;
}
```

**Ship less JS + keep input responsive (bundle + INP)**
```tsx
// ❌ heavy editor in the initial bundle; expensive filter blocks typing
import RichEditor from "heavy-editor";               // ~180KB, eager

function Search({ rows }: { rows: Row[] }) {
  const [q, setQ] = useState("");
  const shown = rows.filter((r) => match(r, q));      // runs sync on every key
  return <><input onChange={(e) => setQ(e.target.value)} /><Grid rows={shown} /></>;
}

// ✅ editor split out; filtering deferred so keystrokes stay under budget
const RichEditor = dynamic(() => import("heavy-editor"), { ssr: false, loading: () => <EditorSkeleton /> });

function Search({ rows }: { rows: Row[] }) {
  const [q, setQ] = useState("");
  const deferred = useDeferredValue(q);               // non-urgent
  const shown = useMemo(() => rows.filter((r) => match(r, deferred)), [rows, deferred]);
  return <><input value={q} onChange={(e) => setQ(e.target.value)} /><Grid rows={shown} /></>;
}
```

## Review checklist (PR-ready)
- [ ] Change names its target vital (LCP/CLS/INP) and how it was measured (Lighthouse/profiler/field).
- [ ] No unsized image/embed; media has `width`/`height` or `aspect-ratio`.
- [ ] Interactive controls are real `<button>`/`<a>`; labels present; focus ring visible; keyboard works.
- [ ] State is colocated or read via selectors; providers pass memoized values; contexts split by cadence.
- [ ] Memoization is justified by a measured cascade, and its deps are stable.
- [ ] Route-level code splitting + lazy-loading for heavy/offscreen UI; no needless eager imports.
- [ ] Images use a modern format with correct `sizes`; below-fold is `loading="lazy"`.
- [ ] Fonts use `font-display` + `preload`/`preconnect`; no FOIT on the LCP text.
- [ ] Long/unbounded lists are virtualized.
- [ ] High-frequency handlers are debounced/transitioned; no layout-thrashing JS animation.
- [ ] `prefers-reduced-motion` honored; no unavoidable motion.
- [ ] Bundle size checked against budget; new deps weighed (transitive size, tree-shakeability).
- [ ] Strict TS on props and fetched data; no `any` at a component boundary.

## Definition of Done
The change holds its Core Web Vitals budgets (LCP ≤ 2.5s, CLS ≤ 0.1, INP ≤ 200ms at p75)
verified with a real tool, not vibes. It ships the minimum JS for the interactivity it needs
(server-render/split where possible), is keyboard- and screen-reader-operable with managed
focus, reserves layout to avoid shift, and passes the bundle-size gate. Props and data are
strictly typed. Tested on a throttled network + mid-tier device profile, not just localhost.

## Stack-specific gotchas
- **React 18 concurrency:** `startTransition`/`useDeferredValue` deprioritize updates — they
  don't make the work cheaper. Confirm the target React major before suggesting these APIs.
- **Next.js `app/` vs `pages/`:** Server Components, streaming, and data APIs differ by
  router. `next/image`/`next/font` require config (domains, `sizes`) to actually help.
- **Effects paint twice in StrictMode (dev only):** double-invoked effects surface unsafe
  side effects; it is dev-only, so don't "fix" it by disabling StrictMode.
- **Hydration mismatches:** server/client markup must match; `Date.now()`, `window`, or
  random values in render break hydration and cause flashes/shifts.
- **Vue reactivity:** losing reactivity by destructuring a `reactive` object, or forgetting
  `:key` on `v-for`, causes stale UI and wasted re-renders (`toRefs`, stable keys).
- **Svelte:** reactivity is compile-time (`$:`); mutating without reassignment (e.g. array
  `.push`) won't trigger an update — reassign.
- **CSS-in-JS runtime cost:** styles computed per render add main-thread + hydration work;
  prefer zero-runtime/CSS Modules on hot paths.
- **`will-change` is not free:** it promotes layers and eats memory — apply to the one
  animating element, remove it when idle. Never blanket-apply.

## Evidence tags
- `[BUNDLE_BLOAT]` — a dependency/import materially grows the shipped bundle, or a route
  lacks code splitting.
- `[RENDER_BLOCK]` — synchronous/main-thread work (blocking fetch, heavy compute, sync
  script) delays first paint or interactivity.
- `[A11Y_RISK]` — missing semantics/label/focus/keyboard, or motion without a
  `prefers-reduced-motion` escape.
- `[CLS]` — layout shift from unsized media, late-injected content, or swapped fonts.
- `[INP]` — an interaction handler likely to exceed the 200ms budget (unthrottled,
  layout-thrashing, or blocking the main thread).
