# Frontend rule module — Next.js / React

**Append to `<project>/.claude/rules.md`** when the project uses Next.js (App Router or Pages Router).

---

### W-NEXT-01 — All pages render real data, not mocks
**Status:** ACTIVE
**Why:** Mock pages slip into production. Hardcoded arrays of fake data lie to users.
**Detect:** components with hardcoded arrays of fake data, "TODO: fetch from API" comments, mock data files imported by pages.
**Fix:** every page hits a real endpoint via TanStack Query / SWR / native fetch in server components. Move mocks to `__mocks__/` for test fixtures only.

### W-NEXT-02 — Use TanStack Query / SWR for all server data
**Status:** ACTIVE
**Detect:** `useEffect(() => { fetch('...') })` for server data in client components.
**Fix:** `useQuery({ queryKey, queryFn })` (TanStack) or `useSWR(...)` (SWR). Server components can use direct `fetch` with Next.js cache options.

### W-NEXT-03 — Error boundaries on every route segment
**Status:** ACTIVE
**Why:** Without error boundaries, a single component crash brings down the whole page.
**Detect:** App Router segments without `error.tsx` files. Pages Router pages without an error boundary wrapper.
**Fix:** add `app/<segment>/error.tsx` for App Router. Wrap pages in an error boundary HOC for Pages Router.

### W-NEXT-04 — No duplicate routes
**Status:** ACTIVE
**Detect:** any two route components with identical or near-identical content (e.g. `/dashboard` and `/dashboard/overview` byte-identical).
**Fix:** pick one, delete the other, redirect via `next.config.js` `redirects()`.

### W-NEXT-05 — Forms use react-hook-form + zod
**Status:** ACTIVE
**Detect:** uncontrolled inputs, manual `useState` form state, no client-side validation, form submission without resolver.
**Fix:** `useForm({ resolver: zodResolver(schema) })`. Schema is shared between client (for UX) and server (for security).

### W-NEXT-06 — `'use client'` only when needed
**Status:** ACTIVE
**Why:** Adding `'use client'` to a component that doesn't need it ships JavaScript to the browser unnecessarily, hurting performance.
**Detect:** `'use client'` directive on components that don't use hooks, browser APIs, or event handlers.
**Fix:** remove the directive. Use server components by default; opt into client components only when interactivity is needed.

### W-NEXT-07 — `next/image` instead of raw `<img>` tags
**Status:** ACTIVE
**Why:** `next/image` provides automatic optimization, lazy loading, and CLS prevention.
**Detect:** raw `<img src={...} />` tags in JSX (allowed in `node_modules` and external embeds).
**Fix:** `import Image from 'next/image'` and use `<Image src={...} alt={...} width={...} height={...} />`.

### W-NEXT-08 — `next/link` for internal navigation
**Status:** ACTIVE
**Why:** `<a href="/internal">` causes a full page reload. `next/link` does client-side navigation.
**Detect:** `<a href="/...">` (not external URLs) in JSX.
**Fix:** `import Link from 'next/link'` and use `<Link href="/...">`.

### W-NEXT-09 — Don't expose API errors verbatim in toasts
**Status:** ACTIVE (reinforces S-13)
**Detect:** `toast.error(err.message)`, `<div>{error.message}</div>` rendering API error responses without filtering.
**Fix:** centralize via `formatErrorForUser(err)` helper. In production, return generic message. In dev/staging, show detail.

### W-NEXT-10 — Colors come from theme tokens, not hardcoded hex
**Why:** Hardcoded hex (inline `style`, arbitrary values like `text-[#3b82f6]`/`bg-[#123]`, raw hex in CSS-in-JS) bypasses the design system, breaks theming/dark mode, and drifts across the app.
**Detect:** hex literals (`#RGB`/`#RRGGBB`) in `style={{}}`/CSS-in-JS, `className` arbitrary-value brackets containing a hex (`[#...]`), or component code; new colors not registered as a theme token or CSS custom property.
**Fix:** define the color once as a design token — the Tailwind theme (`tailwind.config`/`@theme`) or a CSS variable, referenced via `text-primary`/`bg-card`/`var(--color-...)` — and reference the semantic token. Reuse an existing token before adding a new one.

---

## Performance & Web Vitals (PERF rules)

**Performance is always in scope.** These apply to EVERY page, route, component, button, image, font, and loading state, not just routes flagged in a Vercel Speed Insights / Lighthouse report. Tools only sample pages users visit, so an unflagged route is "untested", not "fast". Build every surface as if it will be measured on the full Web Vitals set — **LCP** (load), **FCP** (first paint), **INP** (interactivity), **CLS** (visual stability), **TTFB** (server latency) — plus bundle size, because eventually it is. L1/L2 (semantic) rules: enforced by `/x-implement` Phase 2 and `/x-check`, not the regex pre-commit hook.

