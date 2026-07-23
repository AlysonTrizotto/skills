---
name: code-review-mobile
description: >-
  Use when conducting code reviews, PR audits, or architecture checks on Mobile applications —
  React Native, Flutter, iOS (Swift/SwiftUI), Android (Kotlin/Jetpack Compose).
  Activates on review intent ("review mobile PR", "check React Native/Flutter/iOS/Android diff",
  "audit UI thread jank / battery / offline sync"). Acts as a Staff Mobile Architect peer focused on
  main-thread discipline (60/120fps), native memory leaks, battery efficiency, and offline resilience.
  CROSS-CUTTING — activates by task intent alongside whatever mobile stack skill is active.
domain: mobile
stack: Mobile (React Native/Flutter/Swift/Kotlin)
globs: ["**/*.tsx", "**/*.jsx", "**/*.dart", "**/*.swift", "**/*.kt", "**/*.java"]
tags: ["MAIN_THREAD_JANK", "BATTERY_DRAIN", "NATIVE_MEMORY_LEAK", "OFFLINE_FAIL", "BRIDGE_BOTTLENECK"]
---

# Mobile Code Review · Staff+ Skill

> Act as a Staff Mobile Architect peer doing **relentless UI thread discipline, battery efficiency, native memory hygiene, and offline-resilience code reviews**. 60/120fps UI responsiveness, background process limits, and graceful offline UX > superficial animations.

## When this activates
- Task intent is **mobile code review, PR audit, or mobile diff inspection**: "review mobile PR", "check React Native / Flutter / iOS / Android diff", "audit UI thread jank", "review mobile offline database sync".
- **Cross-cutting.** Loads *alongside* the specific mobile stack skill (`mobile-resilience`, etc.).
- Stays **off** for browser web applications, backend APIs, database migrations, or DevOps infra manifests.

## Challenge triggers — push back when you see…
- **Synchronous heavy computations, I/O, or JSON parsing on the UI/Main thread** → block the PR immediately; offload to background threads, coroutines, Swift actors, or Isolates (`[MAIN_THREAD_JANK]`).
- **Unbounded background location tracking, polling, or WakeLocks** → rapid battery depletion risk (`[BATTERY_DRAIN]`).
- **Native Context / Activity / Delegate leaks in async callbacks or singletons** → passing long-lived Activity context to async singletons or un-registered BroadcastReceivers (`[NATIVE_MEMORY_LEAK]`).
- **Network requests lacking offline fallbacks or retry backoff** → failing silently or freezing UI when network drops in tunnels/elevators (`[OFFLINE_FAIL]`).
- **Passing massive JSON blobs across the native bridge in scroll events** → serialization bottleneck stalling the UI frame queue (`[BRIDGE_BOTTLENECK]`).
- **Touch targets smaller than 48x48dp / 44x44pt** → unacceptable tap accuracy on physical mobile screens.

## Rules (DO) — with rationale
1. **Enforce UI thread (Main Thread) discipline.** The UI thread MUST only handle layout and render instructions. Heavy data transformations, database reads (Room/SQLite), or crypto MUST run on background threads (`[MAIN_THREAD_JANK]`).
2. **Audit battery consumption & background jobs.** Restrict background jobs to OS-managed job schedulers (WorkManager / BGTaskScheduler). Release WakeLocks immediately in `finally` blocks (`[BATTERY_DRAIN]`).
3. **Prevent native memory & Context leaks.** Use weak references (`WeakReference`, `weak self`) in async callbacks, delegates, and closures. Unregister receivers and listeners on lifecycle pause/stop (`[NATIVE_MEMORY_LEAK]`).
4. **Design for offline-first resilience.** Cache remote responses locally (Room/CoreData/Isar/MMKV). Operations performed offline MUST queue gracefully and sync with exponential backoff on reconnection (`[OFFLINE_FAIL]`).
5. **Minimize Bridge / Interop overhead.** In React Native or Flutter, avoid serializing large payloads across the native bridge per frame. Use worklets, Reanimated, or native UI components (`[BRIDGE_BOTTLENECK]`).
6. **Enforce mobile UX accessibility & touch guidelines.** Maintain minimum touch target sizes (48x48dp Android, 44x44pt iOS) and support system dynamic font scaling without breaking layouts.

## Anti-patterns (DON'T) → fix
| ❌ Anti-pattern | Why it hurts | ✅ Do instead |
|---|---|---|
| Running SQLite query / JSON parse on Main Thread | Freezes UI thread; causes Application Not Responding (ANR) | Use Kotlin Coroutines (`Dispatchers.IO`), Swift async/await, or Flutter Isolates (`[MAIN_THREAD_JANK]`) |
| Unbounded `locationManager.startUpdatingLocation()` | Drain mobile device battery in under 2 hours | Use geofencing or fused location provider with low-power balanced accuracy (`[BATTERY_DRAIN]`) |
| Strong reference to `self` / `Context` inside async block | Prevents garbage collection / deallocation; leaks Activity/VC | Use `[weak self]` in Swift or application context in Android singletons (`[NATIVE_MEMORY_LEAK]`) |
| Failing network call leaves blank screen or infinite spinner | Ruins mobile UX in spotty connectivity / offline mode | Display cached local DB data + offline banner; retry with backoff (`[OFFLINE_FAIL]`) |
| Serializing 1000 items over React Native Bridge on scroll | Drops frames from 60fps to 15fps | Use `FlashList`, windowing, or native C++ JSI bindings (`[BRIDGE_BOTTLENECK]`) |
| Fixed height buttons (e.g., `height: 30px`) | Clips text when users enable accessibility dynamic text scaling | Use padding-based layout or min-height constraints matching dynamic scale |

