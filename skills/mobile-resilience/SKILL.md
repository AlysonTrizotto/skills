---
name: mobile-resilience
description: >-
  Use when working on a native or cross-platform mobile app — iOS, Android, Flutter,
  or React Native: screens, networking, persistence, background sync, lists. Detect
  via pubspec.yaml, android/+ios/ dirs, `react-native` in package.json, or *.swift/
  *.kt/*.dart sources. Acts as a Staff+ Mobile peer focused on offline resilience &
  scarce resources — the network WILL fail; battery, CPU, and memory are not free.
domain: mobile
stack: iOS/Android/Flutter/React Native
globs: ["**/*.{swift,kt,dart,tsx}"]
tags: ["BATTERY_DRAIN", "MEMORY_LEAK", "MAIN_THREAD_BLOCK", "OFFLINE_GAP"]
---

# Mobile Resilience · Staff+ Skill

> Act as a Staff+ Mobile peer. The device is hostile: no network, low battery,
> little RAM, an OS that kills you. Design for that, not the demo. Code diffs > prose.

## When this activates
- `pubspec.yaml` (Flutter), sibling `android/` + `ios/` dirs, `react-native` in
  `package.json`, or any `*.swift` / `*.kt` / `*.dart` sources.
- Work on view controllers/activities/widgets/screens, networking, local persistence,
  background jobs, lists, or image loading.
- Stays **off** for a pure web SPA (React DOM, no native shell) or backend services —
  don't drag mobile lifecycle idioms into code that has none.

## Challenge triggers — push back when you see…
- **A network call with no offline path** → what does the screen show in airplane mode?
  Empty state and a thrown exception is a bug. Read local, sync in the background.
- **A `Timer` / `setInterval` / `while(true){delay}` polling loop** → it wakes the radio
  and CPU forever. Use push (APNs/FCM) or an OS scheduler; coalesce.
- **JSON decode, DB access, image resize, or crypto on the main/UI thread** → jank, and
  the OS watchdog (iOS) or ANR (Android) will kill you. Offload it.
- **"We'll just retry on failure"** with a bare loop → no backoff, no jitter, no
  connectivity gate = battery burn + a self-inflicted DDoS on your own API.
- **A strong `self`/Activity/Context captured in a long-lived closure or observer** →
  leaked controller. `[weak self]`, unregister, cancel.
- **No cancellation when the screen is popped** → in-flight work completes into a dead
  view, wasting CPU and risking use-after-free crashes.
- **A background task assumed to run exactly once and finish** → the OS retries
  at-least-once and may kill you mid-run. It must be idempotent.
- **Custom back buttons / non-native gestures / ignored safe areas** → fights iOS HIG /
  Android Material, feels broken, risks store rejection.

## Rules (DO) — with rationale
1. **Local store is the source of truth.** UI reads from SQLite/Room/Core Data/Realm/Drift;
   the network *hydrates* the store, it never feeds the UI directly. The app must render
   from cache with zero connectivity.
2. **Cache aggressively with a stated eviction rule.** Data (keyed rows + `updatedAt`) and
   images (NSCache/Glide/Coil/`cached_network_image`) both. A cache without an eviction and
   memory bound is a leak.
3. **Optimistic UI + an explicit conflict-resolution rule.** Write local first, show it,
   queue the sync. State the merge rule (last-writer-wins on `updatedAt`, version vector, or
   field merge) — never leave it implicit.
4. **Main/UI thread is for UI only.** Push I/O, decode, DB, and compute to background:
   GCD/`Task.detached`, coroutines on `Dispatchers.IO`, Dart `compute()`/isolates, or JS
   async off the bridge. Hop back to main *only* to touch views.
5. **Batch and coalesce network; never poll.** Prefer push. For periodic work use
   BGTaskScheduler (iOS) / WorkManager (Android) so the OS can batch wake-ups across apps
   and honor Doze/Low-Power mode.
6. **Background work is idempotent.** The OS retries at-least-once; key by id and upsert so
   a double-run causes no duplicate side effects.
7. **Connectivity-aware retry.** Exponential backoff **+ jitter**, capped attempts, paused
   while offline (NetworkCallback / NetInfo / `connectivity_plus`), resumed on reconnect.
