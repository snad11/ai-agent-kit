# Frontend rule module — React (Vite / CRA / generic React, NOT Next.js)

**Append to `<project>/.claude/rules.md`** when the project uses React but NOT Next.js (e.g. Vite, Create React App, Remix, Astro+React).

For Next.js projects, use `frontend-next.md` instead — it includes everything here plus Next.js-specific rules.

---

### W-REACT-01 — All pages render real data, not mocks
**Status:** ACTIVE
**Detect:** components with hardcoded arrays of fake data, "TODO: fetch from API" comments.
**Fix:** every page hits a real endpoint via TanStack Query / SWR / Apollo / RTK Query.

### W-REACT-02 — Use a data-fetching library, not bare `useEffect + fetch`
**Status:** ACTIVE
**Why:** `useEffect + fetch` lacks caching, retries, deduplication, and stale-while-revalidate. Causes race conditions on rapid navigation.
**Detect:** `useEffect(() => { fetch('...').then(...).then(setData) })` patterns.
**Fix:** TanStack Query: `useQuery({ queryKey, queryFn })`. SWR: `useSWR(key, fetcher)`. RTK Query: `useGetXQuery()`.

### W-REACT-03 — Error boundaries on every top-level route
**Status:** ACTIVE
**Detect:** routes without an `<ErrorBoundary>` wrapper.
**Fix:** `react-error-boundary` library is the standard. Wrap each top-level route.

### W-REACT-04 — Forms use react-hook-form + zod (or equivalent)
**Status:** ACTIVE
**Detect:** uncontrolled inputs, manual `useState` form state without validation library.
**Fix:** `useForm({ resolver: zodResolver(schema) })` or Formik + Yup.

### W-REACT-05 — Memoize expensive computations + child renders
**Status:** ACTIVE
**Why:** Without `useMemo` / `useCallback` / `React.memo`, parents re-rendering trigger unnecessary child re-renders.
**Detect:** components that pass new object/array literals as props every render. Expensive computations in render bodies without `useMemo`.
**Fix:** `useMemo(() => expensiveFn(), [deps])`. `useCallback(() => fn, [deps])` for handler functions passed as props. `React.memo(Component)` for pure children.

### W-REACT-06 — Keys in lists use stable IDs, not array index
**Status:** ACTIVE
**Why:** Index keys cause incorrect element identity when the list reorders, leading to bugs in animations, focus, and stateful children.
**Detect:** `xs.map((x, i) => <Component key={i} ... />)` patterns.
**Fix:** `xs.map((x) => <Component key={x.id} ... />)`.

### W-REACT-07 — Don't expose API errors verbatim in toasts
**Status:** ACTIVE (reinforces S-13)
**Detect:** `toast.error(err.message)`, `<div>{error.message}</div>` rendering API error responses without filtering.
**Fix:** centralize via `formatErrorForUser(err)` helper.

### W-REACT-08 — Colors come from theme tokens, not hardcoded hex
**Why:** Hardcoded hex (inline `style`, arbitrary values like `text-[#3b82f6]`/`bg-[#123]`, raw hex in CSS-in-JS) bypasses the design system, breaks theming/dark mode, and drifts across the app.
**Detect:** hex literals (`#RGB`/`#RRGGBB`) in `style={{}}`/CSS-in-JS, `className` arbitrary-value brackets containing a hex (`[#...]`), or component code; new colors not registered as a theme token or CSS custom property.
**Fix:** define the color once as a design token — the Tailwind theme or a CSS variable, referenced via a semantic class/`var(--color-...)` — and reference the semantic token. Reuse an existing token before adding a new one.

---

## Performance & Web Vitals (PERF rules)

**Performance is always in scope** — every page, component, image, font, and loading state, not just routes a Lighthouse / field-data report flagged. Build every surface for LCP, FCP, CLS, INP. L1/L2 (semantic) rules.

### PERF-01 — The LCP element must paint immediately (no opacity-from-0 entrance)
**Status:** ACTIVE
**Why:** An element animated from `opacity: 0` is not counted as the Largest Contentful Paint until JS runs the animation. Most common LCP regression (hero headings, page titles, primary cards).
**Detect:** `framer-motion`/CSS `initial={{ opacity: 0 }}`, `opacity-0` + transition, or `@keyframes` fading from `opacity:0` on the largest above-the-fold element.
**Fix:** animate transform only (`translateY`/`scale`); keep the element at full opacity from first paint.

