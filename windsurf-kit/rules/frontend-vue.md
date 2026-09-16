# Frontend rule module — Vue 3 (Vite, generic Vue, NOT Nuxt)

**Append to `<project>/.claude/rules.md`** when the project uses Vue 3 but NOT Nuxt.

For Nuxt projects, use `frontend-nuxt.md` instead — it includes everything here plus Nuxt-specific rules.

---

### W-VUE-01 — All pages render real data, not mocks
**Status:** ACTIVE
**Detect:** components with hardcoded arrays of fake data, "TODO: fetch from API" comments.
**Fix:** every page fetches from a real endpoint via Pinia store actions, `vue-query`, `useFetch` composable, or Apollo.

### W-VUE-02 — Use Composition API + `<script setup>` for new components
**Status:** ACTIVE
**Why:** Options API is legacy. Composition API is more performant, has better TypeScript support, and is the documented direction.
**Detect:** new components using `export default { data, methods, computed }` (Options API) instead of `<script setup>`.
**Fix:** use `<script setup lang="ts">` syntax with `ref()`, `computed()`, `watch()`, etc.

### W-VUE-03 — Use Pinia, not Vuex
**Status:** ACTIVE
**Why:** Vuex is in maintenance mode. Pinia is the official Vue state library going forward.
**Detect:** new code importing from `vuex` or extending `Vuex.Store`.
**Fix:** use Pinia: `defineStore('name', () => { ... })` (composition style).

### W-VUE-04 — Use a data-fetching library, not bare `fetch` in components
**Status:** ACTIVE
**Why:** Same reasoning as React — caching, retries, deduplication, stale-while-revalidate.
**Detect:** `onMounted(() => { fetch('...').then(...).then(data => state.value = data) })` patterns.
**Fix:** `vue-query` (TanStack), `@vueuse/core`'s `useFetch`, or custom composable that wraps the data layer.

### W-VUE-05 — Forms use VeeValidate or Vorms with schema validation
**Status:** ACTIVE
**Detect:** form inputs with `v-model` and manual validation in submit handlers.
**Fix:** `VeeValidate` with `yup` or `zod` schema. Or `Vorms`. Schema-driven validation with field-level error display.

### W-VUE-06 — Reactive primitives: `ref` for primitives, `reactive` for objects
**Status:** ACTIVE
**Why:** Mixing them causes confusion and reactivity bugs.
**Detect:** `reactive({ count: 0 })` for a single primitive, or `ref({ user: {...} })` for a deep object.
**Fix:** `ref(0)` for primitives, `reactive({ user: {...} })` for objects, OR consistently use `ref` everywhere with `.value` access.

### W-VUE-07 — Keys in `v-for` use stable IDs, not index
**Status:** ACTIVE
**Detect:** `v-for="(item, i) in items" :key="i"` patterns.
**Fix:** `v-for="item in items" :key="item.id"`.

### W-VUE-08 — `v-html` only with sanitized content
**Status:** ACTIVE (reinforces S-06)
**Detect:** `v-html="userContent"` where `userContent` is from user input.
**Fix:** sanitize via `DOMPurify` first: `v-html="sanitize(userContent)"`.

### W-VUE-09 — Don't expose API errors verbatim
**Status:** ACTIVE (reinforces S-13)
**Detect:** toasts / dialogs displaying `err.message` directly.
**Fix:** centralize via `formatErrorForUser(err)` helper.

### W-VUE-10 — Colors come from theme tokens, not hardcoded hex
**Why:** Hardcoded hex (inline `style`, arbitrary values like `text-[#3b82f6]`/`bg-[#123]`, raw hex in CSS-in-JS) bypasses the design system, breaks theming/dark mode, and drifts across the app.
**Detect:** hex literals (`#RGB`/`#RRGGBB`) in `style={{}}`/CSS-in-JS, `className` arbitrary-value brackets containing a hex (`[#...]`), or component code; new colors not registered as a theme token or CSS custom property.
**Fix:** define the color once as a design token — the Tailwind theme or a CSS variable / `<style>` token, referenced via a semantic class/`var(--color-...)` — and reference the semantic token. Reuse an existing token before adding a new one.

---

## Performance & Web Vitals (PERF rules)

**Performance is always in scope** — every page, component, image, font, and loading state, not just routes a Lighthouse / field-data report flagged. Build every surface for LCP, FCP, CLS, INP. L1/L2 (semantic) rules.

### PERF-01 — The LCP element must paint immediately (no opacity-from-0 entrance)
**Status:** ACTIVE
**Why:** An element animated from `opacity: 0` is not counted as the Largest Contentful Paint until the animation runs. Most common LCP regression (hero headings, page titles, primary cards).
**Detect:** `<Transition>` / CSS / `@vueuse/motion` entrance fading from `opacity:0` on the largest above-the-fold element.
**Fix:** animate transform only (`translateY`/`scale`); keep the element at full opacity from first paint.

### PERF-02 — Loading/skeleton states must contain a real contentful element (FCP)
**Status:** ACTIVE
**Why:** A skeleton built only from background-color / shimmer boxes is NOT an FCP candidate (FCP counts text, images, SVG, canvas, background-images — not background-color), so first paint is deferred until data lands.
**Detect:** `v-if="pending"` loading branches / Suspense fallbacks rendering only skeleton boxes with no real text/heading/SVG.
**Fix:** render the view's static heading/label as real text in the loading state (matches the loaded state, no flash), then skeletons for the dynamic parts.

### PERF-03 — Above-the-fold LCP image is prioritized + sized; below-fold stays lazy
**Status:** ACTIVE
**Why:** The above-the-fold hero/avatar is often the LCP element; without an eager/high-priority hint it lazy-loads and LCP waits. Prioritizing below-fold images wastes bandwidth.
**Detect:** above-the-fold `<img>` without `fetchpriority="high"` / `loading="eager"`; eager/priority on below-fold images.
**Fix:** `fetchpriority="high"` + correct `width`/`height` on the single above-the-fold LCP image only (reserve space to avoid CLS); everything else `loading="lazy"`.

### PERF-04 — Heavy / route-specific / optional dependencies must be code-split, never eager in the root
**Status:** ACTIVE
**Why:** Anything statically imported into `main.ts`/`App.vue`/a global plugin or a shared component ships in EVERY route's initial bundle. Offenders: maps, ML/vision, charting, realtime, social-login SDKs, rich editors, image-crop.
**Detect:** static `import` of a heavy or route-specific library at the app entry, a global plugin, or a component on every route; a global plugin for a feature only some routes use (including disabled/feature-flagged-off features).
**Fix:** `defineAsyncComponent()` or route-level dynamic `import()` (async route components) so the module loads only where needed. Don't register a disabled feature's plugin globally.

### PERF-05 — Verify the production bundle before deploying
**Status:** ACTIVE (process rule — the deploy gate)
**Why:** Web Vitals regressions ship silently; one eager heavy import balloons the initial bundle and you find out days later from field data.
**Detect:** N/A (process). Applies whenever a change adds a dependency, a global plugin, a top-level import, or a heavy component.
**Fix:** run `vite build` and confirm no heavy dep leaked into the entry chunk and the initial bundle didn't regress. Use `rollup-plugin-visualizer` for attribution.

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