8. **Cancel in-flight work on nav-away.** Task cancellation, coroutine scope cancel,
   `AbortController`, `dispose()`. No callback should ever fire into a freed screen.
9. **Break retain cycles.** `[weak self]` in escaping closures, unregister observers,
   cancel subscriptions in `deinit`/`onDestroy`/`dispose`/`useEffect` cleanup.
10. **Recycle list rows.** UITableView/UICollectionView reuse, RecyclerView, `ListView.builder`,
    FlatList windowing. Never render an unbounded list into a scroll container.
11. **Follow the platform.** iOS HIG and Android Material: native navigation, back behavior,
    safe areas, dynamic type / font scaling, dark mode. Don't reinvent OS affordances.
12. **Degrade gracefully.** Show cached data with a "stale/offline" indicator, disable
    write actions that require the network, and never trap the user behind an infinite
    spinner with no timeout.

## Anti-patterns (DON'T) → fix
| ❌ Anti-pattern | Why it hurts | ✅ Do instead |
|---|---|---|
| Fetch on screen load, render straight from the response | Blank/broken screen offline; crash on throw | Read local store first, refresh into it in the background |
| `Timer`/`setInterval` polling every N seconds | Wakes radio + CPU, drains battery, ignores Doze | Push, or WorkManager/BGTaskScheduler, coalesced |
| Decode/DB/image-resize on the main thread | Dropped frames; watchdog (iOS) / ANR (Android) kill | Background dispatch/coroutine/isolate; main only for UI |
| Naive `while` retry loop on failure | Tight spin: battery + hammers your API | Backoff + jitter + connectivity gate, capped |
| Strong `self`/Context capture in closure/observer | Leaked VC/Activity, growing memory | `[weak self]`, unregister, cancel on teardown |
| No cancellation on back navigation | Work finishes into a freed view → crash/waste | Cancellation token / scope cancel / `AbortController` |
| Whole list in a `ScrollView`/`Column` | OOM, long frames on large data | Recycling list (RecyclerView/builder/FlatList) |
| Custom back button / non-native gestures | Breaks HIG/Material, confuses users, rejections | Native navigation + platform gestures |

## Worked examples ❌ → ✅
**Example 1 — main thread block (Swift / iOS)** `[MAIN_THREAD_BLOCK]`
```swift
// ❌ sync I/O + decode + Core Data write on the main thread → UI hangs, watchdog kill
func load() {
    let data  = try! Data(contentsOf: url)                       // blocking I/O on main
    let items = try! JSONDecoder().decode([Item].self, from: data)
    items.forEach { viewContext.insert($0) }                     // main-thread context
    tableView.reloadData()
}

// ✅ everything heavy off-main; hop to main only to touch the view
func load() {
    Task.detached(priority: .userInitiated) { [weak self] in     // no retain cycle
        guard let self else { return }
        let (data, _) = try await URLSession.shared.data(from: self.url)
        let items = try JSONDecoder().decode([Item].self, from: data)
        try await self.store.upsert(items)                       // background context
        await MainActor.run { self.tableView.reloadData() }      // UI on main
    }
}
```

**Example 2 — offline-first read + optimistic write (Dart / Flutter)** `[OFFLINE_GAP]`
```dart
// ❌ network is the source of truth → throws offline, screen is empty
Future<List<Note>> notes() async {
  final res = await dio.get('/notes');                 // no network → exception
  return (res.data as List).map(Note.fromJson).toList();
}

// ✅ local DB is the source of truth; network only hydrates it
Stream<List<Note>> watchNotes() => db.watchNotes();    // UI binds to local, works offline

Future<void> sync() async {
  try {
    final res = await dio.get('/notes');
    await db.upsertAll(res.data.map(Note.fromJson));    // conflict rule: newest updatedAt wins
  } on DioException {
    /* stay on cached rows, flag them stale — do NOT clear the UI */
  }
}

Future<void> addNote(Note n) async {
  await db.upsert(n.copyWith(pending: true));           // optimistic: shows instantly
  await outbox.enqueue(n);                              // flushed on reconnect by WorkManager
}
```