### PERF-02 — Loading/skeleton states must contain a real contentful element (FCP)
**Status:** ACTIVE
**Why:** A skeleton built only from background-color / shimmer boxes is NOT an FCP candidate (FCP counts text, images, SVG, canvas, background-images — not background-color), so first paint is deferred until data lands.
**Detect:** loading branches / Suspense fallbacks rendering only skeleton boxes with no real text/heading/SVG on a data-fetched view.
**Fix:** render the view's static heading/label as real text in the loading state (matches the loaded state, no flash), then skeletons for the dynamic parts.

### PERF-03 — Above-the-fold LCP image is prioritized + sized; below-fold stays lazy
**Status:** ACTIVE
**Why:** The above-the-fold hero/avatar is often the LCP element; without an eager/high-priority hint it lazy-loads and LCP waits. Prioritizing below-fold images wastes bandwidth.
**Detect:** above-the-fold image without `fetchpriority="high"` / `loading="eager"` (or the framework image component's priority prop); `priority`/eager on below-fold images.
**Fix:** `fetchpriority="high"` + correct `sizes`/dimensions on the single above-the-fold LCP image only (reserve space to avoid CLS); everything else `loading="lazy"`.

### PERF-04 — Heavy / route-specific / optional dependencies must be code-split, never eager in the root
**Status:** ACTIVE
**Why:** Anything statically imported into the app root, providers, or a shared component ships in EVERY route's initial bundle. Offenders: maps, ML/vision, charting, realtime (websocket/pusher/firebase), social-login SDKs, rich editors, image-crop.
**Detect:** static `import` of a heavy or route-specific library at the app entry, the providers file, or a component on every route; a provider at the root for a feature only some routes use (including disabled/feature-flagged-off features — their deps must not ship).
**Fix:** `React.lazy()` + `<Suspense>` or route-level dynamic `import()` so the module loads only where needed. Don't wrap the app in a disabled feature's provider.

### PERF-05 — Verify the production bundle before deploying
**Status:** ACTIVE (process rule — the deploy gate)
**Why:** Web Vitals regressions ship silently; one eager heavy import balloons the initial bundle and you find out days later from field data.
**Detect:** N/A (process). Applies whenever a change adds a dependency, a provider, a top-level import, or a heavy component.
**Fix:** run the production build (`vite build` / `npm run build`) and confirm no heavy dep leaked into the main/entry chunk and the initial bundle didn't regress. Use the bundle visualizer (`rollup-plugin-visualizer` / `source-map-explorer`) for attribution.

### PERF-06 — INP: keep interaction handlers light (Interaction to Next Paint)
**Status:** ACTIVE
**Why:** INP measures the delay from a user interaction (tap, click, keypress) to the next paint; target under 200ms. Long synchronous work in handlers, large unmemoized re-renders, and refetch-on-interaction block the main thread. Common offender: tab/filter switches that re-render a big list synchronously.
**Detect:** heavy synchronous work in event handlers; filtering/sorting a large list inline on each keystroke or tab change; long non-virtualized lists re-rendering on parent state change; layout-animating on interaction.
**Fix:** keep handlers to a few ms; debounce/throttle high-frequency inputs; memoize rows + derived views (React: `React.memo`/`useMemo`/`useDeferredValue`/`useTransition`; Vue: `v-memo`/`computed`/`shallowRef`); virtualize long lists; defer heavy work off the interaction path; animate transform/opacity (compositor), never layout.

### PERF-07 — CLS: reserve space, never shift content after paint
**Status:** ACTIVE
**Why:** CLS measures unexpected layout movement (target under 0.1). Images/media without dimensions, skeletons whose size differs from the loaded content, content injected above existing content (banners), and webfont swaps that resize text all shift the page.
**Detect:** `<img>`/media/iframe without width/height or `aspect-ratio`; a skeleton/loading block whose height differs from the content it replaces; banners/notices inserted at the top after load; entrance animations that change layout (height/margin) instead of transform.
**Fix:** always set width/height or `aspect-ratio`; make skeleton dimensions match the real content; reserve space for late content (fixed overlay or pre-allocated slot) instead of pushing content down; use a size-adjusted font fallback (`size-adjust`/`@font-face` metrics); animate transform/opacity only.
