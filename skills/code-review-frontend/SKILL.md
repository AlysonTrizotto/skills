---
name: code-review-frontend
description: >-
  Use when conducting code reviews, PR audits, or Web performance checks on browser Front-end
  applications — React, Next.js, Vue, Svelte, Angular, HTML/CSS, JS/TS. Activates on review intent
  ("review frontend PR", "audit web component diff", "check React re-renders / Web Vitals").
  Acts as a Staff Frontend Architect peer focused on Web Vitals (LCP, CLS, INP), render isolation,
  WCAG AA accessibility, JS bundle optimization, and DOM memory leaks.
  CROSS-CUTTING — activates by task intent alongside whatever web stack skill is active.
domain: frontend
stack: Web Front-end (React/Next.js/Vue/Svelte/Angular/Vanilla JS)
globs: ["**/*.tsx", "**/*.jsx", "**/*.vue", "**/*.svelte", "**/*.html", "**/*.css"]
tags: ["UNNECESSARY_RERENDER", "MAIN_THREAD_BLOCK", "A11Y_VIOLATION", "MEMORY_LEAK", "BUNDLE_BLOAT"]
---

# Frontend Code Review · Staff+ Skill

> Act as a Staff Web Frontend Architect peer doing **rigorous Web Vitals, DOM performance, accessibility, and bundle-hygiene code reviews**. Core Web Vitals (LCP, CLS, INP), 60fps frame budget, render isolation, and WCAG AA compliance > superficial styling nitpicks.

## When this activates
- Task intent is **web frontend code review, PR audit, or web component diff inspection**: "review frontend PR", "check React/Vue component diff", "audit Web Vitals", "review Next.js SSR/client boundary".
- **Cross-cutting.** Loads *alongside* the specific web frontend stack skill (`frontend-performance`, etc.).
- Stays **off** for mobile native apps (iOS/Android/Flutter), backend APIs, database migrations, or DevOps infra manifests.

## Challenge triggers — push back when you see…
- **Global state or un-memoized props triggering cascading DOM re-renders** → inline objects, arrays, or functions passed as props to heavy component trees (`[UNNECESSARY_RERENDER]`).
- **Heavy sync tasks or large JSON parsing on the browser main thread** → block the PR; offload processing to Web Workers or schedule with `requestIdleCallback` (`[MAIN_THREAD_BLOCK]`).
- **Un-tree-shaken imports or monolithic library dependencies** → importing entire packages (`import _ from 'lodash'`) instead of cherry-picking or using dynamic imports (`[BUNDLE_BLOAT]`).
- **Non-semantic HTML lacking keyboard navigation or ARIA semantics** → `div` or `span` elements with `onClick` missing `role="button"`, `tabIndex`, or keypress handlers (`[A11Y_VIOLATION]`).
- **Uncleaned DOM event listeners, RxJS subscriptions, or timers in lifecycle hooks** → missing teardown in `useEffect`, `onUnmounted`, or `ngOnDestroy` (`[MEMORY_LEAK]`).
- **Layout shifts (CLS risks) caused by un-sized images or dynamic content insertion** → img tags without `width`/`height` or aspect-ratio CSS rules.

## Rules (DO) — with rationale
1. **Enforce strict render isolation & memoization.** Keep dynamic component state low in the tree. Wrap expensive list items and child trees in memoization guards (`[UNNECESSARY_RERENDER]`).
2. **Protect the 16.6ms frame budget (INP / LCP).** Offload CPU-heavy sorting, filtering, or JSON transformations to Web Workers or chunked micro-tasks (`[MAIN_THREAD_BLOCK]`).
3. **Enforce WCAG AA accessibility compliance.** All interactive controls must be keyboard-accessible (`Tab`, `Enter`, `Space`) with visible focus rings and screen-reader accessible names (`[A11Y_VIOLATION]`).
4. **Enforce complete lifecycle cleanup.** Every `addEventListener`, `IntersectionObserver`, `setInterval`, or store subscription MUST return a teardown callback (`[MEMORY_LEAK]`).
5. **Optimize bundle size and route-based code-splitting.** Enforce dynamic imports (`React.lazy`, Next.js `dynamic`, ES dynamic `import()`) for heavy modals, charts, or non-critical routes (`[BUNDLE_BLOAT]`).
6. **Guard against Cumulative Layout Shift (CLS).** Enforce explicit aspect ratios or reserved skeleton containers for dynamically loaded media and async data.