### PERF-01 — The LCP element must paint immediately (no opacity-from-0 entrance)
**Status:** ACTIVE
**Why:** An element animated from `opacity: 0` is invisible until JS hydrates and the animation runs, so the browser cannot count it as the Largest Contentful Paint until then — the most common LCP regression (hero headings, page titles, primary cards). Transform/scale entrances are fine; opacity-from-0 on the largest above-the-fold element is not.
**Detect:** `motion`/framer/CSS with `initial={{ opacity: 0, ... }}`, `opacity-0` + transition, or `@keyframes` fading from `opacity:0` on a hero heading, page `<h1>`, primary card, or above-the-fold image wrapper.
**Fix:** animate transform only (`{ y: 8 }` / `translateY` / `scale`), keeping the element at full opacity from first paint.

### PERF-02 — Loading/skeleton states must contain a real contentful element (FCP)
**Status:** ACTIVE
**Why:** A skeleton built only from background-color / shimmer boxes is NOT a First Contentful Paint candidate (FCP counts text, images, SVG, canvas, background-images — not background-color). A route whose first render is all-gray skeleton defers FCP until real content lands after the client fetch.
**Detect:** loading branches / `loading.tsx` / Suspense fallbacks that render only skeleton boxes with no real text/heading/SVG, on a route whose content is client-fetched.
**Fix:** render the route's static heading/eyebrow as real text in the loading state (identical to the loaded state, so no flash), then skeletons for the dynamic parts.

### PERF-03 — Above-the-fold LCP image uses `next/image` + `priority` + `sizes`; below-fold stays lazy
**Status:** ACTIVE (extends W-NEXT-07)
**Why:** The above-the-fold hero/avatar image is often the LCP element; without `priority` it lazy-loads and LCP waits on it. Marking below-fold images `priority` wastes bandwidth and delays the real candidate.
**Detect:** above-the-fold `<Image>` (hero, avatar, first card) without `priority`/`fetchPriority="high"`; OR `priority` on below-fold images (galleries, lists, grids).
**Fix:** `priority` + accurate `sizes` on the single above-the-fold LCP image only; everything else stays default-lazy.

### PERF-04 — Heavy / route-specific / optional dependencies must be code-split, never eager in the root tree
**Status:** ACTIVE
**Why:** Anything statically imported into the root layout, the providers tree, or a shared component ships in EVERY route's first-load bundle, including static guest pages that never use it. Common offenders: maps, ML/vision (MediaPipe/TF), charting, realtime (websocket/pusher/firebase), social-login, rich editors, image-crop. Each eager megabyte is paid by mobile users on first paint.
**Detect:** static `import` of a heavy or route-specific library at the top of the root `layout`, the providers file, `app-shell`, `header`, or any component rendered on guest/static routes; a provider in the root tree for a feature only some routes use.
**Fix:** `next/dynamic` (with `ssr: false` where client-only) so the module loads only on the routes that need it. Verify via PERF-09 that the dep is absent from the guest/shared bundle.
**`ssr:false` bailout trap (important):** a `dynamic(ssr:false)` placed inside a component that should server-render bails that component's ENTIRE subtree out of SSR (emits `BAILOUT_TO_CLIENT_SIDE_RENDERING`) — so the surrounding content (often the LCP element) renders client-only, delaying LCP/FCP and causing a layout shift (CLS) when it pops in. Fix: keep any `ssr:false` import in an isolated LEAF client component wrapped in its own `<Suspense fallback={...}>`, so the bail is contained to that leaf and its siblings still server-render.

### PERF-05 — Disabled / feature-flagged-off features must not ship their dependencies
**Status:** ACTIVE
**Why:** A feature gated behind `FLAG && <X/>` still bundles `X` and its deps if `X` is statically imported, even when the flag is permanently off (e.g. a disabled social-login still loading its SDK + third-party script on every route via an eager provider).
**Detect:** a component/provider behind a `false` (or env-off) flag that is still statically imported; a provider in the root tree for a disabled feature.
**Fix:** `next/dynamic` the flagged component so its module loads only when the flag renders it; don't wrap the root tree in a disabled feature's provider. Comment the flag for re-enabling.

### PERF-06 — Font preload discipline
**Status:** ACTIVE
**Why:** Each preloaded webfont competes for bandwidth on first paint. Preload only faces that render above the fold; preloading rarely-used faces (mono, secondary display) slows the critical ones.
**Detect:** `next/font` faces with default preload (preload omitted) that are only used in non-critical / below-the-fold spots; missing `display: "swap"`.
**Fix:** `preload: false` on non-critical faces (they still load on demand with swap); keep the body + above-the-fold display face preloaded.

