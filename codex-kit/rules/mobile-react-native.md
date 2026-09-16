# Mobile rule module — React Native (Expo or bare)

**Append to `<project>/.claude/rules.md`** when the project uses React Native.

---

### M-RN-01 — Use `expo-secure-store` / `react-native-keychain` for tokens
**Status:** ACTIVE (reinforces A-03)
**Why:** `AsyncStorage` is NOT encrypted. Tokens stored there are readable by any app with filesystem access on a rooted/jailbroken device.
**Detect:** `AsyncStorage.setItem('token', ...)`, `AsyncStorage.setItem('jwt', ...)` patterns.
**Fix:** `SecureStore.setItemAsync('token', value)` (Expo) or `Keychain.setGenericPassword(...)` (`react-native-keychain` for bare RN).

### M-RN-02 — All async UI work has loading + error states
**Status:** ACTIVE
**Detect:** `useEffect(() => { fetch(...) })` without `isLoading` / `error` state tracking.
**Fix:** TanStack Query or RTK Query for server data. Native `Suspense` for component-level loading.

### M-RN-03 — Don't expose error messages in production UI
**Status:** ACTIVE (reinforces S-13)
**Detect:** `Alert.alert(error.message)`, `<Text>{error.message}</Text>` without env gate.
**Fix:** `__DEV__ ? \`DEV: ${e}\` : 'Something went wrong'`. Log via Sentry / Bugsnag / structured logger.

### M-RN-04 — Use `FlatList` / `SectionList`, not `<ScrollView>` for long lists
**Status:** ACTIVE
**Why:** `<ScrollView>` renders all children at once. `FlatList` virtualizes — only renders visible items. Difference is dramatic above ~50 items.
**Detect:** `<ScrollView>` containing `xs.map(x => <Item key={x.id} ... />)` patterns where `xs.length` could exceed ~30.
**Fix:** `<FlatList data={xs} renderItem={({ item }) => <Item ... />} keyExtractor={x => x.id} />`.

### M-RN-05 — Memoize list item components
**Status:** ACTIVE
**Why:** FlatList re-renders all visible items when state changes unless items are memoized.
**Detect:** list item components without `React.memo` or `useMemo`.
**Fix:** `const Item = React.memo(({ data }) => ...)`.

### M-RN-06 — `console.log` in committed code
**Status:** ACTIVE (reinforces Q-03)
**Detect:** `console.log` / `console.warn` outside `__tests__/`.
**Fix:** use a logger (Reactotron, Flipper, Sentry breadcrumbs).

### M-RN-07 — Image URIs use `cache: 'force-cache'` or a caching library
**Status:** ACTIVE
**Why:** Without caching, images re-download on every render — burns bandwidth and feels slow.
**Detect:** `<Image source={{ uri: ... }} />` without `react-native-fast-image` or explicit cache policy.
**Fix:** use `react-native-fast-image` for production apps, OR `<Image source={{ uri: ..., cache: 'force-cache' }} />` for simple cases.

### M-RN-08 — Permissions declared in app.json / Info.plist / AndroidManifest
**Status:** ACTIVE
**Why:** Asking for camera/location/contacts at runtime fails silently if not declared in the manifest.
**Detect:** `Camera.request(...)`, `Location.request(...)`, `Contacts.request(...)` calls without corresponding manifest entries.
**Fix:** declare in `app.json` (Expo) `plugins` section, or `Info.plist` (iOS) and `AndroidManifest.xml` (Android) for bare RN.

### M-RN-09 — Don't bundle `__DEV__` checks for production secrets
**Status:** ACTIVE
**Detect:** `if (__DEV__) { useApiKey('test_key') } else { useApiKey('AKIA...') }` patterns where the production key is hardcoded.
**Fix:** use env vars via `react-native-config` / `expo-constants` `extra` field. Production keys come from CI secrets, not bundled in code.