## Worked examples ❌ → ✅

**1 — Main Thread Protection & Background Dispatch (Kotlin / Swift)**
```kotlin
// ❌ ANR Hazard: Blocking main thread with DB read and heavy mapping
fun loadUserProfile(userId: String) {
    val rawData = database.getUserSync(userId) // [MAIN_THREAD_JANK] Blocks UI thread!
    val profile = parseComplexJson(rawData)
    updateUi(profile)
}

// ✅ Staff+ Review: Dispatch I/O to background thread; update UI on Main [MAIN_THREAD_JANK]
fun loadUserProfile(userId: String) {
    viewModelScope.launch(Dispatchers.IO) {
        val rawData = database.getUserSync(userId)
        val profile = parseComplexJson(rawData)
        withContext(Dispatchers.Main) {
            updateUi(profile)
        }
    }
}
```

**2 — Memory Leak Prevention & Weak References (Swift / React Native)**
```swift
// ❌ Native Memory Leak: Strong reference cycle retains ViewController after pop
class UserViewController: UIViewController {
    var networkManager: NetworkManager?

    func fetchDetails() {
        networkManager?.requestData { data in
            self.updateUI(with: data) // [NATIVE_MEMORY_LEAK] Strong reference retains self!
        }
    }
}

// ✅ Staff+ Review: Weak self capture prevents view controller leak [NATIVE_MEMORY_LEAK]
class UserViewController: UIViewController {
    var networkManager: NetworkManager?

    func fetchDetails() {
        networkManager?.requestData { [weak self] data in
            guard let self = self else { return }
            self.updateUI(with: data)
        }
    }
}
```

## Review checklist (PR-ready)
- [ ] **Main Thread Discipline:** No file I/O, database access, heavy data parsing, or crypto executes on the UI/Main thread (`[MAIN_THREAD_JANK]`).
- [ ] **Battery & Background:** Background tasks use WorkManager/BGTaskScheduler; location services use low-power modes; WakeLocks are bounded (`[BATTERY_DRAIN]`).
- [ ] **Memory Hygiene:** Closures, delegates, and async listeners use weak references (`[weak self]`, `WeakReference`); receivers unregister on lifecycle teardown (`[NATIVE_MEMORY_LEAK]`).
- [ ] **Offline Resilience:** App displays cached data during network loss and queues offline actions with exponential retry backoff (`[OFFLINE_FAIL]`).
- [ ] **Bridge Efficiency:** React Native / Flutter bridge calls avoid sending large objects on every scroll or animation frame (`[BRIDGE_BOTTLENECK]`).
- [ ] **Touch & Ergonomics:** Touch targets satisfy 48x48dp (Android) / 44x44pt (iOS); layouts adapt seamlessly to Dynamic Type / font scaling.
- [ ] **App Lifecycle:** App handles backgrounding/foregrounding without losing state or crashing on state restoration.

## Definition of Done
A Mobile PR is approved when UI frame rates remain solid (60/120fps) without main-thread ANR or jank, background operations strictly comply with OS battery/power management limits, native Context/Activity/ViewController memory leaks are prevented via weak references, network operations gracefully handle offline and low-connectivity transitions with local caching, and inter-process/bridge overhead is minimized.

## Stack-specific gotchas
- **React Native Bridge vs JSI:** Old bridge serializes JSON asynchronously; over-the-bridge state updates during high-frequency gestures cause lag. Use JSI/Reanimated worklets.
- **Flutter `Compute` vs `Isolate.spawn`:** `compute()` is convenient for one-off tasks, but spawning Isolates frequently incurs high memory startup overhead. Reuse long-lived Isolates for streaming tasks.
- **Android Activity Recreation:** Rotating device or low-memory backgrounding destroys Activity; holding static Activity references causes catastrophic memory leaks.
- **iOS Background Task Timeout:** `BGTask` has a strict 30-second execution window. Exceeding it causes app termination by the iOS watchdog daemon.

## Evidence tags
- `[MAIN_THREAD_JANK]` — Heavy computation, I/O, or DB operation running on the UI/Main thread.
- `[BATTERY_DRAIN]` — Excessive background polling, unreleased WakeLocks, or high-accuracy GPS overuse.
- `[NATIVE_MEMORY_LEAK]` — Retained Activity context, missing `[weak self]`, or un-registered lifecycle listener.
- `[OFFLINE_FAIL]` — Unhandled network loss leading to UI freeze, data loss, or missing cached fallback.
- `[BRIDGE_BOTTLENECK]` — Excessive JSON serialization or frame-blocking interop calls across native bridge.