## Anti-patterns (DON'T) → fix
| ❌ Anti-pattern | Why it hurts | ✅ Do instead |
|---|---|---|
| Passing inline objects/functions to child props | Forces full child tree re-render on every parent render | Memoize callback with `useCallback` and objects with `useMemo` (`[UNNECESSARY_RERENDER]`) |
| `<div onClick={handleClick}>Submit</div>` | Inaccessible to keyboard users and screen readers | Use native `<button type="button" onClick={handleClick}>` (`[A11Y_VIOLATION]`) |
| Synchronous parsing of 5MB JSON response | Freezes browser UI thread; causes high INP penalty | Parse/transform data inside a Web Worker thread (`[MAIN_THREAD_BLOCK]`) |
| `useEffect(() => { window.addEventListener('resize', cb) }, [])` | Leaks listener when component unmounts; degrades performance | Return cleanup function: `return () => window.removeEventListener('resize', cb)` (`[MEMORY_LEAK]`) |
| Direct full package import: `import { Icon } from 'lucide-react'` | Pulls unused icons into main bundle; increases LCP time | Path import or dynamic import specific sub-modules (`[BUNDLE_BLOAT]`) |
| Async image load without reserved dimensions | Causes visible layout shift (CLS) as image loads | Set explicit `width`, `height`, or `aspect-ratio` CSS |

## Worked examples ❌ → ✅

**1 — Render Isolation & Memoization (React / Next.js)**
```tsx
// ❌ Unnecessary Re-renders: Inline object and function force HeavyTable to re-render on count tick
function Dashboard({ data }) {
  const [count, setCount] = useState(0);
  return (
    <div>
      <button onClick={() => setCount(c => c + 1)}>Tick {count}</button>
      <HeavyTable data={data} options={{ filterActive: true }} onRowSelect={(id) => console.log(id)} />
    </div>
  );
}

// ✅ Staff+ Review: Memoized props & stable callbacks isolate HeavyTable renders [UNNECESSARY_RERENDER]
const HeavyTableMemo = React.memo(HeavyTable);

function Dashboard({ data }) {
  const [count, setCount] = useState(0);
  const options = useMemo(() => ({ filterActive: true }), []);
  const handleRowSelect = useCallback((id: string) => console.log(id), []);

  return (
    <div>
      <button onClick={() => setCount(c => c + 1)}>Tick {count}</button>
      <HeavyTableMemo data={data} options={options} onRowSelect={handleRowSelect} />
    </div>
  );
}
```

**2 — Accessibility & Event Teardown**
```tsx
// ❌ Inaccessible modal trigger & uncleaned window keydown listener
function SearchDialog({ onClose }: { onClose: () => void }) {
  useEffect(() => {
    window.addEventListener('keydown', (e) => {
      if (e.key === 'Escape') onClose();
    });
    // [MEMORY_LEAK] Missing listener cleanup
  }, []);

  return (
    <div className="overlay" onClick={onClose}>
      <div className="modal">
        <span onClick={onClose}>X</span> {/* [A11Y_VIOLATION] Not focusable or screen-reader accessible */}
      </div>
    </div>
  );
}

// ✅ Staff+ Review: Accessible dialog semantics, keyboard navigation & clean teardown [A11Y_VIOLATION] [MEMORY_LEAK]
function SearchDialog({ onClose }: { onClose: () => void }) {
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handleKeyDown);
    return () => window.removeEventListener('keydown', handleKeyDown);
  }, [onClose]);

  return (
    <div className="overlay" onClick={onClose} role="presentation">
      <div className="modal" role="dialog" aria-modal="true" aria-label="Search Dialog">
        <button type="button" onClick={onClose} aria-label="Close dialog" className="close-btn">
          ✕
        </button>
      </div>
    </div>
  );
}
```

