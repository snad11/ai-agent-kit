# Frontend rule module — Nuxt 3 / Vue

**Append to `<project>/.claude/rules.md`** when the project uses Nuxt 3.

Includes everything from `frontend-vue.md` PLUS Nuxt-specific rules. If you're appending this file, also append `frontend-vue.md` first.

---

### W-NUXT-01 — Use `useFetch` / `useAsyncData` for SSR-safe data fetching
**Status:** ACTIVE
**Why:** Bare `fetch` in component setup runs on the server AND the client, causing duplicate requests and hydration mismatches.
**Detect:** `<script setup>` blocks with bare `fetch` / `axios` calls instead of Nuxt's data composables.
**Fix:** `const { data } = await useFetch('/api/x')` for simple cases. `useAsyncData('key', () => $fetch('/api/x'))` for control over caching keys.

### W-NUXT-02 — Server routes use `defineEventHandler` + validate input
**Status:** ACTIVE
**Why:** Nuxt server routes (`server/api/`) are full backend endpoints. Same validation requirements as any backend.
**Detect:** server routes that read `event.body` or `getQuery(event)` without validation.
**Fix:** use `readBody(event)` then validate with `zod` / `valibot` schema. Reject invalid input with `createError({ statusCode: 400, message: '...' })`.

### W-NUXT-03 — Server routes require auth check
**Status:** ACTIVE
**Why:** Nuxt server routes are NOT auth-gated by default. Anyone can hit them.
**Detect:** server routes that mutate state without checking session / token.
**Fix:** use `nuxt-auth` / custom session middleware. Every protected route calls `requireAuth(event)` or equivalent at the top.

### W-NUXT-04 — `useState` for SSR-safe shared state
**Status:** ACTIVE
**Why:** Module-level `let state = ...` is shared across requests on the server, causing data leaks between users.
**Detect:** module-level mutable state (`let`, `var`) at the top of composables or stores accessed during SSR.
**Fix:** use `useState('key', () => initial)` (Nuxt's SSR-safe state) or Pinia with `definePiniaStore`.

### W-NUXT-05 — `useNuxtApp().$config` for runtime config (not `process.env`)
**Status:** ACTIVE
**Why:** `process.env.X` only works at build time. Runtime config is exposed via Nuxt's runtime config system.
**Detect:** `process.env.X` accessed in `<script setup>` blocks (client code).
**Fix:** declare in `nuxt.config.ts`:
```ts
runtimeConfig: {
  apiSecret: '', // server-only
  public: { apiBase: '' } // exposed to client
}
```
Then access via `useRuntimeConfig().public.apiBase`.

### W-NUXT-06 — `<NuxtLink>` for internal navigation, not `<a>`
**Status:** ACTIVE
**Why:** `<a href="/internal">` causes a full reload. `<NuxtLink>` does client-side navigation.
**Detect:** `<a href="/...">` for internal routes.
**Fix:** `<NuxtLink to="/...">`.

### W-NUXT-07 — `<NuxtImg>` for optimized images
**Status:** ACTIVE
**Why:** Nuxt Image module provides automatic optimization, lazy loading, responsive sizing.
**Detect:** raw `<img src="...">` in templates.
**Fix:** `<NuxtImg src="..." :width="..." :height="..." />`.

### W-NUXT-08 — Colors come from theme tokens, not hardcoded hex
**Why:** Hardcoded hex (inline `style`, arbitrary values like `text-[#3b82f6]`/`bg-[#123]`, raw hex in CSS-in-JS) bypasses the design system, breaks theming/dark mode, and drifts across the app.
**Detect:** hex literals (`#RGB`/`#RRGGBB`) in `style={{}}`/CSS-in-JS, `className` arbitrary-value brackets containing a hex (`[#...]`), or component code; new colors not registered as a theme token or CSS custom property.
**Fix:** define the color once as a design token — the Tailwind theme or app CSS variables, referenced via a semantic class/`var(--color-...)` — and reference the semantic token. Reuse an existing token before adding a new one.

---

## Performance & Web Vitals (PERF rules)

**Performance is always in scope** — every page, component, image, font, and loading state, not just routes a Lighthouse / field-data report flagged. Build every surface for LCP, FCP, CLS, INP. L1/L2 (semantic) rules. (Append `frontend-vue.md`'s PERF rules too; these are the Nuxt-specific refinements.)

### PERF-N01 — The LCP element must paint immediately (no opacity-from-0 entrance)
**Status:** ACTIVE
**Why:** An element animated from `opacity: 0` is not counted as the Largest Contentful Paint until the animation runs.
**Detect:** page-transition / `<Transition>` / motion entrance fading from `opacity:0` on the largest above-the-fold element.
**Fix:** animate transform only; keep the element at full opacity from first paint.

### PERF-N02 — Loading states must be FCP-contentful; prioritize the LCP image
**Status:** ACTIVE
**Why:** All-gray skeletons are not FCP candidates; an unprioritized above-the-fold image delays LCP.
**Detect:** `useFetch`/`useAsyncData` pending branches rendering only skeleton boxes; `<NuxtImg>`/`<NuxtPicture>` above the fold without `preload`/high priority; eager loading on below-fold media.
**Fix:** render static text in the pending state; set `<NuxtImg preload>` (+ correct sizes) on the single above-the-fold LCP image only; lazy the rest.

### PERF-N03 — Heavy / route-specific / disabled deps are lazy; cache server data; verify the bundle
**Status:** ACTIVE
**Why:** Eager heavy imports in `app.vue`/plugins/layouts bloat every route's first load; uncached SSR `useFetch` makes TTFB hostage to the API; regressions ship silently.
**Detect:** static import of heavy/route-specific/disabled-feature deps at the app entry, a plugin, or a global layout; `useFetch`/`useAsyncData` for public read-only data without caching (`getCachedData` / route rules `swr`/`isr`); no production-bundle check before deploy.
**Fix:** `defineAsyncComponent`, the `Lazy` component prefix, or `import()`; don't register disabled features' plugins; cache public read-only data via Nitro route rules (`swr`/`isr`) or `getCachedData`; run `nuxi build` and check the client bundle / `.output` before deploying.

### PERF-N04 — INP: keep interaction handlers light
**Status:** ACTIVE
**Why:** INP measures interaction-to-next-paint (target under 200ms); long synchronous handlers and large re-renders block the main thread.
**Detect:** heavy work in `@click`/`@input` handlers; filtering large lists in a `computed` on each keystroke; non-virtualized long lists; layout-animating on interaction.
**Fix:** debounce/throttle inputs; memoize with `computed`/`v-memo`/`shallowRef`; virtualize long lists; defer heavy work (`nextTick`/idle); animate transform/opacity only.

### PERF-N05 — CLS: reserve space, never shift content after paint
**Status:** ACTIVE
**Why:** Unexpected layout movement (target under 0.1) comes from undimensioned media, mismatched skeletons, late banners, and font swaps.
**Detect:** `<NuxtImg>`/`<img>`/media without width/height or `aspect-ratio`; skeleton size differing from loaded content; banners inserted above existing content after load; layout-changing entrance animations.
**Fix:** set width/height or `aspect-ratio` (`<NuxtImg>` supports this); match skeleton dimensions to content; reserve space for late content; size-adjusted font fallback; animate transform/opacity only.