### PERF-07 — Client-gated routes stream a `loading.tsx`
**Status:** ACTIVE
**Why:** Authenticated CSR routes wait on store hydration + data fetch before content paints. A route-level `loading.tsx` streams an instant skeleton on navigation instead of a frozen previous screen.
**Detect:** a client route segment gated on auth/hydration with no sibling `loading.tsx`; duplicated skeleton markup between `loading.tsx` and the page.
**Fix:** extract the page skeleton into a shared component and render it from both the page's pre-ready branch and `loading.tsx`. Skeletons must still satisfy PERF-02.

### PERF-08 — Public read-only SSR data is cached (ISR), not refetched per request
**Status:** ACTIVE
**Why:** A server-side fetch on every request makes TTFB (and therefore FCP) hostage to backend latency. Public, slowly-changing data should serve cached HTML.
**Detect:** server `fetch` / SSR data calls for public read-only data without `next: { revalidate }`; duplicate SSR round-trips not wrapped in `React.cache()`.
**Fix:** set a sensible `revalidate` and dedupe with `React.cache()` so `generateMetadata` + the page share one round-trip. Never cache authenticated/per-user SSR data this way.

### PERF-09 — Verify the production bundle before deploying
**Status:** ACTIVE (process rule — the deploy gate)
**Why:** Web Vitals regressions ship silently; a single eager heavy import balloons every route's first-load JS and you only find out days later when field data samples it.
**Detect:** N/A (process). Applies whenever a change adds a dependency, a provider, a top-level import, or a heavy component.
**Fix:** run `next build` and confirm (a) no heavy dep leaked into the guest/shared first-load bundle (PERF-04/05), (b) per-route First Load JS didn't regress, (c) routes that should be static stayed static. For deeper analysis, fingerprint `.next/static/chunks` against the route HTML in `.next/server/app/*.html`.

### PERF-10 — INP: keep interaction handlers light (Interaction to Next Paint)
**Status:** ACTIVE
**Why:** INP measures the delay from a user interaction (tap, click, keypress) to the next paint; target under 200ms. Long synchronous work in handlers, large unmemoized re-renders, and refetch-on-interaction block the main thread. Common offender: tab/filter switches that re-render a big list and refire a query synchronously.
**Detect:** heavy synchronous work in `onClick`/`onChange`/`onInput`; filtering/sorting a large list inline on each keystroke or tab change without `useDeferredValue`/`useTransition`; expensive list rows re-rendering on every parent state change without `React.memo`; layout-animating on interaction; `setState` cascades.
**Fix:** keep handlers to a few ms; wrap non-urgent updates in `useTransition`, derive filtered/sorted views with `useDeferredValue`; memoize rows (`React.memo`) + stabilize callbacks (`useCallback`); debounce/throttle high-frequency inputs; precompute or defer heavy work off the interaction path; animate transform/opacity (compositor), never layout.

### PERF-11 — CLS: reserve space, never shift content after paint
**Status:** ACTIVE
**Why:** CLS measures unexpected layout movement (target under 0.1). Images/media without dimensions, skeletons whose size differs from the loaded content, content injected above existing content (banners), and webfont swaps that resize text all shift the page.
**Detect:** `<img>`/media/iframe without width/height or `aspect-ratio`; a skeleton/loading block whose height differs from the content it replaces; banners/notices inserted at the top after load (cookie/install/maintenance); entrance animations that change layout (height/margin) instead of transform; late-loading sections that push content down.
**Fix:** always set width/height or `aspect-ratio` (`next/image` enforces this); make skeleton dimensions match the real content (ties to PERF-02/07); reserve space for late banners (fixed overlay or pre-allocated slot) instead of pushing content; rely on `next/font`'s automatic size-adjust fallback; animate transform/opacity only.

### PERF-12 — TTFB: minimize server latency on the response path
**Status:** ACTIVE
**Why:** TTFB is the floor under FCP/LCP — nothing paints until the first byte arrives (target under 0.8s). Per-request server work inflates it: uncached SSR fetches, blocking calls in `generateMetadata`, cross-region backend round-trips, cold serverless starts.
**Detect:** dynamic (`ƒ`) routes that could be static/ISR; `generateMetadata` or a page awaiting an uncached backend call on every request; a route forced dynamic by an unnecessary `cookies()`/`headers()`/`no-store`; blocking work in the render path that could be cached or deferred.
**Fix:** prefer static or ISR (`revalidate`) rendering; cache public read-only SSR data (PERF-08) + dedupe with `React.cache`; keep `generateMetadata` cheap (cached/minimal query); stream non-critical sections via `<Suspense>` so the shell's first byte isn't blocked; don't opt a route into dynamic rendering unless it genuinely needs per-request data.