## Review checklist (PR-ready)
- [ ] **DOM Render Isolation:** Dynamic state is localized; expensive components use `React.memo`, `shouldComponentUpdate`, or Vue `computed` (`[UNNECESSARY_RERENDER]`).
- [ ] **Main Thread Protection:** Heavy calculations, sorting, or large payload transformations execute in Web Workers (`[MAIN_THREAD_BLOCK]`).
- [ ] **Accessibility (a11y):** Interactive elements use semantic HTML tags (`<button>`, `<a>`), visible focus rings, and valid ARIA attributes (`[A11Y_VIOLATION]`).
- [ ] **Lifecycle Teardown:** All `addEventListener`, `setInterval`, `IntersectionObserver`, and store subscriptions return cleanups (`[MEMORY_LEAK]`).
- [ ] **Bundle Hygiene:** Route-level code-splitting is enabled; dependencies are tree-shaken and path-imported (`[BUNDLE_BLOAT]`).
- [ ] **Layout Stability:** Media elements and async dynamic content reserve layout space to prevent CLS degradation.
- [ ] **SSR / CSR Boundaries:** Next.js / Nuxt client components (`'use client'`) are pushed down to leaf nodes rather than wrapping whole pages.

## Self-audit protocol (mandatory before publishing findings)

Do not publish a finding straight out of the checklist scan above. Every flagged issue must survive three passes:

1. **Investigate in context.** Before tagging anything, open the surrounding code: the parent component, how the prop/hook is used elsewhere in the tree, whether cleanup/memoization already exists one level up, whether the "heavy" computation is actually on the hot path. A tag without a code citation backing it is not a finding yet — it's a hypothesis.
2. **Adversarial self-review.** Re-read your own Phase 1 findings as a skeptical second reviewer would, actively trying to disprove each one. For each finding, decide explicitly:
   - **CONFIRMED** — cite the exact line(s)/pattern that prove the issue holds.
   - **FALSE POSITIVE** — explain concretely why the concern doesn't apply here (e.g., component is already wrapped in `React.memo` by the parent, the listener is already torn down in a different effect, the prop is a stable ref from `useRef`, the "heavy" loop runs on a dataset capped at 20 items).
   Discard or downgrade anything that doesn't survive this pass — do not keep a finding "just in case."
3. **Coverage gap check.** Re-read the full checklist above item by item. Explicitly list which checklist items you did **not** verify in this diff — because the relevant code lives outside the diff, context was insufficient, or the file wasn't touched — instead of silently skipping them.

Publish only **CONFIRMED** findings from Phase 2 as review comments, each with its supporting code citation. Publish the Phase 3 gap list as a separate summary comment (not mixed in with findings) so the human reviewer knows exactly what was and wasn't checked.

## Definition of Done
A Web Frontend PR is approved when Core Web Vitals (LCP, CLS, INP) are protected from degradation, component renders are isolated without cascading un-memoized tree re-renders, the browser main thread remains unblocked during heavy operations, interactive controls meet WCAG AA keyboard and screen-reader accessibility standards, lifecycle subscriptions teardown cleanly without memory leaks, JS bundle sizes are verified against unnecessary bloat, and every reported finding has passed the self-audit protocol above.

## Stack-specific gotchas
- **React 18 Automatic Batching:** State updates inside async promises batch automatically, but inline objects passed to non-memoized children still bypass batching benefits.
- **Next.js `'use client'` Waterfall:** Placing `'use client'` at a top-level layout forces the entire sub-tree into the client JS bundle, disabling SSR streaming optimizations.
- **Vue 3 Reactivity Loss:** Destructuring props inside Vue `setup()` breaks reactivity unless `toRefs()` or `toRef()` is used.
- **CSS `will-change` Abuse:** Overusing `will-change: transform` consumes massive GPU memory layers on mobile browsers.

## Evidence tags
- `[UNNECESSARY_RERENDER]` — Component re-renders excessively due to un-memoized props, inline functions, or lifted state.
- `[MAIN_THREAD_BLOCK]` — Heavy processing/regex/parsing executing on the browser main thread causing INP / input latency.
- `[A11Y_VIOLATION]` — Missing ARIA attributes, non-keyboard accessible elements, or poor focus visibility.
- `[MEMORY_LEAK]` — Uncleaned event listeners, observers, or subscriptions on component unmount.
- `[BUNDLE_BLOAT]` — Large un-tree-shaken imports or missing route code-splitting expanding JS bundle size.