# Process Separation — Decision Framework

When to split work into a separate process (XPC service / helper agent) versus
keeping it in-process as an actor/queue. Read this *before* recommending XPC —
it is frequently proposed for the wrong reason.

## The resource myth (read first)

**Splitting into processes does NOT reduce resource use. It increases total
memory.** Each process loads its own copy of the Swift runtime, Foundation, and
any frameworks it links (Network.framework, etc.) — typically tens of MB per
process. The CPU work is unchanged; you've just moved it. If a user asks to
split services "to use fewer resources," correct the premise.

Threads/actors ≠ processes. Async/await on a background QoS already keeps work
off the main thread. If the UI isn't blocked, in-process concurrency has already
solved the responsiveness problem at the lowest memory cost.

### What process separation actually buys

| Benefit | Real? | Notes |
|---|---|---|
| Crash isolation | ✅ | A crash in the helper doesn't kill the main app. The #1 legit reason. |
| Sandbox hardening | ✅ | Each helper gets a single-purpose entitlement set instead of one process holding everything. Shrinks attack surface. |
| Idle memory reclamation | ⚠️ | Only for **bursty** work. launchd SIGKILLs an idle XPC service and frees 100% of its RAM — but an always-on connection never goes idle. |
| Lower resource use | ❌ | False. More processes = more memory. |
| Privilege separation | ✅ | Run a riskier operation under a different/tighter profile. |

## What actually lowers resource use (in-process)

- Lazy-start services behind feature flags; fully tear down connections when a
  feature is toggled off (don't just pause).
- Throttle/coalesce timers; prefer event-driven (notifications, sockets) over
  polling. Reduce poll frequency on battery (`ProcessInfo.thermalState`, power
  source).
- Let App Nap apply when idle — don't hold `ProcessInfo.beginActivity` or sleep
  assertions unless actively doing user-visible work.
- Bound caches (artwork/image) with eviction.

## Mechanism selection

| Need | Mechanism | Module |
|---|---|---|
| Isolate crash-prone parsing of untrusted/external data | XPC service | extensions.md |
| Bursty, request/response work that can be reclaimed when idle | XPC service | extensions.md |
| Quarantine a powerful entitlement to a small helper | XPC service | extensions.md |
| Run at login / outlive the app | SMAppService agent or daemon | background.md |
| Deferrable periodic work | BGTaskScheduler / NSBackgroundActivityScheduler | background.md |
| Responsiveness only (UI not blocked) | In-process actor + background QoS | coding-best-practices/modern-concurrency.md |

## XPC lifecycle gotcha: long-lived connections

XPC services are **ephemeral**. launchd launches one on the first
`NSXPCConnection` message and **SIGKILLs it when idle or under memory pressure**.
The app's connection stays valid and transparently relaunches the service on
next use. Apple's rule: **design the service to hold minimal/zero persistent
state** because it can die at any moment.

Consequence: a service whose whole job is to keep an **always-on connection**
alive (a chat WebSocket, an IPC socket, a listening server) fights this model.
To keep the connection up you keep the service busy, which **defeats idle
reclamation** — so for always-on work the only real wins are crash isolation and
sandbox hardening, not memory.

Always wire both recovery hooks:

```swift
connection.interruptionHandler = { /* service crashed or was killed — re-push state, reconnect */ }
connection.invalidationHandler = { /* connection torn down for good — stop using this proxy */ }
```

State that must survive a service restart either lives on the app side and is
re-pushed on `interruptionHandler`, or is persisted. Never assume in-memory
service state survives.

## Notarization cost (direct / Developer ID distribution)

Each nested `.xpc` is signed code and must be handled in the build:

- Sign **inside-out**: sign nested bundles (`.xpc`, frameworks) **first**, then
  the app. The notary issues a ticket per nested bundle.
- Enable **hardened runtime** on every nested bundle (`codesign -o runtime`).
- **Never `--deep --force`** the app — it invalidates the nested signatures and
  the app crashes after notarization even if notarization "succeeds."
- Each `.xpc` needs its own Info.plist + entitlements file.

## Cost checklist before recommending a split

1. Convert callback/`AsyncStream` wiring to an `@objc` XPC protocol with reply
   blocks; all crossing types become `NSSecureCoding`/Sendable.
2. New Info.plist + entitlements per service.
3. Inside-out signing in the release pipeline.
4. Accept higher total memory.

Only split when crash isolation or sandbox hardening clears that cost. If the
motivation is "use fewer resources," it does not — tune in-process instead.