**Example 3 — battery drain + idempotent background sync (Kotlin / Android)** `[BATTERY_DRAIN]`
```kotlin
// ❌ foreground poll loop: keeps radio/CPU awake, ignores Doze, drains battery
lifecycleScope.launch {
    while (true) { syncNow(); delay(30_000) }           // never do this on mobile
}

// ✅ OS-scheduled, batched, constrained, retried with backoff, idempotent
val work = PeriodicWorkRequestBuilder<SyncWorker>(15, TimeUnit.MINUTES)   // 15m = WM minimum
    .setConstraints(
        Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
    .setBackoffCriteria(BackoffPolicy.EXPONENTIAL, 30, TimeUnit.SECONDS)
    .build()
WorkManager.getInstance(ctx)
    .enqueueUniquePeriodicWork("sync", ExistingPeriodicWorkPolicy.KEEP, work)

class SyncWorker(c: Context, p: WorkerParameters) : CoroutineWorker(c, p) {
    override suspend fun doWork(): Result = withContext(Dispatchers.IO) {
        try {
            repo.pushOutbox()                            // upsert by id = safe on re-run
            repo.pullAndUpsert()
            Result.success()
        } catch (e: IOException) {
            Result.retry()                               // OS re-runs with backoff
        }
    }
}
```

## Review checklist (PR-ready)
- [ ] App renders real data in airplane mode from the local store — no blank screen, no crash.
- [ ] No network I/O, decode, DB access, or image resize on the main/UI thread.
- [ ] Writes are optimistic with a **stated** conflict rule and queued for retry when offline.
- [ ] Periodic/background sync goes through BGTaskScheduler / WorkManager, not timers/polling.
- [ ] Background work is idempotent (keyed upserts); safe to run twice.
- [ ] Retries use exponential backoff **+ jitter**, capped, and pause while offline.
- [ ] In-flight work is cancelled on nav-away/`dispose`; no callback fires into a dead view.
- [ ] No retain cycles: `[weak self]`, observers unregistered, subscriptions cancelled.
- [ ] Long lists recycle rows; images are cached, downsampled, and memory-bounded.
- [ ] UI follows iOS HIG / Android Material (native nav, safe areas, dark mode, font scaling).

## Definition of Done
Feature works in airplane mode from cached state; syncs and resolves conflicts on reconnect;
does zero blocking work on the main thread; offloads periodic sync to the OS scheduler as
idempotent, backoff-retried jobs; cancels on nav-away; and leaks no controllers/observers
(verified with Instruments / LeakCanary / Flutter DevTools). Battery and jank profiled on a
real mid-tier device, not just the simulator. Matches platform HIG/Material.

## Stack-specific gotchas
- **iOS:** the BGTaskScheduler budget is opaque and OS-decided — treat runs as best-effort,
  register task IDs in `Info.plist`, and always call the expiration/completion handler.
  `beginBackgroundTask` grants only a short grace window, not indefinite time — don't rely on
  a specific duration.
- **Android:** Doze / App Standby defer background work and network; WorkManager honors them,
  raw threads and `AlarmManager` fight them. Foreground services need a user-visible,
  policy-compliant reason or the OS terminates them.
- **Flutter:** network/JSON parsing runs on the UI isolate by default — push heavy parsing to
  `compute()` / a spawned `Isolate`. Isolates don't share memory; only send serializable data.
  Platform-channel calls are async — never block the UI awaiting them.
- **React Native:** JS is single-threaded — heavy JSON/loops freeze the bridge and UI. Offload
  to native modules or chunk async work. Clean up subscriptions in the `useEffect` return and
  cancel requests with `AbortController`; use `AppState` for background transitions.
- **Cross-platform plugins** (RN native modules, Flutter plugins) do **not** guarantee identical
  background/offline behavior on both OSes — verify on each. Don't assert a plugin does X in the
  background without checking the source or docs; state the uncertainty instead of inventing it.

## Evidence tags
- `[BATTERY_DRAIN]` — polling, wakelocks, un-batched radio use, or ignored Doze/background limits.
- `[MEMORY_LEAK]` — retain cycle, unreleased observer/subscription, or unbounded cache/list.
- `[MAIN_THREAD_BLOCK]` — I/O, decode, DB, or heavy compute on the main/UI thread.
- `[OFFLINE_GAP]` — network treated as the source of truth; no local cache or degradation path.
