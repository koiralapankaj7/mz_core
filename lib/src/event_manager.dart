// Relative imports used intentionally for package-internal references.
// ignore_for_file: always_use_package_imports
// ignore_for_file: lines_longer_than_80_chars

/// {@template mz_core.event_manager_library}
/// A high-performance, feature-rich event queue system for Flutter applications.
///
/// ## Why EventManager?
///
/// Traditional state management solutions handle UI state well, but fall short when applications need:
///
/// - **Ordered execution** of async operations (API calls, database writes)
/// - **Cancellable operations** with token-based group cancellation
/// - **Undo/Redo support** for user actions
/// - **Automatic retry** with configurable backoff strategies
/// - **Timeout handling** for long-running operations
/// - **Progress reporting** for UI feedback during execution
/// - **Priority-based processing** for urgent events
/// - **AI-compatible architecture** where agents emit structured intents
/// - **Audit trails** with full event lifecycle logging
///
/// EventManager combines what typically requires 5-6 separate packages into a unified, performant solution.
///
/// ## Key Features
///
/// | Feature              | Description                                        |
/// |----------------------|----------------------------------------------------|
/// | **Priority Queue**   | Higher priority events processed first             |
/// | **Timeout Support**  | Automatic cancellation of long-running events      |
/// | **Auto Retry**       | Exponential/linear/constant backoff on failure     |
/// | **Progress**         | Real-time progress updates during execution        |
/// | **Token Cancel**     | Cancel groups of related events                    |
/// | **Batch Processing** | Process multiple events with [BatchEvent]          |
/// | **Undo/Redo**        | Full undo/redo with event merging support          |
/// | **Backpressure**     | Configurable queue limits and overflow policies    |
/// | **Performance**      | Time-based batching for UI responsiveness          |
/// | **Logging**          | Integrated [EventLogger] with colored output       |
/// | **Execution Modes**  | Sequential, concurrent, or rate-limited processing |
///
/// ## System Architecture
///
/// ```text
/// ┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
/// │                                              EventManager<T>                                                   │
/// │                                                                                                                │
/// │  ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────┐  │
/// │  │                                           EVENT QUEUE                                                    │  │
/// │  │                                                                                                          │  │
/// │  │    ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐                                   │  │
/// │  │    │ Event   │   │ Event   │   │ Event   │   │ Event   │   │ Event   │      ← Priority Sorted (High→Low) │  │
/// │  │    │ P: 100  │   │ P: 50   │   │ P: 10   │   │ P: 1    │   │ P: 0    │                                   │  │
/// │  │    └─────────┘   └─────────┘   └─────────┘   └─────────┘   └─────────┘                                   │  │
/// │  │         ↑                                                                                                │  │
/// │  │         │  Backpressure Control: maxQueueSize + OverflowPolicy (dropNewest/dropOldest/error)             │  │
/// │  └─────────┼────────────────────────────────────────────────────────────────────────────────────────────────┘  │
/// │            │                                                                                                   │
/// │   ┌────────┴────────┐                                                                                          │
/// │   │ addEventToQueue │                                                                                          │
/// │   │    (event)      │                                                                                          │
/// │   └────────┬────────┘                                                                                          │
/// │            │                                                                                                   │
/// │            ▼                                                                                                   │
/// │  ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────┐  │
/// │  │                                        EVENT PROCESSOR                                                   │  │
/// │  │                                                                                                          │  │
/// │  │   ┌─────────────────────────────────────────────────────────────────────────────────────────────────┐    │  │
/// │  │   │  ExecutionMode: Sequential | Concurrent(maxConcurrency) | RateLimited(limit, window)            │    │  │
/// │  │   └─────────────────────────────────────────────────────────────────────────────────────────────────┘    │  │
/// │  │                                                                                                          │  │
/// │  │   ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐      ┌─────────────────┐         │  │
/// │  │   │  Check Token    │ ───► │  Execute with   │ ───► │    Report       │ ───► │ Handle Result   │         │  │
/// │  │   │  Pause/Cancel   │      │    Timeout      │      │   Progress      │      │ Success/Error   │         │  │
/// │  │   └────────┬────────┘      └─────────────────┘      └─────────────────┘      └────────┬────────┘         │  │
/// │  │            │                                                                          │                  │  │
/// │  │            │ Token Cancelled?                                              ┌──────────┴──────────┐       │  │
/// │  │            ▼                                                               │                     │       │  │
/// │  │   ┌─────────────────┐                                              Has RetryPolicy?         No Retry     │  │
/// │  │   │  EventCancel    │                                                      │                     │       │  │
/// │  │   │   (reason)      │                                                      ▼                     ▼       │  │
/// │  │   └─────────────────┘                                              ┌───────────────┐     ┌─────────────┐ │  │
/// │  │                                                                    │  EventRetry   │     │ Terminal    │ │  │
/// │  │                                                                    │  (attempt, N) │     │   State     │ │  │
/// │  │                                                                    │  (delay, Xms) │     └─────────────┘ │  │
/// │  │                                                                    └───────┬───────┘                     │  │
/// │  │                                                                            │                             │  │
/// │  │                                                                      Re-queue with delay                 │  │
/// │  │                                                                            │                             │  │
/// │  │                                                                            └─────────────► Event Queue   │  │
/// │  └──────────────────────────────────────────────────────────────────────────────────────────────────────────┘  │
/// │            │                                                                                                   │
/// │            ▼                                                                                                   │
/// │  ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────┐  │
/// │  │                                        TERMINAL STATES                                                   │  │
/// │  │                                                                                                          │  │
/// │  │      ┌─────────────────┐          ┌─────────────────┐          ┌─────────────────┐                       │  │
/// │  │      │  EventComplete  │          │   EventError    │          │  EventCancel    │                       │  │
/// │  │      │                 │          │                 │          │                 │                       │  │
/// │  │      │   data: T       │          │   error: E      │          │   reason: R     │                       │  │
/// │  │      └────────┬────────┘          └────────┬────────┘          └─────────────────┘                       │  │
/// │  │               │                            │                                                             │  │
/// │  │               ▼                            ▼                                                             │  │
/// │  │      ┌─────────────────┐          ┌─────────────────┐                                                    │  │
/// │  │      │ onDone Callback │          │ onError Callback│                                                    │  │
/// │  │      │  (event, data)  │          │    (error)      │                                                    │  │
/// │  │      └─────────────────┘          └─────────────────┘                                                    │  │
/// │  └──────────────────────────────────────────────────────────────────────────────────────────────────────────┘  │
/// │            │                                                                                                   │
/// │            ▼                                                                                                   │
/// │  ┌─────────────────────────────────────────────┐    ┌─────────────────────────────────────────────┐           │
/// │  │            UndoRedoManager                  │    │               EventLogger                   │           │
/// │  │                                             │    │                                             │           │
/// │  │   ┌─────────────┐     ┌─────────────┐       │    │   ┌───────────────────────────────────┐     │           │
/// │  │   │ Undo Stack  │     │ Redo Stack  │       │    │   │  • Lifecycle state tracking       │     │           │
/// │  │   │             │     │             │       │    │   │  • Colored console output         │     │           │
/// │  │   │ [History]   │     │ [History]   │       │    │   │  • Bounded history (circular)     │     │           │
/// │  │   │ [Entry  ]   │     │ [Entry  ]   │       │    │   │  • Custom output handlers         │     │           │
/// │  │   │ [...]    ]  │     │ [...]    ]  │       │    │   └───────────────────────────────────┘     │           │
/// │  │   └─────────────┘     └─────────────┘       │    │                                             │           │
/// │  │                                             │    │   maxHistorySize: prevents memory leaks     │           │
/// │  │   • Event merging for consecutive actions   │    │                                             │           │
/// │  │   • maxHistorySize circular buffer          │    │                                             │           │
/// │  └─────────────────────────────────────────────┘    └─────────────────────────────────────────────┘           │
/// └────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Event Lifecycle States
///
/// ```text
///                                         ┌─────────────────────┐
///                                         │      CREATED        │
///                                         │    (state: null)    │
///                                         └──────────┬──────────┘
///                                                    │
///                                         addEventToQueue(event)
///                                                    │
///                                                    ▼
///                                         ┌─────────────────────┐
///                                         │     EventQueue      │
///                                         │                     │
///                                         │  Waiting in queue   │
///                                         │  (priority sorted)  │
///                                         └──────────┬──────────┘
///                                                    │
///                       ┌────────────────────────────┼────────────────────────────┐
///                       │                            │                            │
///                       ▼                            ▼                            ▼
///              ┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
///              │   EventPause    │         │  EventCancel    │         │   EventStart    │
///              │                 │         │                 │         │                 │
///              │  Token paused   │         │ Token cancelled │         │    Executing    │
///              │  (skip event)   │         │    (reason)     │         │   buildAction   │
///              └─────────────────┘         └─────────────────┘         └─────────┬───────┘
///                                                                                │
///                       ┌───────────────────────────┬────────────────────────────┤
///                       │                           │                            │
///                       ▼                           ▼                            ▼
///              ┌─────────────────┐         ┌─────────────────┐         ┌─────────────────┐
///              │  EventCancel    │         │  EventProgress  │         │  EventComplete  │
///              │                 │         │                 │         │   or            │
///              │    (timeout)    │         │  value: 0.0-1.0 │         │  EventError     │
///              │                 │         │  message: "..." │         │                 │
///              └─────────────────┘         └─────────────────┘         └────────┬────────┘
///                                                                               │
///                                                               ┌───────────────┴───────────────┐
///                                                               │                               │
///                                                               ▼                               ▼
///                                                      ┌─────────────────┐             ┌─────────────────┐
///                                                      │   EventRetry    │             │    TERMINAL     │
///                                                      │                 │             │                 │
///                                                      │  attempt: N     │             │  EventComplete  │
///                                                      │  delay: Xms     │             │  EventError     │
///                                                      └────────┬────────┘             │  EventCancel    │
///                                                               │                      └─────────────────┘
///                                                               │
///                                                          Re-queue
///                                                               │
///                                                               └──────────────────► EventQueue
/// ```
///
/// ## Event Types Hierarchy
///
/// ```text
///                                              ┌───────────────────┐
///                                              │      Intent       │  (from Flutter)
///                                              └─────────┬─────────┘
///                                                        │
///                                              ┌─────────┴─────────┐
///                                              │     BaseEvent     │
///                                              │                   │
///                                              │  • token          │
///                                              │  • priority       │
///                                              │  • timeout        │
///                                              │  • retryPolicy    │
///                                              │  • buildAction()  │
///                                              │  • reportProgress │
///                                              └─────────┬─────────┘
///                                                        │
///                ┌───────────────────────────────────────┼───────────────────────────────────────┐
///                │                                       │                                       │
///                ▼                                       ▼                                       ▼
///      ┌───────────────────┐               ┌───────────────────┐               ┌───────────────────┐
///      │   UndoableEvent   │               │    BatchEvent     │               │   YourCustomEvent │
///      │                   │               │                   │               │                   │
///      │  • captureState() │               │  • events[]       │               │   Extend BaseEvent│
///      │  • undo()         │               │  • eagerError     │               │   to create your  │
///      │  • redo()         │               │                   │               │   own events      │
///      │  • canMergeWith() │               │  Process multiple │               │                   │
///      │  • mergeWith()    │               │  events as batch  │               │                   │
///      │  • undoDescription│               │                   │               │                   │
///      └───────────────────┘               └───────────────────┘               └───────────────────┘
/// ```
///
/// ## Token-Based Cancellation
///
/// ```text
///      ┌───────────────────────────────────────────────────────────────────────────────────────────┐
///      │                                      EventToken                                           │
///      │                                                                                           │
///      │   Token groups multiple events for collective control:                                    │
///      │                                                                                           │
///      │      token.pause()   ──►  All events with this token are skipped                          │
///      │      token.resume()  ──►  Processing resumes for paused events                            │
///      │      token.cancel()  ──►  All events with this token are cancelled                        │
///      │                                                                                           │
///      │   ┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐                     │
///      │   │    Event A      │     │    Event B      │     │    Event C      │                     │
///      │   │                 │     │                 │     │                 │                     │
///      │   │  token: myToken │     │  token: myToken │     │  token: myToken │                     │
///      │   └────────┬────────┘     └────────┬────────┘     └────────┬────────┘                     │
///      │            │                       │                       │                              │
///      │            └───────────────────────┼───────────────────────┘                              │
///      │                                    │                                                      │
///      │                                    ▼                                                      │
///      │                          ┌─────────────────────┐                                          │
///      │                          │     EventToken      │                                          │
///      │                          │                     │                                          │
///      │                          │  • isPaused         │                                          │
///      │                          │  • isCancelled      │                                          │
///      │                          │  • whenCancel       │ ◄── Future that completes on cancel      │
///      │                          │  • cancelData       │                                          │
///      │                          └─────────────────────┘                                          │
///      └───────────────────────────────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Retry Flow with Backoff
///
/// ```text
///      Event Execution Fails
///               │
///               ▼
///      ┌─────────────────────────────────────────────────┐
///      │              Check RetryPolicy                  │
///      │                                                 │
///      │   retryPolicy = RetryPolicy(                    │
///      │     maxAttempts: 3,                             │
///      │     backoff: RetryBackoff.exponential(          │
///      │       initial: Duration(seconds: 1),            │
///      │       maxDelay: Duration(seconds: 30),          │
///      │     ),                                          │
///      │   )                                             │
///      └────────────────────┬────────────────────────────┘
///                           │
///            ┌──────────────┴──────────────┐
///            │                             │
///            ▼                             ▼
///     attempt < maxAttempts?        attempt >= maxAttempts?
///            │                             │
///            ▼                             ▼
///   ┌─────────────────┐           ┌─────────────────┐
///   │   EventRetry    │           │   EventError    │
///   │                 │           │                 │
///   │  attempt: N     │           │  Final failure  │
///   │  delay: Xms     │           │  (no more retry)│
///   └────────┬────────┘           └─────────────────┘
///            │
///            │   Wait for delay...
///            │
///            │   ┌─────────────────────────────────────────────────────┐
///            │   │              Backoff Strategies                     │
///            │   │                                                     │
///            │   │   constant:    [1s]  [1s]  [1s]  [1s]  [1s]         │
///            │   │   linear:      [1s]  [2s]  [3s]  [4s]  [5s]         │
///            │   │   exponential: [1s]  [2s]  [4s]  [8s]  [16s]        │
///            │   └─────────────────────────────────────────────────────┘
///            │
///            ▼
///   Re-queue Event ────────────────────────────────────────────► Event Queue
/// ```
///
/// ## Backpressure Handling
///
/// ```text
///      Queue reaches maxQueueSize
///               │
///               ▼
///      ┌─────────────────────────────────────────────────────────────────────────────┐
///      │                            OverflowPolicy                                   │
///      │                                                                             │
///      │   ┌─────────────────┐                                                       │
///      │   │   dropNewest    │ ──►  New events are silently discarded                │
///      │   │                 │      Best for: analytics, logging, non-critical       │
///      │   └─────────────────┘                                                       │
///      │                                                                             │
///      │   ┌─────────────────┐                                                       │
///      │   │   dropOldest    │ ──►  Oldest events removed to make room for new       │
///      │   │                 │      Best for: real-time updates, latest data wins    │
///      │   └─────────────────┘                                                       │
///      │                                                                             │
///      │   ┌─────────────────┐                                                       │
///      │   │     error       │ ──►  QueueOverflowError thrown                        │
///      │   │                 │      Best for: critical events that must not be lost  │
///      │   └─────────────────┘                                                       │
///      └─────────────────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Execution Modes
///
/// ```text
///      ┌─────────────────────────────────────────────────────────────────────────────┐
///      │                            ExecutionMode                                    │
///      │                                                                             │
///      │   ┌─────────────────┐                                                       │
///      │   │   Sequential    │ ──►  Process one event at a time (default)            │
///      │   │                 │      Best for: ordered operations, state mutations    │
///      │   └─────────────────┘                                                       │
///      │                                                                             │
///      │   ┌─────────────────┐                                                       │
///      │   │   Concurrent    │ ──►  Process multiple events simultaneously           │
///      │   │ (maxConcurrency)│      Best for: independent API calls, I/O operations  │
///      │   └─────────────────┘                                                       │
///      │                                                                             │
///      │   ┌─────────────────┐                                                       │
///      │   │  RateLimited    │ ──►  Process up to N events per time window           │
///      │   │ (limit, window) │      Best for: API rate limits, throttling            │
///      │   └─────────────────┘                                                       │
///      └─────────────────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Undo/Redo System
///
/// ```text
///      ┌─────────────────────────────────────────────────────────────────────────────────────────┐
///      │                                  UndoRedoManager                                        │
///      │                                                                                         │
///      │   ┌─────────────────────────────┐         ┌─────────────────────────────┐               │
///      │   │        UNDO STACK           │         │        REDO STACK           │               │
///      │   │                             │         │                             │               │
///      │   │   ┌─────────────────────┐   │         │   ┌─────────────────────┐   │               │
///      │   │   │    HistoryEntry     │   │         │   │    HistoryEntry     │   │               │
///      │   │   │  • event            │   │         │   │  • event            │   │               │
///      │   │   │  • timestamp        │   │         │   │  • timestamp        │   │               │
///      │   │   └─────────────────────┘   │         │   └─────────────────────┘   │               │
///      │   │   ┌─────────────────────┐   │         │   ┌─────────────────────┐   │               │
///      │   │   │    HistoryEntry     │   │         │   │    HistoryEntry     │   │               |
///      │   │   └─────────────────────┘   │         │   └─────────────────────┘   │               │
///      │   │           ...               │         │           ...               │               │
///      │   └─────────────────────────────┘         └─────────────────────────────┘               │
///      │                                                                                         │
///      │   ┌─────────────────────────────────────────────────────────────────────────────────┐   │
///      │   │                              EVENT MERGING                                      │   │
///      │   │                                                                                 │   │
///      │   │   Consecutive similar events are merged to reduce history size:                 │   │
///      │   │                                                                                 │   │
///      │   │   TypeCharEvent('H') ─┐                                                         │   │
///      │   │   TypeCharEvent('e') ─┤                                                         │   │
///      │   │   TypeCharEvent('l') ─┼──────►  Merged: TypeCharEvent(characters: "Hello")      │   │
///      │   │   TypeCharEvent('l') ─┤                                                         │   │
///      │   │   TypeCharEvent('o') ─┘                                                         │   │
///      │   │                                                                                 │   │
///      │   │   One undo reverts all 5 characters instead of one at a time                    │   │
///      │   └─────────────────────────────────────────────────────────────────────────────────┘   │
///      │                                                                                         │
///      │   maxHistorySize: Circular buffer automatically removes oldest entries when full        │
///      └─────────────────────────────────────────────────────────────────────────────────────────┘
/// ```
///
/// ## Performance Characteristics
///
/// - Handles **10,000+ events/second** for sync operations
/// - **Priority queue** ensures urgent events processed first
/// - **Time-based batching** yields to UI thread every ~8ms (configurable)
/// - **Circular buffer** for event history prevents memory leaks
/// - **Zero allocations** in hot paths where possible
///
/// ## Quick Start
///
/// ```dart
/// // 1. Define your event
/// class FetchUserEvent extends BaseEvent<AppState> {
///   FetchUserEvent(this.userId);
///
///   final String userId;
///
///   @override
///   Duration? get timeout => const Duration(seconds: 30);
///
///   @override
///   int get priority => 10; // Higher = processed first
///
///   @override
///   RetryPolicy? get retryPolicy => RetryPolicy(
///     maxAttempts: 3,
///     backoff: RetryBackoff.exponential(initial: Duration(seconds: 1)),
///   );
///
///   @override
///   Future<User> buildAction(EventManager<AppState> manager) async {
///     reportProgress(0.0, message: 'Connecting...');
///     final user = await api.fetchUser(userId);
///     reportProgress(1.0, message: 'Done');
///     return user;
///   }
/// }
///
/// // 2. Create manager and dispatch
/// final manager = EventManager<AppState>(
///   maxQueueSize: 1000,
///   overflowPolicy: OverflowPolicy.dropOldest,
///   undoManager: UndoRedoManager(maxHistorySize: 50),
///   logger: EventLogger(maxHistorySize: 100),
/// );
///
/// manager.addEventToQueue(
///   FetchUserEvent('123'),
///   onDone: (event, user) => print('Got: $user'),
///   onError: (error) => print('Failed: $error'),
/// );
/// ```
///
/// ## Undo/Redo Support
///
/// ```dart
/// class UpdateNameEvent extends UndoableEvent<AppState> {
///   UpdateNameEvent(this.newName);
///
///   final String newName;
///   String? _previousName;
///
///   @override
///   void captureState(EventManager<AppState> manager) {
///     _previousName = manager.state.name;
///   }
///
///   @override
///   Future<void> buildAction(EventManager<AppState> manager) async {
///     manager.state.name = newName;
///   }
///
///   @override
///   Future<void> undo(EventManager<AppState> manager) async {
///     manager.state.name = _previousName!;
///   }
///
///   @override
///   String get undoDescription => 'Change name to "$newName"';
/// }
///
/// // Usage
/// manager.addEventToQueue(UpdateNameEvent('John'));
///
/// // Later...
/// await manager.undoManager?.undo(manager);   // Reverts to previous
/// await manager.undoManager?.redo(manager);   // Re-applies 'John'
/// await manager.undoManager?.undo(manager, count: 3); // Undo 3 actions
/// ```
///
/// ## Comparison with Other Solutions
///
/// ```text
/// ┌────────────────────┬──────────────┬──────┬───────────┬──────────┐
/// │      Feature       │ EventManager │ BLoC │ queue pkg │ undo pkg │
/// ├────────────────────┼──────────────┼──────┼───────────┼──────────┤
/// │ Priority Queue     │      ●       │  ○   │     ○     │    ○     │
/// │ Execution Modes    │      ●       │  ○   │     ○     │    ○     │
/// │ Timeout Support    │      ●       │  ○   │     ○     │    ○     │
/// │ Auto Retry         │      ●       │  ○   │     ○     │    ○     │
/// │ Progress Reporting │      ●       │  ○   │     ○     │    ○     │
/// │ Token Cancellation │      ●       │  ○   │     ○     │    ○     │
/// │ Undo/Redo          │      ●       │  ○   │     ○     │    ●     │
/// │ Batch Events       │      ●       │  ○   │     ○     │    ○     │
/// │ Backpressure       │      ●       │  ○   │     ●     │    ○     │
/// │ State Tracking     │      ●       │  ●   │     ○     │    ○     │
/// │ Logging            │      ●       │  ○   │     ○     │    ○     │
/// └────────────────────┴──────────────┴──────┴───────────┴──────────┘
///                       ● = Supported    ○ = Not Supported
/// ```
///
/// ## See Also
///
/// - [BaseEvent] - Base class for creating events
/// - [UndoableEvent] - Events that support undo/redo
/// - [BatchEvent] - Process multiple events as a unit
/// - [EventManager] - The main queue processor
/// - [UndoRedoManager] - Manages undo/redo history
/// - [EventToken] - Group cancellation tokens
/// - [EventLogger] - Event lifecycle logging
/// - [RetryPolicy] - Configure automatic retries
/// - [RetryBackoff] - Backoff strategies for retries
/// - [OverflowPolicy] - Backpressure handling options
/// - [EventState] - Event lifecycle states
/// - [ExecutionMode] - Execution strategies (Sequential, Concurrent, RateLimited)
/// {@endtemplate}
library;

import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Intent;

import 'controller.dart';
import 'logger.dart';

/// Callback function type for handling successful event completion.
///
/// [event] is the completed event instance.
/// [data] is the result data returned by the event's buildAction.
typedef OnDone<T, E extends BaseEvent<T>> = void Function(
  E event,
  Object? data,
);

/// Callback function type for handling event errors.
///
/// [error] contains the error details and optional retry functionality.
typedef OnError<T> = void Function(BaseError error);

/// Callback function type for retrying failed events.
typedef RetryCallback = FutureOr<Object?> Function();

/// Type representing a failed event and its error.
typedef PendingEvent<T, E extends BaseEvent<T>> = ({E event, BaseError? error});

/// Record type for token cancellation data.
typedef TokenCancellation = ({Object? reason, bool retriable});

/// Callback for event state changes.
///
/// Listeners receive the new [EventState] and can use pattern matching
/// to filter which states they care about.
typedef StateListener = void Function(EventState? state);

typedef _EventQueue<T> = Queue<_QueuedEvent<T, BaseEvent<T>>>;

// ======================= Overflow Policy ==========================

/// {@template mz_core.OverflowPolicy}
/// Policy for handling queue overflow when [EventManager.maxQueueSize] is
/// reached.
///
/// Used to prevent unbounded memory growth in high-throughput scenarios.
///
/// ## Choosing a Policy
///
/// {@tool snippet}
/// Configure overflow policy for your use case:
///
/// ```dart
/// // For analytics/logging - drop new events silently
/// final manager = EventManager<AppState>(
///   maxQueueSize: 1000,
///   overflowPolicy: OverflowPolicy.dropNewest,
/// );
///
/// // For real-time updates - keep latest data
/// final manager = EventManager<AppState>(
///   maxQueueSize: 100,
///   overflowPolicy: OverflowPolicy.dropOldest,
/// );
///
/// // For critical events - fail loudly
/// final manager = EventManager<AppState>(
///   maxQueueSize: 500,
///   overflowPolicy: OverflowPolicy.error,
/// );
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [EventManager.maxQueueSize] - Maximum queue size.
/// * [QueueOverflowError] - Error thrown with [OverflowPolicy.error].
/// {@endtemplate}
enum OverflowPolicy {
  /// Silently drop new events when queue is full.
  ///
  /// Best for: Fire-and-forget events like analytics, logging.
  dropNewest,

  /// Remove oldest events to make room for new ones.
  ///
  /// Best for: Real-time updates where latest data is most important.
  dropOldest,

  /// Throw [QueueOverflowError] when queue is full.
  ///
  /// Best for: Critical events that must not be silently dropped.
  error,
}

/// {@template mz_core.QueueOverflowError}
/// Error thrown when event queue exceeds [EventManager.maxQueueSize] and
/// [OverflowPolicy.error] is configured.
///
/// ## Handling Overflow
///
/// {@tool snippet}
/// Catch and handle overflow errors:
///
/// ```dart
/// try {
///   manager.addEventToQueue(myEvent);
/// } on QueueOverflowError catch (e) {
///   print('Queue full: ${e.queueSize}/${e.maxQueueSize}');
///   // Handle backpressure - maybe pause upstream
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [OverflowPolicy] - Policy options for handling overflow.
/// * [EventManager.maxQueueSize] - Configure maximum queue size.
/// {@endtemplate}
class QueueOverflowError extends Error {
  /// Creates a queue overflow error.
  QueueOverflowError({
    required this.queueSize,
    required this.maxQueueSize,
    this.event,
  });

  /// Current queue size when overflow occurred.
  final int queueSize;

  /// Maximum allowed queue size.
  final int maxQueueSize;

  /// The event that caused the overflow (if available).
  final BaseEvent<dynamic>? event;

  @override
  String toString() =>
      'QueueOverflowError: Queue size ($queueSize) exceeds max ($maxQueueSize)';
}

// ======================= Base Events ==========================

/// {@template mz_core.EventToken}
/// Token used to group and collectively control related events.
///
/// Events can be associated with a token by passing it to their constructor.
/// The token allows pausing, resuming, or cancelling all associated events
/// as a group.
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Associate multiple events with a token for group control:
///
/// ```dart
/// final token = EventToken();
///
/// // Associate events with the token
/// manager.addEventToQueue(FetchDataEvent(token: token));
/// manager.addEventToQueue(ProcessDataEvent(token: token));
/// manager.addEventToQueue(SaveDataEvent(token: token));
///
/// // Pause all events in this group
/// token.pause();
///
/// // Resume processing
/// token.resume();
///
/// // Cancel all events at once
/// token.cancel(reason: 'User navigated away');
/// ```
/// {@end-tool}
///
/// ## Cancellation Options
///
/// {@tool snippet}
/// Control whether cancelled events can be retried:
///
/// ```dart
/// // Cancel but allow retry (default behavior)
/// token.cancel(reason: 'Network timeout', retriable: true);
///
/// // Cancel permanently - event cannot be re-added
/// token.cancel(reason: 'Invalid session', retriable: false);
/// ```
/// {@end-tool}
///
/// ## Awaiting Cancellation
///
/// {@tool snippet}
/// Use [whenCancel] to await token cancellation:
///
/// ```dart
/// final token = EventToken();
///
/// // In async code
/// token.whenCancel.then((data) {
///   print('Token cancelled: ${data.reason}');
///   if (data.retriable) {
///     // Safe to retry operations
///   }
/// });
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [BaseEvent] - Events that can be associated with tokens.
/// * [EventManager] - Processes events and respects token states.
/// {@endtemplate}
class EventToken {
  bool _isPaused = false;
  TokenCancellation? _cancelData;
  Completer<TokenCancellation>? _cancelCompleter;

  /// The state change listener.
  ///
  /// Only one listener is supported. This is called by [EventManager] when
  /// tracking tokens via reference counting. The listener is notified when
  /// the token is paused, resumed, or cancelled.
  VoidCallback? listener;

  /// Pauses all events associated with this token.
  ///
  /// Paused events remain in the queue but are skipped during processing.
  /// Call [resume] to continue processing paused events.
  ///
  /// ## When to use `pause()` vs `cancel()`
  ///
  /// Use `pause()` when you want to **temporarily stop** processing and
  /// **resume later from where you left off**:
  /// - User switches tabs/screens temporarily
  /// - Waiting for a condition (network, user input)
  /// - Throttling during high load
  ///
  /// Use `cancel()` when you want to **stop permanently** or **start fresh**:
  /// - User explicitly cancels an operation
  /// - Operation is no longer relevant
  /// - Error requires starting over (with `retriable: true`)
  ///
  /// Has no effect if the token is already paused or cancelled.
  void pause() {
    if (_isPaused || isCancelled) return;
    _isPaused = true;
    listener?.call();
  }

  /// Resumes processing of events associated with this token.
  ///
  /// Events will continue processing from where they were paused.
  /// The [EventManager] automatically restarts queue processing when
  /// a token is resumed.
  ///
  /// Has no effect if the token is not paused.
  void resume() {
    if (!_isPaused) return;
    _isPaused = false;
    listener?.call();
  }

  /// Cancels all events associated with this token.
  ///
  /// Cancelled events are removed from the queue and will not be processed.
  ///
  /// ## Parameters
  ///
  /// - [reason]: Optional explanation for the cancellation.
  /// - [retriable]: Whether cancelled events can be re-added to the queue
  ///   (default: `true`).
  ///
  /// ## When to use `retriable`
  ///
  /// - `retriable: true` (default): The event can be re-added to the queue
  ///   later, starting fresh. Use when cancellation is temporary or
  ///   error-driven (e.g., network timeout, user can retry).
  ///
  /// - `retriable: false`: The event is permanently cancelled and cannot
  ///   be re-added. Use when the operation should never be attempted again
  ///   (e.g., invalid data, unauthorized action).
  ///
  /// ## Difference from `pause()`
  ///
  /// - `pause()` + `resume()`: Continues from paused state, event stays in
  ///   queue
  /// - `cancel(retriable: true)` + re-add: Starts fresh, event re-enters
  ///   queue
  ///
  /// Has no effect if the token is already cancelled.
  void cancel({Object? reason, bool retriable = true}) {
    if (isCancelled) return;
    _cancelData = (
      reason: reason ?? 'Cancelled by token',
      retriable: retriable,
    );
    _cancelCompleter?.complete(_cancelData);
    listener?.call();
  }

  /// Whether this token is paused.
  bool get isPaused => _isPaused && !isCancelled;

  /// Whether this token has been cancelled.
  bool get isCancelled => _cancelData != null;

  /// The cancellation data, or null if not cancelled.
  TokenCancellation? get cancelData => _cancelData;

  /// Future that completes when this token is cancelled.
  ///
  /// The completer is created lazily on first access.
  Future<TokenCancellation> get whenCancel {
    if (_cancelCompleter != null) return _cancelCompleter!.future;
    _cancelCompleter = Completer<TokenCancellation>();
    // If already cancelled, complete immediately
    if (_cancelData != null) {
      _cancelCompleter!.complete(_cancelData);
    }
    return _cancelCompleter!.future;
  }
}

// ======================= Retry Policy ==========================

/// {@template mz_core.RetryBackoff}
/// Strategy for calculating delay between retry attempts.
///
/// ## Backoff Strategies
///
/// {@tool snippet}
/// Three backoff strategies are available:
///
/// ```dart
/// // Constant - same delay every time
/// RetryBackoff.constant(Duration(seconds: 1))
///
/// // Exponential - delays double: 1s, 2s, 4s, 8s...
/// RetryBackoff.exponential(
///   initial: Duration(seconds: 1),
///   maxDelay: Duration(seconds: 30),
/// )
///
/// // Linear - delays increase by fixed amount: 1s, 2s, 3s, 4s...
/// RetryBackoff.linear(
///   initial: Duration(seconds: 1),
///   increment: Duration(seconds: 1),
/// )
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [RetryPolicy] - Combines backoff with retry limits.
/// * [BaseEvent.retryPolicy] - Configure retry for events.
/// {@endtemplate}
// ignore: one_member_abstracts
abstract class RetryBackoff {
  /// Creates a constant backoff with fixed delay between retries.
  const factory RetryBackoff.constant(Duration delay) = _ConstantBackoff;

  /// Creates an exponential backoff with increasing delays.
  ///
  /// Delay doubles after each attempt: initial, 2x, 4x, 8x...
  /// Capped at [maxDelay] if provided.
  const factory RetryBackoff.exponential({
    required Duration initial,
    Duration? maxDelay,
    double multiplier,
  }) = _ExponentialBackoff;

  /// Creates a linear backoff with linearly increasing delays.
  ///
  /// Delay increases by [increment] after each attempt.
  const factory RetryBackoff.linear({
    required Duration initial,
    required Duration increment,
    Duration? maxDelay,
  }) = _LinearBackoff;

  /// Calculates the delay before the given retry attempt.
  ///
  /// [attempt] is 0-based (0 = first retry, 1 = second retry, etc.)
  Duration delay(int attempt);
}

class _ConstantBackoff implements RetryBackoff {
  const _ConstantBackoff(this._delay);
  final Duration _delay;

  @override
  Duration delay(int attempt) => _delay;
}

class _ExponentialBackoff implements RetryBackoff {
  const _ExponentialBackoff({
    required this.initial,
    this.maxDelay,
    this.multiplier = 2.0,
  });

  final Duration initial;
  final Duration? maxDelay;
  final double multiplier;

  @override
  Duration delay(int attempt) {
    final ms = initial.inMicroseconds * math.pow(multiplier, attempt);
    final duration = Duration(microseconds: ms.toInt());
    if (maxDelay != null && duration > maxDelay!) return maxDelay!;
    return duration;
  }
}

class _LinearBackoff implements RetryBackoff {
  const _LinearBackoff({
    required this.initial,
    required this.increment,
    this.maxDelay,
  });

  final Duration initial;
  final Duration increment;
  final Duration? maxDelay;

  @override
  Duration delay(int attempt) {
    final duration = initial + (increment * attempt);
    if (maxDelay != null && duration > maxDelay!) return maxDelay!;
    return duration;
  }
}

/// {@template mz_core.RetryPolicy}
/// Policy for automatic event retries on failure.
///
/// Controls how many times an event should be retried and the delay
/// between attempts.
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Configure retry with exponential backoff:
///
/// ```dart
/// RetryPolicy(
///   maxAttempts: 3,
///   backoff: RetryBackoff.exponential(
///     initial: Duration(seconds: 1),
///     maxDelay: Duration(seconds: 30),
///   ),
/// )
/// ```
/// {@end-tool}
///
/// ## Conditional Retry
///
/// {@tool snippet}
/// Retry only specific errors:
///
/// ```dart
/// RetryPolicy(
///   maxAttempts: 3,
///   backoff: RetryBackoff.constant(Duration(seconds: 1)),
///   retryIf: (error) {
///     // Only retry network errors
///     return error is SocketException || error is TimeoutException;
///   },
/// )
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [RetryBackoff] - Strategies for calculating retry delays.
/// * [BaseEvent.retryPolicy] - Configure retry for events.
/// * [EventRetry] - State indicating retry is pending.
/// {@endtemplate}
class RetryPolicy {
  /// Creates a retry policy.
  ///
  /// [maxAttempts] is the maximum number of retry attempts (not including
  /// the initial attempt). Must be >= 1.
  ///
  /// [backoff] determines the delay between attempts.
  ///
  /// [retryIf] is an optional predicate to determine if a specific error
  /// should be retried. Defaults to retrying all errors.
  const RetryPolicy({
    required this.maxAttempts,
    required this.backoff,
    this.retryIf,
  }) : assert(maxAttempts >= 1, 'maxAttempts must be >= 1');

  /// Maximum number of retry attempts.
  final int maxAttempts;

  /// Strategy for calculating delay between attempts.
  final RetryBackoff backoff;

  /// Optional predicate to determine if an error should be retried.
  ///
  /// If null, all errors are retried. If provided, only errors where
  /// this returns true will trigger a retry.
  final bool Function(Object error)? retryIf;

  /// Whether the given error should be retried on the given attempt.
  bool shouldRetry(int attempt, Object error) {
    if (attempt >= maxAttempts) return false;
    if (retryIf != null && !retryIf!(error)) return false;
    return true;
  }

  /// Gets the delay before the given retry attempt.
  Duration getDelay(int attempt) => backoff.delay(attempt);
}

/// {@template mz_core.BaseEvent}
/// Abstract base class for creating custom events that can be processed by
/// [EventManager].
///
/// Events can be synchronous or asynchronous, cancellable, and support full
/// lifecycle state tracking.
///
/// ## Overview
///
/// Extend [BaseEvent] to create custom events. Override [buildAction] to
/// define the event's behavior.
///
/// ## Lifecycle States
///
/// Events go through these states:
/// 1. **Created** - `state = null`
/// 2. **Queued** - [EventQueue]
/// 3. **Started** - [EventStart]
/// 4. **Terminal** - [EventComplete], [EventError], or [EventCancel]
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Create a simple async event:
///
/// ```dart
/// class FetchUserEvent extends BaseEvent<AppState> {
///   FetchUserEvent(this.userId, {super.debugKey});
///
///   final String userId;
///
///   @override
///   Future<User> buildAction(EventManager<AppState> manager) async {
///     return await api.fetchUser(userId);
///   }
/// }
///
/// // Usage
/// manager.addEventToQueue(
///   FetchUserEvent('123', debugKey: 'fetch-user'),
///   onDone: (event, user) => print('Fetched: $user'),
///   onError: (error) => print('Failed: $error'),
/// );
/// ```
/// {@end-tool}
///
/// ## Using Cancellation Tokens
///
/// {@tool snippet}
/// Associate events with a token for group cancellation:
///
/// ```dart
/// final token = EventToken();
///
/// class UploadEvent extends BaseEvent<AppState> {
///   UploadEvent({super.token});
///
///   @override
///   Future<void> buildAction(EventManager<AppState> manager) async {
///     // Long-running operation
///   }
/// }
///
/// manager.addEventToQueue(UploadEvent(token: token));
///
/// // Cancel all events with this token
/// token.cancel(reason: 'User cancelled');
/// ```
/// {@end-tool}
///
/// ## Timeout Support
///
/// {@tool snippet}
/// Override [timeout] to set a maximum execution time:
///
/// ```dart
/// class ApiCallEvent extends BaseEvent<AppState> {
///   @override
///   Duration? get timeout => const Duration(seconds: 30);
///
///   @override
///   Future<Response> buildAction(EventManager<AppState> manager) async {
///     return await api.call(); // Times out after 30s
///   }
/// }
/// ```
/// {@end-tool}
///
/// ## Priority Queue
///
/// {@tool snippet}
/// Override [priority] to process urgent events first:
///
/// ```dart
/// class UrgentEvent extends BaseEvent<AppState> {
///   @override
///   int get priority => 100; // Higher = processed first
///
///   @override
///   void buildAction(EventManager<AppState> manager) {
///     // Processed before events with lower priority
///   }
/// }
/// ```
/// {@end-tool}
///
/// ## Automatic Retry
///
/// {@tool snippet}
/// Override [retryPolicy] for automatic retries on failure:
///
/// ```dart
/// class NetworkEvent extends BaseEvent<AppState> {
///   @override
///   RetryPolicy? get retryPolicy => RetryPolicy(
///     maxAttempts: 3,
///     backoff: RetryBackoff.exponential(
///       initial: Duration(seconds: 1),
///       maxDelay: Duration(seconds: 30),
///     ),
///   );
///
///   @override
///   Future<Data> buildAction(EventManager<AppState> manager) async {
///     return await api.fetchData(); // Retries on failure
///   }
/// }
/// ```
/// {@end-tool}
///
/// ## Progress Reporting
///
/// {@tool snippet}
/// Report progress during long-running operations:
///
/// ```dart
/// class DownloadEvent extends BaseEvent<AppState> {
///   @override
///   Future<File> buildAction(EventManager<AppState> manager) async {
///     for (var i = 0; i <= 100; i += 10) {
///       await downloadChunk(i);
///       reportProgress(i / 100, message: 'Downloading: $i%');
///     }
///     return downloadedFile;
///   }
/// }
///
/// // Listen to progress
/// event.listen(
///   onProgress: (value, message) => print('Progress: $value - $message'),
///   onDone: (data) => print('Downloaded: $data'),
/// );
/// ```
/// {@end-tool}
///
/// ## Retry Behavior
///
/// By default, all events are retriable - even completed or errored events
/// can be re-executed by re-adding to the queue. Only events cancelled with
/// `retriable: false` cannot be retried.
///
/// See also:
///
/// * [UndoableEvent] - Events that support undo/redo operations.
/// * [BatchEvent] - Process multiple events as a batch.
/// * [EventManager] - Processes events in a FIFO queue.
/// * [EventToken] - Group and control related events.
/// * [EventState] - Event lifecycle states.
/// {@endtemplate}
abstract class BaseEvent<T> extends Intent with PropertyStore {
  /// Creates a new event with optional debugging key and cancellation token.
  ///
  /// [debugKey] is used for identifying the event during debugging.
  /// [token] can be used to control this event along with other events sharing
  /// the same token.
  BaseEvent({
    this.debugKey,
    EventToken? token,
  }) : _token = token;

  /// A key used for debugging purposes to identify this event.
  final String? debugKey;

  /// The token associated with this event, if any.
  final EventToken? _token;

  /// The state controller for tracking event lifecycle.
  late final EventController _stateController =
      EventController(debugKey: debugKey);

  /// Builds an error object when the event fails.
  ///
  /// Override this method to customize error handling for your event.
  BaseError buildError(
    Object error,
    StackTrace? stackTrace,
    EventManager<T> manager,
  ) {
    if (error is BaseError) return error;
    return BaseError(
      asyncError: AsyncError(error, stackTrace),
      onRetry: () => manager.addEventToQueue(this),
    );
  }

  /// Determines if the event can be processed.
  ///
  /// Override this method to add custom enabling/disabling logic.
  bool isEnabled(EventManager<T> manager) => manager.isInitialized;

  /// Adds listeners for various event states.
  ///
  /// - [onQueue]: Called when event is queued
  /// - [onPause]: Called when event is paused (not terminal, listener kept)
  /// - [onStart]: Called when event starts processing
  /// - [onDone]: Called when event completes successfully
  /// - [onError]: Called when event fails
  /// - [onCancel]: Called when event is cancelled
  void listen({
    void Function()? onQueue,
    void Function()? onPause,
    void Function()? onStart,
    void Function(double value, String? message)? onProgress,
    void Function(Object? data)? onDone,
    void Function(BaseError error)? onError,
    void Function(Object? reason)? onCancel,
    void Function(int attempt, Duration delay)? onRetry,
    String? debugKey,
  }) {
    void listener(EventState? state) {
      state?.map(
        onQueue: onQueue,
        onPause: onPause, // Note: doesn't remove listener (not terminal)
        onStart: onStart,
        onProgress: onProgress,
        onRetry: onRetry,
        onDone: (data) {
          _stateController.removeListener(listener);
          return onDone?.call(data);
        },
        onError: (error) {
          _stateController.removeListener(listener);
          return onError?.call(error);
        },
        onCancel: (reason) {
          _stateController.removeListener(listener);
          return onCancel?.call(reason);
        },
      );
    }

    _stateController.addListener(listener);
  }

  /// The main action to be performed by this event.
  ///
  /// This method must be implemented by concrete event classes.
  @protected
  FutureOr<Object?> buildAction(EventManager<T> manager);

  /// Optional timeout for this event's execution.
  ///
  /// If the event takes longer than this duration, it will be cancelled
  /// with a [TimeoutException]. Override this to set a timeout:
  ///
  /// ```dart
  /// class MyApiEvent extends BaseEvent<String> {
  ///   @override
  ///   Duration? get timeout => const Duration(seconds: 30);
  /// }
  /// ```
  ///
  /// Returns `null` by default (no timeout).
  Duration? get timeout => null;

  /// The priority of this event in the queue.
  ///
  /// Higher values are processed first. Default is 0.
  /// Events with equal priority are processed in FIFO order.
  ///
  /// ```dart
  /// class UrgentEvent extends BaseEvent<String> {
  ///   @override
  ///   int get priority => 100; // High priority
  /// }
  /// ```
  int get priority => 0;

  /// Optional retry policy for automatic retries on failure.
  ///
  /// If set, the event will automatically retry on error according
  /// to the policy. Override this to enable automatic retries:
  ///
  /// ```dart
  /// class MyApiEvent extends BaseEvent<String> {
  ///   @override
  ///   RetryPolicy? get retryPolicy => RetryPolicy(
  ///     maxAttempts: 3,
  ///     backoff: RetryBackoff.exponential(
  ///       initial: Duration(seconds: 1),
  ///     ),
  ///   );
  /// }
  /// ```
  ///
  /// Returns `null` by default (no automatic retry).
  RetryPolicy? get retryPolicy => null;

  /// Reports progress during event execution.
  ///
  /// Call this from within [buildAction] to notify listeners of progress.
  /// Progress [value] should be between 0.0 and 1.0.
  ///
  /// ```dart
  /// @override
  /// Future<String> buildAction(EventManager<AppState> manager) async {
  ///   for (var i = 0; i <= 100; i += 10) {
  ///     await processChunk(i);
  ///     reportProgress(i / 100, message: 'Processing: $i%');
  ///   }
  ///   return 'Done';
  /// }
  /// ```
  ///
  /// Listeners receive progress via [listen] or [EventState.map]:
  /// ```dart
  /// event.listen((state) {
  ///   state.map(onProgress: (value, message) => print('$value: $message'));
  /// });
  /// ```
  void reportProgress(double value, {String? message}) {
    _stateController.value =
        EventState.progress(value: value, message: message);
  }

  /// Pauses this event.
  ///
  /// Paused events remain in the queue but are skipped during processing.
  /// Call [resume] to continue processing.
  ///
  /// ## When to use `pause()` vs `cancel()`
  ///
  /// Use `pause()` when you want to **temporarily stop** and **resume later**:
  /// ```dart
  /// // Pause during background state
  /// event.pause();
  ///
  /// // Resume when app returns to foreground
  /// event.resume();
  /// ```
  ///
  /// Use `cancel()` when the event should **stop permanently** or **start
  /// fresh**:
  /// ```dart
  /// // Cancel and potentially retry later
  /// event.cancel(reason: 'Network error', retriable: true);
  /// manager.addEventToQueue(event); // Re-adds as new
  /// ```
  ///
  /// Has no effect if the event is already paused, running, or in a terminal
  /// state.
  void pause() {
    if (_stateController.isTerminal || _stateController.isRunning) return;
    _stateController._onPause();
  }

  /// Resumes this event from paused state.
  ///
  /// The event will continue processing from where it was paused.
  ///
  /// Has no effect if the event is not paused.
  void resume() {
    _stateController._onResume();
  }

  /// Cancels this event.
  ///
  /// Cancelled events are removed from the queue and will not be processed.
  ///
  /// ## Parameters
  ///
  /// - [reason]: Optional explanation for the cancellation.
  /// - [retriable]: Whether the event can be re-added to the queue later
  ///   (default: `true`).
  ///
  /// ## When to use `retriable`
  ///
  /// - `retriable: true` (default): Event can be re-added to queue, starting
  ///   fresh. Use for temporary/recoverable cancellations.
  ///
  /// - `retriable: false`: Event is permanently cancelled. Use when the
  ///   operation should never be retried.
  ///
  /// ## Example
  ///
  /// ```dart
  /// // Cancel but allow retry later (default)
  /// event.cancel(reason: 'User navigated away');
  /// // Later: manager.addEventToQueue(event); // Works
  ///
  /// // Cancel permanently
  /// event.cancel(reason: 'Invalid data', retriable: false);
  /// // Later: manager.addEventToQueue(event); // Does nothing
  /// ```
  ///
  /// ## Difference from `pause()`
  ///
  /// | | `pause()` + `resume()` | `cancel()` + re-add |
  /// |---|---|---|
  /// | Event location | Stays in queue | Removed, then re-added |
  /// | State on continue | Resumes from paused | Starts fresh |
  /// | Use case | Temporary hold | Stop and optionally retry |
  void cancel({Object? reason, bool retriable = true}) {
    // Don't cancel if already in a terminal state
    if (_stateController.isTerminal) return;
    _stateController._onCancel(
      reason: reason ?? 'Event cancelled',
      retriable: retriable,
    );
  }

  /// Adds this event to the event manager.
  ///
  /// Convenience method that calls [EventManager.addEventToQueue].
  FutureOr<Object?> addTo(EventManager<T> manager) {
    return manager.addEventToQueue(this);
  }

  /// The current state of this event.
  EventState? get state => _stateController.value;

  /// Whether this event is paused.
  ///
  /// An event is paused if either:
  /// - It was directly paused via [pause]
  /// - Its [token] was paused
  bool get isPaused => _stateController.isPaused || (_token?.isPaused ?? false);

  /// Whether this event has been cancelled.
  bool get isCancelled =>
      _stateController.isCancelled || (_token?.isCancelled ?? false);

  /// Whether this event has reached a terminal state (completed, errored,
  /// or cancelled).
  bool get isUsed => _stateController.isTerminal;

  /// Whether this event can be retried.
  ///
  /// Returns `true` for:
  /// - Fresh events (not yet processed)
  /// - Completed events
  /// - Errored events
  /// - Cancelled events with `retriable: true`
  ///
  /// Returns `false` for:
  /// - Events currently in queue or running
  /// - Cancelled events with `retriable: false`
  bool get canRetry {
    // Check token cancellation first (lazy check)
    if (_token?.cancelData case final TokenCancellation cancelData) {
      return cancelData.retriable;
    }
    return switch (_stateController.value) {
      EventQueue() || EventStart() => false, // In progress
      EventCancel(:final retriable) => retriable, // Check retriable flag
      _ => true, // Completed/errored - always retriable
    };
  }

  /// The token associated with this event, if any.
  EventToken? get token => _token;

  /// A human-readable name for this event, defaults to the event's type.
  String get name => debugKey ?? toStringShort();

  /// A detailed description of this event.
  String get description => toString();

  /// The state controller for testing purposes.
  @visibleForTesting
  EventController get stateController => _stateController;
}

// ======================= Execution Mode ==========================

/// {@template mz_core.ExecutionMode}
/// Defines how [EventManager] processes events from its queue.
///
/// ## Available Modes
///
/// * [Sequential] - Process events one at a time, in order (default).
/// * [Concurrent] - Process multiple events simultaneously.
/// * [RateLimited] - Limit event processing to a maximum rate.
///
/// ## Example
///
/// ```dart
/// // Sequential queue processing (default)
/// EventManager(mode: const Sequential());
///
/// // Process up to 5 events concurrently
/// EventManager(mode: const Concurrent(maxConcurrency: 5));
///
/// // Rate limit to 60 events per minute
/// EventManager(mode: const RateLimited(limit: 60, window: Duration(minutes: 1)));
/// ```
///
/// See also:
///
/// * [EventManager.mode] - The mode property on EventManager.
/// {@endtemplate}
sealed class ExecutionMode {
  /// Creates an execution mode.
  const ExecutionMode();

  /// Creates a [Sequential] execution mode.
  const factory ExecutionMode.sequential() = Sequential;

  /// Creates a [Concurrent] execution mode.
  const factory ExecutionMode.concurrent({int? maxConcurrency}) = Concurrent;

  /// Creates a [RateLimited] execution mode.
  const factory ExecutionMode.rateLimited({
    required int limit,
    required Duration window,
  }) = RateLimited;
}

/// {@template mz_core.Sequential}
/// Processes events one at a time, in order.
///
/// This is the default [ExecutionMode] for [EventManager]. Events are
/// processed sequentially, preserving execution order.
///
/// ## Example
///
/// ```dart
/// final manager = EventManager<AppState>(
///   mode: const Sequential(), // This is the default
/// );
/// ```
/// {@endtemplate}
class Sequential extends ExecutionMode {
  /// Creates a sequential execution mode.
  const Sequential();
}

/// {@template mz_core.Concurrent}
/// Processes multiple events simultaneously.
///
/// Controls how many events [EventManager] can process at the same time
/// from its queue.
///
/// ## Example
///
/// ```dart
/// // Process up to 5 events concurrently
/// final manager = EventManager<AppState>(
///   mode: const Concurrent(maxConcurrency: 5),
/// );
///
/// // Unlimited concurrency
/// final manager = EventManager<AppState>(
///   mode: const Concurrent(),
/// );
/// ```
/// {@endtemplate}
class Concurrent extends ExecutionMode {
  /// Creates a concurrent execution mode.
  ///
  /// If [maxConcurrency] is null (default), unlimited events can run
  /// simultaneously. Otherwise, at most [maxConcurrency] events run at once.
  const Concurrent({this.maxConcurrency});

  /// Maximum number of concurrent executions, or null for unlimited.
  final int? maxConcurrency;
}

/// {@template mz_core.RateLimited}
/// Processes up to [limit] events per [window] duration.
///
/// Events beyond the limit are queued and processed when the window resets.
/// No events are dropped—they're delayed until allowed.
///
/// Use cases:
///
/// * API rate limits (e.g., 100 requests/minute)
/// * Payment gateway restrictions
/// * Email/SMS sending limits
/// * Database write batching
/// * Throttling (use `limit: 1` for one event per interval)
///
/// ## Example
///
/// ```dart
/// // Rate limit API calls to 60 per minute
/// final manager = EventManager<AppState>(
///   mode: const RateLimited(
///     limit: 60,
///     window: Duration(minutes: 1),
///   ),
/// );
///
/// // Throttle to one event per 100ms
/// final manager = EventManager<AppState>(
///   mode: const RateLimited(
///     limit: 1,
///     window: Duration(milliseconds: 100),
///   ),
/// );
/// ```
/// {@endtemplate}
class RateLimited extends ExecutionMode {
  /// Creates a rate-limited execution mode.
  ///
  /// At most [limit] events are processed per [window] duration.
  /// Use `limit: 1` for throttle-like behavior.
  const RateLimited({required this.limit, required this.window});

  /// Maximum number of events allowed per window.
  final int limit;

  /// Time window for rate limiting.
  final Duration window;
}

/// {@template mz_core.BatchEvent}
/// An event that processes multiple sub-events as a batch.
///
/// [BatchEvent] allows you to group related events and process them together.
/// It can be configured to fail fast on the first error or collect all errors.
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Process multiple events as a batch:
///
/// ```dart
/// final events = [
///   SaveItemEvent(item1),
///   SaveItemEvent(item2),
///   SaveItemEvent(item3),
/// ];
///
/// manager.addEventToQueue(
///   BatchEvent(events),
///   onDone: (event, results) => print('All saved: $results'),
///   onError: (error) => print('Batch failed: $error'),
/// );
/// ```
/// {@end-tool}
///
/// ## Eager vs Lazy Error Handling
///
/// {@tool snippet}
/// Control error handling behavior:
///
/// ```dart
/// // Fail fast - stop on first error (default)
/// final batch = BatchEvent(events, eagerError: true);
///
/// // Collect all errors - process all events, then report failures
/// final batch = BatchEvent(events, eagerError: false);
/// ```
/// {@end-tool}
///
/// ## Handling Batch Errors
///
/// {@tool snippet}
/// Access failed events from [BatchError]:
///
/// ```dart
/// manager.addEventToQueue(
///   BatchEvent(events, eagerError: false),
///   onError: (error) {
///     if (error is BatchError) {
///       for (final pending in error.pendingEvents) {
///         print('Failed: ${pending.event} - ${pending.error}');
///       }
///       // Retry failed events
///       error.onRetry?.call();
///     }
///   },
/// );
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [BaseEvent] - Base class for individual events.
/// * [BatchError] - Error containing failed batch events.
/// {@endtemplate}
class BatchEvent<T, E extends BaseEvent<T>> extends BaseEvent<T> {
  /// Creates a new batch event.
  ///
  /// [events] is the collection of events to process.
  /// [eagerError] determines if the batch should fail on first error or
  /// collect all errors.
  /// [concurrent] if true, all events start simultaneously; if false (default),
  /// events run one at a time.
  BatchEvent(
    this.events, {
    this.eagerError = true,
    this.concurrent = false,
  });

  /// The collection of events to process in this batch.
  final Iterable<E> events;

  /// Whether to fail immediately on the first error.
  ///
  /// If true, remaining events won't be processed after an error.
  /// If false, all events will be processed and errors collected.
  final bool eagerError;

  /// Whether to execute events concurrently.
  ///
  /// If true, all events start simultaneously using [Future.wait].
  /// If false (default), events run one at a time in order.
  final bool concurrent;

  @override
  bool isEnabled(EventManager<T> manager) =>
      events.isNotEmpty && events.any((e) => e.isEnabled(manager));

  @override
  FutureOr<List<Object?>> buildAction(EventManager<T> manager) {
    return concurrent
        ? _buildConcurrentAction(manager)
        : _buildSequentialAction(manager);
  }

  Future<List<Object?>> _buildSequentialAction(EventManager<T> manager) async {
    final pendingEvents = <PendingEvent<T, E>>[];
    final queue = ListQueue<E>.from(events);
    final results = <Object?>[];

    BatchError<T, E> error() {
      return BatchError<T, E>(
        onRetry: () => manager.addEventToQueue(
          BatchEvent<T, E>(pendingEvents.map((e) => e.event)),
        ),
        pendingEvents: pendingEvents,
      );
    }

    // _processEvents only throws BatchError (via _handleError when eagerError)
    // All other errors are collected in pendingEvents
    await _processEvents(queue, results, pendingEvents, manager);

    // If there are pending events, throw an error with a retry callback
    if (pendingEvents.isNotEmpty) {
      assert(queue.isEmpty, '');
      throw error();
    }

    return results;
  }

  Future<List<Object?>> _buildConcurrentAction(EventManager<T> manager) async {
    final eventList = events.toList();
    final pendingEvents = <PendingEvent<T, E>>[];

    // Start all events concurrently
    final futures = eventList.map((event) async {
      try {
        return await event.buildAction(manager);
      } on Object catch (error, stackTrace) {
        final baseError = event.buildError(error, stackTrace, manager);
        pendingEvents.add((event: event, error: baseError));
        rethrow;
      }
    }).toList();

    try {
      return await Future.wait(futures, eagerError: eagerError);
    } on Object {
      throw BatchError<T, E>(
        // coverage:ignore-start
        // When Future.wait throws, at least one future threw, which means
        // our catch block already added to pendingEvents. This branch is
        // defensive code that cannot be reached in practice.
        pendingEvents: pendingEvents.isEmpty
            ? eventList.map((e) => (event: e, error: null))
            : pendingEvents,
        // coverage:ignore-end
        onRetry: () => manager.addEventToQueue(
          BatchEvent<T, E>(
            pendingEvents.map((e) => e.event),
            concurrent: true,
          ),
        ),
      );
    }
  }

  FutureOr<void> _processEvents(
    ListQueue<E> queue,
    List<Object?> results,
    List<PendingEvent<T, E>> pendingEvents,
    EventManager<T> manager,
  ) {
    while (queue.isNotEmpty) {
      final event = queue.removeFirst();
      try {
        final future = event.buildAction(manager);
        if (future is Future<Object?>) {
          return _continueAsync(
            future,
            event,
            queue,
            results,
            pendingEvents,
            manager,
          );
        }
        results.add(future);
      } on Object catch (error, stackTrace) {
        _handleError(
          error,
          stackTrace,
          event,
          queue,
          pendingEvents,
          manager,
        );
      }
    }
  }

  /// Continues processing events asynchronously after encountering a Future.
  ///
  /// This method handles the async continuation while preserving synchronous
  /// execution for sync events in [_processEvents].
  Future<void> _continueAsync(
    Future<Object?> pendingFuture,
    E currentEvent,
    ListQueue<E> queue,
    List<Object?> results,
    List<PendingEvent<T, E>> pendingEvents,
    EventManager<T> manager,
  ) async {
    try {
      final result = await pendingFuture;
      results.add(result);
    } on Object catch (error, stackTrace) {
      _handleError(
        error,
        stackTrace,
        currentEvent,
        queue,
        pendingEvents,
        manager,
      );
    }
    return _processEvents(queue, results, pendingEvents, manager);
  }

  void _handleError(
    Object error,
    StackTrace stackTrace,
    E event,
    ListQueue<E> queue,
    List<PendingEvent<T, E>> pendingEvents,
    EventManager<T> manager,
  ) {
    final baseError = super.buildError(error, stackTrace, manager);
    if (eagerError) {
      throw BatchError<T, E>(
        onRetry: () => manager.addEventToQueue(
          BatchEvent<T, E>([event, ...queue]),
        ),
        pendingEvents: [
          (event: event, error: baseError),
          ...queue.map((e) => (event: e, error: null)),
        ],
      );
    }
    pendingEvents.add((event: event, error: baseError));
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      IterableProperty(
        'BatchEvent',
        events,
        ifEmpty: 'Event is triggered with empty list which should be avoided',
      ),
    );
  }
}

/// {@template mz_core.UndoableEvent}
/// Abstract base class for events that support undo/redo operations.
///
/// Extend this class when you need to create reversible actions. The
/// [UndoRedoManager] will automatically track these events and allow
/// users to undo/redo them.
///
/// ## Implementation Guide
///
/// 1. Override [captureState] to save current state before the action
/// 2. Implement [buildAction] to perform the action
/// 3. Override [undo] to reverse the action using captured state
/// 4. Optionally override [redo] if re-applying needs special handling
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Create an undoable event:
///
/// ```dart
/// class UpdateTitleEvent extends UndoableEvent<EditorState> {
///   UpdateTitleEvent(this.newTitle);
///
///   final String newTitle;
///   String? _previousTitle;
///
///   @override
///   void captureState(EventManager<EditorState> manager) {
///     _previousTitle = manager.state.title;
///   }
///
///   @override
///   FutureOr<void> buildAction(EventManager<EditorState> manager) {
///     manager.state.title = newTitle;
///   }
///
///   @override
///   FutureOr<void> undo(EventManager<EditorState> manager) {
///     manager.state.title = _previousTitle!;
///   }
///
///   @override
///   String get undoDescription => 'Change title to "$newTitle"';
/// }
/// ```
/// {@end-tool}
///
/// ## Event Merging
///
/// {@tool snippet}
/// Merge consecutive similar events (e.g., typing characters):
///
/// ```dart
/// class TypeCharacterEvent extends UndoableEvent<EditorState> {
///   TypeCharacterEvent(this.character);
///
///   final String character;
///   String _allCharacters = '';
///
///   @override
///   void captureState(EventManager<EditorState> manager) {}
///
///   @override
///   FutureOr<void> buildAction(EventManager<EditorState> manager) {
///     manager.state.text += character;
///   }
///
///   @override
///   FutureOr<void> undo(EventManager<EditorState> manager) {
///     // Remove typed characters
///   }
///
///   @override
///   bool canMergeWith(UndoableEvent<EditorState> other) {
///     return other is TypeCharacterEvent;
///   }
///
///   @override
///   UndoableEvent<EditorState>? mergeWith(UndoableEvent<EditorState> other) {
///     if (other is TypeCharacterEvent) {
///       _allCharacters += other.character;
///       return this;
///     }
///     return null;
///   }
///
///   @override
///   String get undoDescription => 'Type "$_allCharacters"';
/// }
/// ```
/// {@end-tool}
///
/// ## Undo/Redo Operations
///
/// {@tool snippet}
/// Use the undo manager to undo/redo:
///
/// ```dart
/// final undoManager = UndoRedoManager<EditorState>(maxHistorySize: 50);
/// final manager = EventManager<EditorState>(undoManager: undoManager);
///
/// // Execute undoable events
/// manager.addEventToQueue(UpdateTitleEvent('New Title'));
///
/// // Undo last action
/// await undoManager.undo(manager);
///
/// // Redo the undone action
/// await undoManager.redo(manager);
///
/// // Undo multiple actions
/// await undoManager.undo(manager, count: 3);
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [UndoRedoManager] - Manages the undo/redo history.
/// * [BaseEvent] - The non-undoable base event class.
/// * [HistoryEntry] - Entry in the undo/redo history stack.
/// {@endtemplate}
abstract class UndoableEvent<T> extends BaseEvent<T> {
  /// Creates an undoable event.
  UndoableEvent({super.debugKey, super.token});

  /// Captures the current state before the action is performed.
  ///
  /// Called automatically before [buildAction]. Store any state needed
  /// to reverse this action in instance variables.
  ///
  /// This method is called synchronously and should be fast.
  @protected
  void captureState(EventManager<T> manager);

  /// Reverses the action performed by [buildAction].
  ///
  /// Called when the user triggers undo. Use the state captured in
  /// [captureState] to restore the previous state.
  @protected
  FutureOr<void> undo(EventManager<T> manager);

  /// Re-applies the action after it was undone.
  ///
  /// By default, this calls [buildAction] again. Override if your
  /// action needs different behavior when redoing vs. doing initially.
  @protected
  FutureOr<void> redo(EventManager<T> manager) => buildAction(manager);

  /// Human-readable description of this action for UI display.
  ///
  /// Used in undo/redo menus. Example: "Delete 3 items", "Change color to red"
  String get undoDescription => name;

  /// Whether this event can be merged with another event of the same type.
  ///
  /// Override to return true for events that should coalesce (e.g., typing
  /// characters, slider movements). Merging reduces undo history size.
  bool canMergeWith(UndoableEvent<T> other) => false;

  /// Merges this event with another event.
  ///
  /// Only called if [canMergeWith] returns true. Return a new event
  /// that represents the combined action, or null to keep them separate.
  UndoableEvent<T>? mergeWith(UndoableEvent<T> other) => null;
}

/// {@template mz_core.EventController}
/// Lightweight event state controller for [BaseEvent] lifecycle management.
///
/// Unlike the general-purpose [Controller], this is purpose-built for
/// [BaseEvent] state management with:
/// - Simple state value tracking
/// - Single list of typed listeners
/// - Pattern matching for state filtering
/// - Minimal memory footprint
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Listen to event state changes:
///
/// ```dart
/// final controller = EventController();
///
/// controller.addListener((state) {
///   switch (state) {
///     case EventCancel(:final reason):
///       print('Cancelled: $reason');
///     case EventComplete(:final data):
///       print('Done: $data');
///     default:
///       break;
///   }
/// });
/// ```
/// {@end-tool}
///
/// ## State Queries
///
/// {@tool snippet}
/// Check current state:
///
/// ```dart
/// if (controller.isPaused) {
///   print('Event is paused');
/// }
/// if (controller.isTerminal) {
///   print('Event has finished');
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [BaseEvent] - Uses EventController for lifecycle tracking.
/// * [EventState] - The state values tracked by this controller.
/// * [Controller] - General-purpose listener notification.
/// {@endtemplate}
class EventController {
  /// Creates a state controller with optional debug key.
  EventController({this.debugKey});

  /// Debug key for identifying this controller.
  final String? debugKey;

  /// The current event state.
  EventState? _value;

  // Single list of listeners - all receive all state changes
  List<StateListener>? _listeners;

  // Notification state for safe removal during iteration
  int _notificationDepth = 0;
  List<StateListener>? _pendingRemovals;

  /// Gets the current event state.
  EventState? get value => _value;

  /// Sets the current event state and notifies all listeners.
  set value(EventState? newValue) {
    if (_value == newValue) return;
    _value = newValue;
    _notifyListeners(newValue);
  }

  /// Notifies all listeners with the given state.
  ///
  /// Safe for listener self-removal during iteration.
  void _notifyListeners(EventState? state) {
    final listeners = _listeners;
    if (listeners == null || listeners.isEmpty) return;

    _notificationDepth++;
    try {
      final length = listeners.length;
      for (var i = 0; i < length; i++) {
        if (i < listeners.length) {
          listeners[i](state);
        }
      }
    } finally {
      _notificationDepth--;

      if (_notificationDepth == 0 && _pendingRemovals != null) {
        _pendingRemovals!.forEach(_listeners!.remove);
        _pendingRemovals = null;
      }
    }
  }

  /// Pauses the event and notifies listeners.
  void _onPause() {
    if (isTerminal || isPaused) return;
    value = EventState.pause();
  }

  /// Resumes the event from paused state and notifies listeners.
  void _onResume() {
    if (!isPaused) return;
    value = EventState.queue();
  }

  /// Cancels the event with the given reason and retriable flag.
  void _onCancel({required Object? reason, required bool retriable}) {
    if (isTerminal) return;
    value = EventState.cancel(reason: reason, retriable: retriable);
  }

  /// Adds a listener for state changes.
  ///
  /// The listener receives all state changes. Use pattern matching
  /// to filter which states to handle:
  ///
  /// ```dart
  /// controller.addListener((state) {
  ///   if (state is EventCancel) {
  ///     // Handle cancellation
  ///   }
  /// });
  /// ```
  void addListener(StateListener listener) {
    _listeners ??= [];
    _listeners!.add(listener);
  }

  /// Removes a previously registered listener.
  ///
  /// Safe to call during notification - removal is deferred until
  /// notification completes.
  void removeListener(StateListener listener) {
    if (_notificationDepth > 0) {
      _pendingRemovals ??= [];
      _pendingRemovals!.add(listener);
    } else {
      _listeners?.remove(listener);
    }
  }

  /// Whether the event is paused.
  bool get isPaused => _value?.isPaused ?? false;

  /// Whether the event is currently running.
  bool get isRunning => _value?.isRunning ?? false;

  /// Whether the event has been cancelled.
  bool get isCancelled => _value?.isCancelled ?? false;

  /// Whether the event has completed successfully.
  bool get isCompleted => _value?.isCompleted ?? false;

  /// Whether the event has reached a terminal state
  /// (completed, errored, or cancelled).
  bool get isTerminal => _value?.isTerminal ?? false;

  /// Whether this controller has any listeners registered.
  bool get hasListeners => _listeners != null && _listeners!.isNotEmpty;
}

// ======================= Undo/Redo Manager ==========================

/// {@template mz_core.HistoryEntry}
/// Entry in the undo/redo history stack.
///
/// Each entry contains the [UndoableEvent] that was executed and when
/// it was executed. Use [UndoableEvent.undoDescription] to get a human-readable
/// description of the action.
///
/// ## Accessing History
///
/// {@tool snippet}
/// Iterate over history entries:
///
/// ```dart
/// for (final entry in undoManager.undoHistory) {
///   print('${entry.event.undoDescription} at ${entry.timestamp}');
/// }
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [UndoRedoManager] - Manages the history stack.
/// * [UndoableEvent] - Events tracked in history.
/// {@endtemplate}
@immutable
class HistoryEntry<T> {
  /// Creates a history entry.
  const HistoryEntry({
    required this.event,
    required this.timestamp,
  });

  /// The undoable event that was executed.
  final UndoableEvent<T> event;

  /// When the event was executed.
  final DateTime timestamp;

  @override
  String toString() => 'HistoryEntry(${event.undoDescription})';
}

/// {@template mz_core.UndoRedoManager}
/// Manages undo/redo history for [UndoableEvent]s.
///
/// Provides a stack-based undo/redo system with configurable history size.
/// Integrates with [EventManager] to automatically track undoable events.
///
/// ## Features
///
/// - Configurable maximum history size
/// - Undo/redo multiple steps at once
/// - Event merging for reducing history size
/// - Observable state for UI updates
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Set up undo/redo with EventManager:
///
/// ```dart
/// final undoManager = UndoRedoManager<AppState>(maxHistorySize: 50);
/// final manager = EventManager<AppState>(undoManager: undoManager);
///
/// // Add undoable events
/// manager.addEventToQueue(UpdateNameEvent('John'));
/// manager.addEventToQueue(UpdateAgeEvent(30));
///
/// // Undo last action
/// await undoManager.undo(manager);
///
/// // Undo multiple actions
/// await undoManager.undo(manager, count: 3);
///
/// // Redo
/// await undoManager.redo(manager);
/// ```
/// {@end-tool}
///
/// ## Checking Undo/Redo State
///
/// {@tool snippet}
/// Build UI that reacts to undo/redo availability:
///
/// ```dart
/// ListenableBuilder(
///   listenable: undoManager,
///   builder: (context, _) {
///     return Row(
///       children: [
///         IconButton(
///           onPressed: undoManager.canUndo
///               ? () => undoManager.undo(manager)
///               : null,
///           icon: Icon(Icons.undo),
///           tooltip: undoManager.undoDescription,
///         ),
///         IconButton(
///           onPressed: undoManager.canRedo
///               ? () => undoManager.redo(manager)
///               : null,
///           icon: Icon(Icons.redo),
///           tooltip: undoManager.redoDescription,
///         ),
///       ],
///     );
///   },
/// )
/// ```
/// {@end-tool}
///
/// ## Accessing History
///
/// {@tool snippet}
/// Access the undo/redo history stacks:
///
/// ```dart
/// // Get history entries
/// final history = undoManager.undoHistory;
/// for (final entry in history) {
///   print('${entry.event.undoDescription} at ${entry.timestamp}');
/// }
///
/// // Check counts
/// print('Can undo ${undoManager.undoCount} actions');
/// print('Can redo ${undoManager.redoCount} actions');
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [UndoableEvent] - Events that support undo/redo.
/// * [HistoryEntry] - Entry in the undo/redo history stack.
/// * [EventManager] - Processes events and integrates with undo/redo.
/// {@endtemplate}
class UndoRedoManager<T> with ChangeNotifier {
  /// Creates an undo/redo manager.
  ///
  /// [maxHistorySize] limits the undo history. Oldest entries are removed
  /// when the limit is reached. Defaults to 100.
  UndoRedoManager({this.maxHistorySize = 100});

  /// Maximum number of actions to keep in undo history.
  final int maxHistorySize;

  // Using ListQueue for O(1) operations at both ends
  final _undoStack = ListQueue<HistoryEntry<T>>();
  final _redoStack = ListQueue<HistoryEntry<T>>();

  /// Whether there are actions that can be undone.
  bool get canUndo => _undoStack.isNotEmpty;

  /// Whether there are actions that can be redone.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Number of actions in the undo stack.
  int get undoCount => _undoStack.length;

  /// Number of actions in the redo stack.
  int get redoCount => _redoStack.length;

  /// The undo history (oldest first).
  List<HistoryEntry<T>> get undoHistory => _undoStack.toList();

  /// The redo history (oldest first).
  List<HistoryEntry<T>> get redoHistory => _redoStack.toList();

  /// Description of the action that would be undone.
  String? get undoDescription =>
      _undoStack.isNotEmpty ? _undoStack.last.event.undoDescription : null;

  /// Description of the action that would be redone.
  String? get redoDescription =>
      _redoStack.isNotEmpty ? _redoStack.last.event.undoDescription : null;

  /// Records a completed undoable event.
  ///
  /// Called automatically by [EventManager] when an [UndoableEvent] completes.
  void record(UndoableEvent<T> event) {
    // Clear redo stack - new actions invalidate redo history
    if (_redoStack.isNotEmpty) {
      _redoStack.clear();
    }

    final entry = HistoryEntry<T>(
      event: event,
      timestamp: DateTime.now(),
    );

    // Try to merge with previous event
    if (_undoStack.isNotEmpty) {
      final lastEntry = _undoStack.last;
      if (lastEntry.event.canMergeWith(event)) {
        final merged = lastEntry.event.mergeWith(event);
        if (merged != null) {
          _undoStack
            ..removeLast()
            ..addLast(
              HistoryEntry<T>(
                event: merged,
                timestamp: DateTime.now(),
              ),
            );
          notifyListeners();
          return;
        }
      }
    }

    // Add to history, removing oldest if at limit
    if (_undoStack.length >= maxHistorySize) {
      _undoStack.removeFirst();
    }
    _undoStack.addLast(entry);
    notifyListeners();
  }

  /// Undoes the last [count] actions.
  ///
  /// Returns the number of actions actually undone (may be less than
  /// [count] if there aren't enough actions in history).
  Future<int> undo(EventManager<T> manager, {int count = 1}) async {
    var undone = 0;
    for (var i = 0; i < count && canUndo; i++) {
      final entry = _undoStack.removeLast();
      await entry.event.undo(manager);
      _redoStack.addLast(entry);
      undone++;
    }
    if (undone > 0) notifyListeners();
    return undone;
  }

  /// Redoes the last [count] undone actions.
  ///
  /// Returns the number of actions actually redone.
  Future<int> redo(EventManager<T> manager, {int count = 1}) async {
    var redone = 0;
    for (var i = 0; i < count && canRedo; i++) {
      final entry = _redoStack.removeLast();
      await entry.event.redo(manager);
      _undoStack.addLast(entry);
      redone++;
    }
    if (redone > 0) notifyListeners();
    return redone;
  }

  /// Clears all undo/redo history.
  void clear() {
    final hadHistory = _undoStack.isNotEmpty || _redoStack.isNotEmpty;
    _undoStack.clear();
    _redoStack.clear();
    if (hadHistory) notifyListeners();
  }

  /// Clears only the redo history.
  void clearRedo() {
    if (_redoStack.isNotEmpty) {
      _redoStack.clear();
      notifyListeners();
    }
  }
}

// ======================= Event Manager ==========================

/// {@template mz_core.EventManager}
/// A manager for handling synchronous/asynchronous events in a
/// FIFO (First In, First Out) queue.
///
/// The [EventManager] provides functionality to:
/// * Queue and process events in order
/// * Pause and resume event processing
/// * Handle both synchronous and asynchronous events
/// * Support event cancellation and error handling
/// * Manage event listeners and callbacks
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Define a custom event and process it:
///
/// ```dart
/// class CustomEvent extends BaseEvent<String> {
///   CustomEvent({super.debugKey, super.token});
///
///   @override
///   FutureOr<Object?> buildAction(EventManager<String> manager) async {
///     await Future.delayed(Duration(seconds: 1));
///     return 'Hello, World!';
///   }
/// }
///
/// // Create an event manager
/// final manager = EventManager<String>();
///
/// // Add event with callbacks
/// final event = CustomEvent(debugKey: 'greeting');
/// manager.addEventToQueue(
///   event,
///   onDone: (event, result) => print('Completed: $result'),
///   onError: (error) => print('Failed: $error'),
/// );
/// ```
/// {@end-tool}
///
/// ## Pause and Resume
///
/// {@tool snippet}
/// Control event processing:
///
/// ```dart
/// final manager = EventManager<String>();
///
/// // Queue events while paused
/// manager.pauseEvents();
/// manager.addEventToQueue(event1);
/// manager.addEventToQueue(event2);
///
/// // Resume processing
/// manager.resumeEvents();
/// ```
/// {@end-tool}
///
/// ## Token-Based Cancellation
///
/// {@tool snippet}
/// Cancel events using tokens:
///
/// ```dart
/// final token = EventToken();
/// final cancellableEvent = CustomEvent(
///   debugKey: 'cancellable',
///   token: token,
/// );
/// manager.addEventToQueue(cancellableEvent);
///
/// // Cancel all events with this token
/// token.cancel();
/// ```
/// {@end-tool}
///
/// ## Backpressure Configuration
///
/// {@tool snippet}
/// Configure queue limits and overflow handling:
///
/// ```dart
/// final manager = EventManager<AppState>(
///   maxQueueSize: 1000,
///   overflowPolicy: OverflowPolicy.dropOldest,
///   frameBudget: Duration(milliseconds: 8),
/// );
/// ```
/// {@end-tool}
///
/// ## Undo/Redo Support
///
/// {@tool snippet}
/// Enable undo/redo for undoable events:
///
/// ```dart
/// final undoManager = UndoRedoManager<AppState>(maxHistorySize: 50);
/// final manager = EventManager<AppState>(undoManager: undoManager);
///
/// // Later...
/// await manager.undoManager?.undo(manager);
/// await manager.undoManager?.redo(manager);
/// ```
/// {@end-tool}
///
/// ## Use Cases
///
/// The [EventManager] is particularly useful when you need to:
/// * Ensure events are processed in order
/// * Handle a mix of sync and async operations
/// * Implement cancellable operations
/// * Manage state transitions with proper error handling
///
/// See also:
///
/// * [BaseEvent] - The abstract base class for creating custom events.
/// * [EventToken] - Used for grouping and cancelling related events.
/// * [UndoRedoManager] - Manages undo/redo history.
/// * [EventLogger] - Tracks event lifecycle with logging.
/// {@endtemplate}
class EventManager<T> extends Controller with Diagnosticable {
  /// Creates a new event manager.
  ///
  /// **Parameters:**
  ///
  /// - [logger] Optional event logger to track event processing.
  /// - [debugLabel] Optional label used for debugging purposes.
  /// - [maxBatchSize] Max sync events before yielding to UI thread (default 50)
  /// - [maxQueueSize] Max queue size for backpressure (default unlimited)
  /// - [overflowPolicy] How to handle queue overflow (default dropNewest)
  /// - [frameBudget] Time budget per batch before yielding (default 8ms)
  /// - [undoManager] Optional manager for undo/redo functionality
  /// - [mode] Execution mode - [Sequential] (default) or [Concurrent]
  EventManager({
    EventLogger<T>? logger,
    String? debugLabel,
    this.maxBatchSize = 50,
    this.maxQueueSize,
    this.overflowPolicy = OverflowPolicy.dropNewest,
    this.frameBudget = const Duration(milliseconds: 8),
    this.undoManager,
    this.mode = const Sequential(),
  })  : logger = logger ?? EventLogger<T>(debugLabel: debugLabel),
        _disposeLogger = logger == null;

  static bool get _isDebug {
    var inDebugMode = false;
    assert(inDebugMode = true, '');
    return inDebugMode;
  }

  /// The maximum number of synchronous events to process consecutively
  /// before yielding to the event loop.
  ///
  /// This value balances between processing efficiency and UI responsiveness:
  /// - Higher values (50-100) improve throughput for sync-heavy workloads
  ///   but may delay UI updates
  /// - Lower values (10-20) increase UI responsiveness but add microtask
  ///   overhead
  ///
  /// Typical usage scenarios:
  /// - **Data processing**: Use higher values (50-100)
  /// - **UI-driven apps**: Use lower values (10-30)
  /// - **Mixed workloads**: Default 50 is a good balance
  ///
  /// Defaults to `50` which allows processing ~1ms of sync work per frame
  /// at 60 FPS (16ms per frame).
  final int maxBatchSize;

  /// Maximum number of events allowed in the queue.
  ///
  /// When null (default), the queue can grow unbounded. Set this to prevent
  /// memory issues in high-throughput scenarios.
  ///
  /// When the limit is reached, behavior is determined by [overflowPolicy].
  ///
  /// **Example:**
  /// ```dart
  /// final manager = EventManager<AppState>(
  ///   maxQueueSize: 1000,
  ///   overflowPolicy: OverflowPolicy.dropOldest,
  /// );
  /// ```
  final int? maxQueueSize;

  /// Policy for handling new events when queue is full.
  ///
  /// Only applies when [maxQueueSize] is set. See [OverflowPolicy] for options.
  final OverflowPolicy overflowPolicy;

  /// Time budget for processing sync events before yielding to UI thread.
  ///
  /// The processor will yield after this duration even if [maxBatchSize]
  /// hasn't been reached. This ensures UI remains responsive.
  ///
  /// Defaults to 8ms (half of 16ms frame budget at 60 FPS).
  final Duration frameBudget;

  /// Optional manager for undo/redo functionality.
  ///
  /// When provided, [UndoableEvent]s will automatically be tracked and
  /// can be undone/redone through this manager.
  ///
  /// **Example:**
  /// ```dart
  /// final manager = EventManager<AppState>(
  ///   undoManager: UndoRedoManager(maxHistorySize: 50),
  /// );
  ///
  /// // Later...
  /// manager.undoManager?.undo(manager);
  /// ```
  final UndoRedoManager<T>? undoManager;

  /// The execution mode for queue processing.
  ///
  /// Controls how events are processed from the queue:
  ///
  /// - [Sequential] (default): Process one event at a time
  /// - [Concurrent]: Process multiple events simultaneously
  ///
  /// For [Concurrent] mode, use [Concurrent.maxConcurrency] to limit
  /// simultaneous executions.
  ///
  /// Priority still determines **start order**, not completion order.
  /// Higher priority events start first, but multiple events may run
  /// concurrently.
  ///
  /// **Example:**
  /// ```dart
  /// // Process up to 5 events concurrently
  /// final manager = EventManager<AppState>(
  ///   mode: const Concurrent(maxConcurrency: 5),
  /// );
  ///
  /// // These can all run concurrently (up to the limit)
  /// manager.addEventToQueue(UpdateCellEvent('A1', value1));
  /// manager.addEventToQueue(UpdateCellEvent('B2', value2));
  /// manager.addEventToQueue(UpdateCellEvent('C3', value3));
  /// ```
  final ExecutionMode mode;

  final bool _disposeLogger;

  /// The event logger used to track event processing.
  final EventLogger<T>? logger;

  final _queue = _EventQueue<T>();
  bool _isProcessing = false;
  bool _isPaused = false;

  // Stream subscriptions for automatic cleanup on dispose
  final _streamSubscriptions = <StreamSubscription<BaseEvent<T>>>{};

  // Concurrent execution tracking
  int _activeCount = 0;

  // Rate-limit timing state
  DateTime? _windowStartTime;
  int _executionCountInWindow = 0;
  Timer? _rateLimitTimer;

  /// Whether more events can be started based on [mode].
  bool get _canStartMore => switch (mode) {
        Sequential() => _canStartSequential,
        Concurrent(:final maxConcurrency) =>
          _canStartConcurrent(maxConcurrency),
        RateLimited(:final limit, :final window) =>
          _canStartRateLimited(limit, window),
      };

  bool get _canStartSequential => _activeCount < 1;

  bool _canStartConcurrent(int? maxConcurrency) =>
      maxConcurrency == null || _activeCount < maxConcurrency;

  bool _canStartRateLimited(int limit, Duration window) {
    _resetWindowIfExpired(window);
    return _executionCountInWindow < limit;
  }

  void _resetWindowIfExpired(Duration window) {
    final now = DateTime.now();
    if (_windowStartTime == null ||
        now.difference(_windowStartTime!) >= window) {
      _windowStartTime = now;
      _executionCountInWindow = 0;
    }
  }

  void _recordExecution() {
    if (mode is RateLimited) {
      _executionCountInWindow++;
    }
  }

  /// Number of events currently executing.
  int get activeEventCount => _activeCount;

  // Token reference counting for efficient listener management
  final _tokenRefCounts = <EventToken, int>{};

  /// Registers a token for listening, using reference counting.
  ///
  /// Only adds a listener on the first event using this token.
  void _registerToken(EventToken? token) {
    if (token == null) return;

    final count = _tokenRefCounts[token] ?? 0;
    if (count == 0) {
      // First event with this token - add listener
      token.listener = _onTokenStateChanged;
    }
    _tokenRefCounts[token] = count + 1;
  }

  /// Unregisters a token, removing listener when no events use it.
  void _unregisterToken(EventToken? token) {
    if (token == null) return;

    final count = _tokenRefCounts[token] ?? 0;
    if (count <= 1) {
      // Last event with this token - remove listener
      _tokenRefCounts.remove(token);
      token.listener = null;
    } else {
      _tokenRefCounts[token] = count - 1;
    }
  }

  /// Called when any tracked token's state changes.
  void _onTokenStateChanged() {
    // Restart processing if we're idle and have events
    // This handles the case where token.resume() is called
    if (!_isProcessing && hasEvents && !_isPaused) {
      // FutureOr cannot be awaited
      // ignore: discarded_futures
      _processQueue();
    }
  }

  /// Called when an individual event is resumed via [BaseEvent.resume].
  void _onEventResumed() {
    // Restart processing if we're idle and have events
    if (!_isProcessing && hasEvents && !_isPaused) {
      // FutureOr cannot be awaited
      // ignore: discarded_futures
      _processQueue();
    }
  }

  /// Add an [event] to the queue and optionally starts processing.
  ///
  /// Returns a [FutureOr] that completes with the event result, or null if:
  /// - Event is disabled via [BaseEvent.isEnabled]
  /// - Event was cancelled
  /// - Queue is full and [overflowPolicy] is [OverflowPolicy.dropNewest]
  ///
  /// Throws [QueueOverflowError] if queue is full and [overflowPolicy] is
  /// [OverflowPolicy.error].
  @protected
  @visibleForTesting
  FutureOr<Object?> addEventToQueue<E extends BaseEvent<T>>(
    E event, {
    OnDone<T, E>? onDone,
    OnError<T>? onError,
  }) {
    if (!event.isEnabled(this)) return null;

    // Handle queue overflow if maxQueueSize is set
    if (maxQueueSize != null && _queue.length >= maxQueueSize!) {
      switch (overflowPolicy) {
        case OverflowPolicy.dropNewest:
          // Silently drop the new event
          return null;
        case OverflowPolicy.dropOldest:
          // Remove oldest event to make room
          final oldest = _queue.removeFirst();
          oldest.cancel('Dropped due to queue overflow', this);
        case OverflowPolicy.error:
          throw QueueOverflowError(
            queueSize: _queue.length,
            maxQueueSize: maxQueueSize!,
            event: event,
          );
      }
    }

    // Register token for state change notifications
    _registerToken(event.token);

    final queuedEvent = _QueuedEvent<T, E>(
      event: event,
      onDone: onDone,
      onError: onError,
    );
    if (!queuedEvent.addTo(_queue, this)) {
      // Event was not added (cancelled, etc.) - unregister token
      _unregisterToken(event.token);
      return null;
    }
    if (isInitialized) {
      if (!_isProcessing) {
        // FutureOr cannot be awaited
        // ignore: discarded_futures
        _processQueue();
      } else if (_canStartMore) {
        // Already processing, but have capacity for more concurrent events
        scheduleMicrotask(_processQueue);
      }
    }
    return queuedEvent.result;
  }

  /// Subscribes to a stream of events, adding each to the queue as it arrives.
  ///
  /// Returns the [StreamSubscription] for manual cancellation.
  /// Subscription is automatically cancelled when the manager is disposed.
  ///
  /// ## Basic Usage
  ///
  /// {@tool snippet}
  /// Subscribe to WebSocket events:
  ///
  /// ```dart
  /// final subscription = manager.addEventStream(
  ///   webSocket.messages.map((msg) => ProcessMessageEvent(msg)),
  ///   onDone: (event, result) => print('Processed: $result'),
  ///   onStreamError: (e, s) => print('Stream error: $e'),
  /// );
  ///
  /// // Later: manual cancellation
  /// subscription.cancel();
  /// ```
  /// {@end-tool}
  ///
  /// ## Parameters
  ///
  /// * [stream] - The stream of events to subscribe to.
  /// * [onDone] - Optional callback for when each event completes.
  /// * [onError] - Optional callback for when an event fails.
  /// * [onStreamError] - Called when the stream itself produces an error.
  /// * [onStreamDone] - Called when the stream closes.
  /// * [cancelOnError] - If true, cancels subscription on first stream error.
  ///
  /// See also:
  ///
  /// * [addEventToQueue] - Add a single event to the queue.
  StreamSubscription<E> addEventStream<E extends BaseEvent<T>>(
    Stream<E> stream, {
    OnDone<T, E>? onDone,
    OnError<T>? onError,
    void Function(Object error, StackTrace stackTrace)? onStreamError,
    void Function()? onStreamDone,
    bool cancelOnError = false,
  }) {
    late StreamSubscription<E> subscription;
    subscription = stream.listen(
      (event) {
        unawaited(
          Future.value(
            addEventToQueue(event, onDone: onDone, onError: onError),
          ),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        onStreamError?.call(error, stackTrace);
      },
      onDone: () {
        _streamSubscriptions.remove(subscription);
        onStreamDone?.call();
      },
      cancelOnError: cancelOnError,
    );
    _streamSubscriptions.add(subscription);
    return subscription;
  }

  /// Processes an event instantly without entering the queue.
  ///
  /// [event] The event to execute.
  /// [onDone] Optional callback for when the event completes.
  /// [onError] Optional callback for when the event fails.
  @protected
  @visibleForTesting
  FutureOr<void> processEvent<E extends BaseEvent<T>>(
    E event, {
    OnDone<T, E>? onDone,
    OnError<T>? onError,
  }) {
    if (!event.isEnabled(this)) return null;
    final queuedEvent = _QueuedEvent<T, E>(
      event: event,
      onDone: onDone,
      onError: onError,
    );
    return queuedEvent.run(this);
  }

  /// Stopwatch for time-based batching (reused to avoid allocations)
  final _batchStopwatch = Stopwatch();

  FutureOr<void> _processQueue() {
    if (_queue.isEmpty || _isPaused) {
      // Only mark as not processing if no active events
      if (_activeCount == 0) _isProcessing = false;
      return null;
    }
    _isProcessing = true;

    // Time-based batching for UI responsiveness
    _batchStopwatch
      ..reset()
      ..start();

    var started = 0;
    var skippedPaused = 0;
    final queueLength = _queue.length;

    while (_queue.isNotEmpty &&
        !_isPaused &&
        started < maxBatchSize &&
        skippedPaused < queueLength &&
        _batchStopwatch.elapsed < frameBudget &&
        _canStartMore) {
      final completer = _queue.first;

      // Skip paused events - move to end of queue and continue
      if (completer.isPaused) {
        _queue
          ..removeFirst()
          ..addLast(completer);
        skippedPaused++;
        continue;
      }

      // Not paused - remove and start
      _queue.removeFirst();
      skippedPaused = 0; // Reset counter when we start an event
      started++;
      _activeCount++;
      _recordExecution();

      final result = completer.run(this);
      if (result is Future) {
        // Track async event completion
        unawaited(result.whenComplete(_onEventComplete));
      } else {
        // Sync event completed immediately
        _activeCount--;
      }
    }

    _batchStopwatch.stop();

    // Track if all remaining events are paused
    final allPaused = skippedPaused >= queueLength;

    // Schedule next batch based on mode
    if (started > 0 || (_queue.isNotEmpty && !allPaused)) {
      _scheduleNextBasedOnMode();
    } else if (_activeCount == 0) {
      // No active events and nothing started - stop processing
      _isProcessing = false;
    }
    // else: active events running, they'll trigger next batch on complete

    return null;
  }

  /// Called when an async event completes to potentially start more events.
  void _onEventComplete() {
    _activeCount--;

    // Try to start more events if queue has items
    if (_queue.isNotEmpty && !_isPaused) {
      // Use mode-aware scheduling to respect throttle/rate-limit timings
      _scheduleNextBasedOnMode();
    } else if (_activeCount == 0) {
      _isProcessing = false;
    }
  }

  /// Schedules next batch based on the execution mode.
  void _scheduleNextBasedOnMode() {
    if (_queue.isEmpty || _isPaused) {
      if (_activeCount == 0) _isProcessing = false;
      return;
    }

    switch (mode) {
      case Sequential():
      case Concurrent():
        _scheduleNext();
      case RateLimited(:final limit, :final window):
        _scheduleRateLimited(limit, window);
    }
  }

  void _scheduleRateLimited(int limit, Duration window) {
    _rateLimitTimer?.cancel();

    if (_canStartMore) {
      _scheduleNext();
      return;
    }

    // Calculate delay until window resets
    final elapsed = DateTime.now().difference(_windowStartTime!);
    final remaining = window - elapsed;

    // coverage:ignore-start
    // Race condition guard: window could expire between _canStartMore check
    // and DateTime.now() call above. Practically impossible to trigger in tests.
    if (remaining.isNegative) {
      _scheduleNext();
    } else {
      // coverage:ignore-end
      // Not actively processing - just waiting for timer
      if (_activeCount == 0) _isProcessing = false;
      _rateLimitTimer = Timer(remaining, _processQueue);
    }
  }

  void _scheduleNext() {
    if (_queue.isEmpty || _isPaused || !_canStartMore) {
      if (_activeCount == 0) _isProcessing = false;
      return;
    }
    assert(
      () {
        debugPrint('EventManager: Scheduling next batch');
        return true;
      }(),
      'Debug assertion for scheduling next batch',
    );
    scheduleMicrotask(_processQueue);
  }

  /// Pauses event processing.
  ///
  /// Events added while paused will be queued but not processed until
  /// [resumeEvents] is called.
  ///
  /// Any pending throttle/rate-limit timers are cancelled while paused.
  void pauseEvents() {
    if (_isPaused) return;
    _isPaused = true;
    // Cancel any pending throttle/rate-limit timer
    _rateLimitTimer?.cancel();
    _rateLimitTimer = null;
  }

  /// Resumes processing of queued events.
  ///
  /// If there are events in the queue when resumed, they will be processed
  /// respecting the current [mode] settings (throttle intervals, rate limits).
  void resumeEvents() {
    assert(
      !_isProcessing,
      'Cannot resume while processing. Wait for current batch to complete.',
    );
    if (!_isPaused || !hasEvents) return;
    _isPaused = false;

    // Process immediately - _processQueue internally respects mode constraints
    // and schedules appropriately if events can't start yet
    // FutureOr cannot be awaited
    // ignore: discarded_futures
    _processQueue();
  }

  /// Clears all pending events from the queue.
  ///
  /// [reason] Optional reason for clearing events, which will be passed to
  /// cancelled events.
  ///
  /// Any pending throttle/rate-limit timers are cancelled.
  void clearEvents([Object? reason]) {
    // Cancel any pending throttle/rate-limit timer
    _rateLimitTimer?.cancel();
    _rateLimitTimer = null;

    for (final completer in _queue) {
      completer.cancel(reason ?? 'Event manager cleared', this);
    }
    _queue.clear();
    _isPaused = false;
  }

  /// Whether the event manager is initialized.
  bool get isInitialized => true;

  /// Whether there are any events in the queue.
  bool get hasEvents => _queue.isNotEmpty;

  /// Whether event processing is currently paused.
  bool get isPaused => _isPaused;

  /// The number of events currently in the queue.
  int get queueLength => _queue.length;

  /// An iterable of all events currently in the queue.
  ///
  /// Events are returned in the order they will be processed.
  Iterable<BaseEvent<T>> get pendingEvents => _queue.map((e) => e._event);

  /// Disposes of the event manager and its resources.
  ///
  /// Clears all pending events and optionally disposes the logger if it was
  /// created internally.
  @override
  void dispose() {
    // Cancel throttle/rate-limit timer
    _rateLimitTimer?.cancel();
    _rateLimitTimer = null;

    // Cancel all stream subscriptions
    for (final subscription in _streamSubscriptions) {
      unawaited(subscription.cancel());
    }
    _streamSubscriptions.clear();

    clearEvents('Event manager disposed');
    // Remove all token listeners
    for (final token in _tokenRefCounts.keys.toList()) {
      token.listener = null;
    }
    _tokenRefCounts.clear();
    if (_disposeLogger) logger?.dispose();
    super.dispose();
  }
}

/// Wraps an event for queue processing with lifecycle management.
///
/// Handles the full event lifecycle: queue → run → complete/error/cancel.
/// Optimized to keep synchronous events synchronous (no Future overhead).
class _QueuedEvent<T, E extends BaseEvent<T>> {
  _QueuedEvent({
    required E event,
    this.onDone,
    this.onError,
  }) : _event = event {
    if (!event.canRetry) {
      _isTerminated = true;
    } else if (event._stateController.isTerminal) {
      // Reset state for retriable events so they can be reprocessed.
      // canRetry is true for completed/error events and cancelled with
      // retriable: true. Non-retriable events are already handled above.
      event._stateController._value = null;
    }
    event._stateController.addListener(_onStateChange);
  }

  final E _event;
  final OnDone<T, E>? onDone;
  final OnError<T>? onError;

  EventManager<T>? _manager;
  Completer<Object?>? _completer;
  Object? _result;
  bool _isTerminated = false;
  int _retryAttempt = 0;

  bool get isTerminated => _isTerminated || (_completer?.isCompleted ?? false);
  bool get isPaused => _event.isPaused;

  // ==================== State Management ====================

  void _setState(EventState state) {
    _event._stateController.value = state;
    if (EventManager._isDebug) _event.addProperty(state.name, state);
  }

  // ==================== External State Changes ====================

  void _onStateChange(EventState? state) {
    if (isTerminated) return;
    switch (state) {
      case EventQueue():
        // Event was resumed from paused state - restart queue processing
        _manager?._onEventResumed();
      default:
        // EventCancel is handled by _checkCancellation when the event
        // is about to run, ensuring consistent termination flow.
        break;
    }
  }

  // ==================== Termination ====================

  void _terminate(EventManager<T>? manager, {EventState? state}) {
    if (_isTerminated) return;
    _isTerminated = true;
    _event._stateController.removeListener(_onStateChange);
    manager?._unregisterToken(_event.token);
    if (state != null) _setState(state);
    _completer?.complete(_result);
  }

  /// Checks for cancellation and terminates if cancelled.
  /// Returns true if event should be skipped.
  bool _checkCancellation(EventManager<T> manager) {
    if (isTerminated) return true;

    // Token cancellation (lazy propagation)
    if (_event._token?.cancelData case final cancel?) {
      _terminate(
        manager,
        state: EventState.cancel(
          reason: cancel.reason,
          retriable: cancel.retriable,
        ),
      );
      return true;
    }

    // Direct event cancellation
    if (_event._stateController.isCancelled) {
      _terminate(manager);
      return true;
    }

    return false;
  }

  // ==================== Queue Operations ====================

  bool addTo(_EventQueue<T> queue, EventManager<T> manager) {
    if (_checkCancellation(manager)) return false;
    _manager = manager;
    manager.logger?.addEvent(_event);
    _setState(EventState.queue());
    _insertByPriority(queue);
    return true;
  }

  /// Inserts this event into the queue based on priority.
  ///
  /// Higher priority events are placed earlier in the queue.
  /// Events with equal priority maintain FIFO ordering.
  void _insertByPriority(_EventQueue<T> queue) {
    final priority = _event.priority;

    // Fast path: empty queue or lowest/equal priority - add at end
    if (queue.isEmpty || queue.last._event.priority >= priority) {
      queue.add(this);
      return;
    }

    // Fast path: highest priority - add at front
    if (queue.first._event.priority < priority) {
      queue.addFirst(this);
      return;
    }

    // Find insertion point: first element with lower priority
    // Convert to list for indexed access, then rebuild queue
    final list = queue.toList();
    var insertIndex = list.length;
    for (var i = 0; i < list.length; i++) {
      if (list[i]._event.priority < priority) {
        insertIndex = i;
        break;
      }
    }
    list.insert(insertIndex, this);

    // Rebuild queue
    queue
      ..clear()
      ..addAll(list);
  }

  // ==================== Execution ====================

  FutureOr<Object?> run(EventManager<T> manager) {
    if (_checkCancellation(manager)) return null;
    _setState(EventState.start());

    if (_event case final UndoableEvent<T> undoableEvent) {
      undoableEvent.captureState(manager);
    }

    try {
      final action = _event.buildAction(manager);
      if (action is Future<Object?>) {
        return _runAsync(action, manager);
      }
      // Sync path - no Future overhead
      _result = action;
      _complete(action, manager);
      return action;
    } on Object catch (error, stackTrace) {
      _completeError(error, stackTrace, manager);
      return null;
    }
  }

  Future<Object?> _runAsync(
    Future<Object?> future,
    EventManager<T> manager,
  ) async {
    try {
      final timeout = _event.timeout;
      final data =
          timeout != null ? await future.timeout(timeout) : await future;
      _complete(data, manager);
      return data;
    } on TimeoutException {
      _terminate(
        manager,
        state: EventState.cancel(reason: 'Event timed out'),
      );
      return null;
    } on Object catch (error, stackTrace) {
      _completeError(error, stackTrace, manager);
      return null;
    }
  }

  // ==================== Completion ====================

  void _complete(Object? data, EventManager<T> manager) {
    if (_checkCancellation(manager)) return;

    if (_event is UndoableEvent<T> && manager.undoManager != null) {
      manager.undoManager!.record(_event as UndoableEvent<T>);
    }

    _result = data;
    _terminate(manager, state: EventState.complete(data: data));
    onDone?.call(_event, data);
  }

  void _completeError(
    Object error,
    StackTrace stackTrace,
    EventManager<T> manager,
  ) {
    if (_checkCancellation(manager)) return;

    final baseError = error is BaseError
        ? error
        : _event.buildError(error, stackTrace, manager);

    // Check for automatic retry
    final policy = _event.retryPolicy;
    if (policy != null && policy.shouldRetry(_retryAttempt, error)) {
      _scheduleRetry(policy, manager);
      return;
    }

    _terminate(manager, state: EventState.error(baseError));
    onError?.call(baseError);
  }

  void _scheduleRetry(RetryPolicy policy, EventManager<T> manager) {
    final attempt = _retryAttempt;
    final delay = policy.getDelay(attempt);
    _retryAttempt++;

    // Set state to indicate retry is pending
    _setState(EventState.retry(attempt: attempt + 1, delay: delay));

    unawaited(
      Future<void>.delayed(delay, () async {
        if (_checkCancellation(manager)) return;
        // Re-run the event
        await run(manager);
      }),
    );
  }

  void cancel(
    Object? reason,
    EventManager<T> manager, {
    bool retriable = true,
  }) {
    _terminate(
      manager,
      state: EventState.cancel(
        reason: reason ?? 'Event cancelled',
        retriable: retriable,
      ),
    );
  }

  // ==================== Result Access ====================

  /// Returns sync result immediately if available, otherwise a Future.
  ///
  /// This optimization ensures synchronous events remain synchronous
  /// without unnecessary Future wrapper overhead.
  FutureOr<Object?> get result {
    if (_isTerminated && _completer == null) return _result;
    _completer ??= Completer<Object?>();
    return _completer!.future;
  }
}

// ======================= Base Error ==========================

/// {@template mz_core.BaseError}
/// Base class for event errors with retry capability.
///
/// Wraps an [AsyncError] and optionally provides a retry callback that
/// allows the failed operation to be retried.
///
/// ## Handling Errors
///
/// {@tool snippet}
/// Handle errors with optional retry:
///
/// ```dart
/// manager.addEventToQueue(
///   myEvent,
///   onError: (error) {
///     print('Failed: ${error.error}');
///     print('Stack: ${error.stackTrace}');
///
///     // Retry if callback is available
///     if (error.onRetry != null) {
///       error.onRetry!();
///     }
///   },
/// );
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [BatchError] - Error containing multiple failed batch events.
/// * [BaseEvent.buildError] - Customize error creation in events.
/// {@endtemplate}
class BaseError extends Error {
  /// Creates a new error with the underlying async error and optional
  /// retry callback.
  BaseError({
    required this.asyncError,
    this.onRetry,
    this.debugKey,
  });

  /// The underlying asynchronous error.
  final AsyncError asyncError;

  /// Optional callback to retry the failed operation.
  final RetryCallback? onRetry;

  /// Optional key for debugging purposes.
  final String? debugKey;

  /// The underlying error object.
  Object get error => asyncError.error;

  @override
  StackTrace get stackTrace => asyncError.stackTrace;

  @override
  String toString() => '${asyncError.error}';
}

/// {@template mz_core.BatchError}
/// Exception thrown when a [BatchEvent] encounters one or more errors
/// during processing.
///
/// This exception contains information about which events failed and why. When
/// [BatchEvent.eagerError] is true, this exception will contain the first
/// failed event and any remaining unprocessed events. When false, it will
/// contain all failed events after attempting to process the entire batch.
///
/// ## Accessing Failed Events
///
/// {@tool snippet}
/// Handle batch errors and access failed events:
///
/// ```dart
/// manager.addEventToQueue(
///   BatchEvent(events, eagerError: false),
///   onError: (error) {
///     if (error is BatchError) {
///       // Access all errors
///       for (final err in error.errors) {
///         print('Error: $err');
///       }
///
///       // Access failed events
///       for (final event in error.events) {
///         print('Failed event: $event');
///       }
///
///       // Retry all failed events
///       error.onRetry?.call();
///     }
///   },
/// );
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [BatchEvent] - Event that processes multiple sub-events.
/// * [BaseError] - Base class for event errors.
/// {@endtemplate}
class BatchError<T, E extends BaseEvent<T>> extends BaseError {
  /// Creates a new batch event exception.
  ///
  /// [pendingEvents] contains the events that failed or weren't processed.
  BatchError({
    required this.pendingEvents,
    super.onRetry,
    super.debugKey,
  }) : super(asyncError: AsyncError('', null));

  /// The collection of events that either failed or weren't processed.
  ///
  /// When [BatchEvent.eagerError] is true, this includes:
  /// * The event that caused the failure
  /// * Any remaining events that weren't processed
  ///
  /// When [BatchEvent.eagerError] is false, this includes:
  /// * All events that failed during processing
  final Iterable<PendingEvent<T, E>> pendingEvents;

  /// All errors from the failed events.
  Iterable<BaseError> get errors => pendingEvents.map((e) => e.error).nonNulls;

  /// All events that failed or weren't processed.
  Iterable<E> get events => pendingEvents.map((e) => e.event);

  @override
  String toString() => errors.join('\n');
}

// ======================= Event State ==========================

/// {@template mz_core.EventState}
/// Sealed class representing various states an event can be in.
///
/// Events progress through these states:
/// 1. [EventQueue] - Event is queued waiting to be processed
/// 2. [EventStart] - Event is currently executing
/// 3. Terminal states:
///    - [EventComplete] - Event finished successfully
///    - [EventError] - Event failed with an error
///    - [EventCancel] - Event was cancelled
///
/// Non-terminal states can also include:
/// - [EventPause] - Event is paused and will be skipped
/// - [EventProgress] - Event is reporting progress
/// - [EventRetry] - Event failed and is pending retry
///
/// ## Pattern Matching
///
/// {@tool snippet}
/// Use pattern matching to handle states:
///
/// ```dart
/// switch (event.state) {
///   case EventComplete(:final data):
///     print('Success: $data');
///   case EventError(:final error):
///     print('Failed: $error');
///   case EventCancel(:final reason):
///     print('Cancelled: $reason');
///   case EventProgress(:final value, :final message):
///     print('Progress: ${value * 100}% - $message');
///   default:
///     print('State: ${event.state?.name}');
/// }
/// ```
/// {@end-tool}
///
/// ## Using the map Method
///
/// {@tool snippet}
/// Use map for functional state handling:
///
/// ```dart
/// event.state?.map(
///   onQueue: () => print('Queued'),
///   onStart: () => print('Started'),
///   onDone: (data) => print('Done: $data'),
///   onError: (error) => print('Error: $error'),
///   onCancel: (reason) => print('Cancelled: $reason'),
///   onProgress: (value, msg) => print('Progress: $value'),
///   onRetry: (attempt, delay) => print('Retry #$attempt in $delay'),
/// );
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [BaseEvent] - Events that have state.
/// * [EventController] - Manages event state transitions.
/// {@endtemplate}
sealed class EventState {
  /// Creates a new event state with the current timestamp (in debug mode).
  EventState()
      : timeStamp = EventManager._isDebug ? DateTime.timestamp() : null;

  /// Const constructor for singleton instances (release mode).
  const EventState._() : timeStamp = null;

  /// Creates a state indicating the event is queued.
  /// Uses singleton in release mode for better performance.
  factory EventState.queue() => EventQueue.instance;

  /// Creates a state indicating the event is paused.
  /// Uses singleton in release mode for better performance.
  factory EventState.pause() => EventPause.instance;

  /// Creates a state indicating the event is cancelled.
  ///
  /// [reason] describes why the event was cancelled.
  /// [retriable] indicates whether the event can be retried (default: true).
  factory EventState.cancel({Object? reason, bool retriable}) = EventCancel;

  /// Creates a state indicating the event has started.
  /// Uses singleton in release mode for better performance.
  factory EventState.start() => EventStart.instance;

  /// Creates a state indicating the event has completed.
  factory EventState.complete({bool? refreshed, dynamic data}) = EventComplete;

  /// Creates a state indicating the event has failed.
  factory EventState.error(BaseError error) = EventError;

  /// Creates a state indicating the event is pending retry.
  factory EventState.retry({required int attempt, required Duration delay}) =
      EventRetry;

  /// Creates a state indicating progress during event execution.
  ///
  /// [value] is the progress from 0.0 to 1.0.
  /// [message] is an optional description of current progress.
  factory EventState.progress({required double value, String? message}) =
      EventProgress;

  /// Maps this state to a value using the provided callbacks.
  R? map<R>({
    R? Function()? onQueue,
    R? Function()? onPause,
    R? Function(Object? reason)? onCancel,
    R? Function()? onStart,
    R? Function(double value, String? message)? onProgress,
    R? Function(dynamic data)? onDone,
    R? Function(BaseError error)? onError,
    R? Function(int attempt, Duration delay)? onRetry,
  }) {
    return switch (this) {
      EventQueue() => onQueue?.call(),
      EventPause() => onPause?.call(),
      EventCancel(:final reason) => onCancel?.call(reason),
      EventStart() => onStart?.call(),
      EventProgress(:final value, :final message) =>
        onProgress?.call(value, message),
      EventComplete(:final data) => onDone?.call(data),
      EventError(:final error) => onError?.call(error),
      EventRetry(:final attempt, :final delay) => onRetry?.call(attempt, delay),
    };
  }

  /// Whether the event is in the queue waiting to be processed.
  bool get isInQueue => this is EventQueue;

  /// Whether the event is paused.
  bool get isPaused => this is EventPause;

  /// Whether the event has been cancelled.
  bool get isCancelled => this is EventCancel;

  /// Whether the event is currently running.
  bool get isRunning => this is EventStart;

  /// Whether the event has completed successfully.
  bool get isCompleted => this is EventComplete;

  /// Whether the event has errored.
  bool get hasError => this is EventError;

  /// Whether the event is pending retry after an error.
  bool get isRetrying => this is EventRetry;

  /// Whether the event is reporting progress.
  bool get hasProgress => this is EventProgress;

  /// Whether this state is terminal (completed, cancelled, or errored).
  bool get isTerminal => isCompleted || isCancelled || hasError;

  /// The key identifier for this state.
  String get name => switch (this) {
        EventQueue() => EventQueue.key,
        EventPause() => EventPause.key,
        EventCancel() => EventCancel.key,
        EventStart() => EventStart.key,
        EventProgress() => EventProgress.key,
        EventComplete() => EventComplete.key,
        EventError() => EventError.key,
        EventRetry() => EventRetry.key,
      };

  /// The timestamp when this state was created.
  ///
  /// Only set in debug mode for performance. In release mode, this is null.
  final DateTime? timeStamp;
}

/// Event is in queue waiting to be processed.
class EventQueue extends EventState {
  /// Creates a new queue state.
  EventQueue() : super();

  /// Private const constructor for singleton instance.
  const EventQueue._() : super._();

  /// Singleton instance for release mode (no timestamp needed).
  static const EventQueue _instance = EventQueue._();

  /// Returns singleton in release mode, new instance in debug mode.
  // ignore: prefer_constructors_over_static_methods
  static EventQueue get instance =>
      EventManager._isDebug ? EventQueue() : _instance;

  /// Key used for state tracking.
  static const String key = 'CVEQueue';
}

/// Event is paused and will be skipped during processing.
///
/// Paused events remain in the queue but are not processed until resumed.
/// This is NOT a terminal state - events can transition back to [EventQueue]
/// when resumed.
class EventPause extends EventState {
  /// Creates a new pause state.
  EventPause() : super();

  /// Private const constructor for singleton instance.
  const EventPause._() : super._();

  /// Singleton instance for release mode (no timestamp needed).
  static const EventPause _instance = EventPause._();

  /// Returns singleton in release mode, new instance in debug mode.
  // ignore: prefer_constructors_over_static_methods
  static EventPause get instance =>
      EventManager._isDebug ? EventPause() : _instance;

  /// Key used for state tracking.
  static const String key = 'CVEPause';
}

/// Event is cancelled.
///
/// By default, cancelled events are retriable ([retriable] = true).
/// Set [retriable] to `false` to permanently prevent the event from
/// being re-added to the queue.
class EventCancel extends EventState {
  /// Creates a cancelled event state.
  ///
  /// [reason] describes why the event was cancelled.
  /// [retriable] indicates whether the event can be retried (default: true).
  EventCancel({this.reason, this.retriable = true});

  /// Key used for state tracking.
  static const String key = 'CVECancel';

  /// The reason for cancellation.
  final Object? reason;

  /// Whether this event can be retried after cancellation.
  ///
  /// Defaults to `true`, meaning events are retriable unless explicitly
  /// marked as non-retriable.
  final bool retriable;

  @override
  String toString() => '$reason';
}

/// Event is executing
class EventStart extends EventState {
  /// Creates a new start state.
  EventStart() : super();

  /// Private const constructor for singleton instance.
  const EventStart._() : super._();

  /// Singleton instance for release mode (no timestamp needed).
  static const EventStart _instance = EventStart._();

  /// Returns singleton in release mode, new instance in debug mode.
  // ignore: prefer_constructors_over_static_methods
  static EventStart get instance =>
      EventManager._isDebug ? EventStart() : _instance;

  /// Key used for state tracking.
  static const String key = 'CVEStart';
}

/// Event is completed successfully.
///
/// This is a terminal state - once an event completes, it cannot transition
/// to any other state.
class EventComplete extends EventState {
  /// Creates a completed event state.
  ///
  /// [refreshed] indicates if this completion refreshed existing data.
  /// [data] contains the result of the event execution.
  EventComplete({this.refreshed, this.data});

  /// Key used for state tracking.
  static const String key = 'CVEComplete';

  /// Whether the event refreshed existing data.
  final bool? refreshed;

  /// The result data from event execution.
  final dynamic data;
}

/// Error occurred while executing the event.
///
/// This is a terminal state unless the event is retriable.
class EventError extends EventState {
  /// Creates an error state with the associated error.
  EventError(this.error);

  /// Key used for state tracking.
  static const String key = 'CVEError';

  /// The error that occurred during event execution.
  final BaseError error;

  @override
  String toString() => '$error';
}

/// Event is pending automatic retry after an error.
///
/// This state indicates that an event has failed but will be retried
/// automatically according to its [RetryPolicy].
class EventRetry extends EventState {
  /// Creates a retry state with the attempt number and delay until next retry.
  EventRetry({required this.attempt, required this.delay});

  /// Key used for state tracking.
  static const String key = 'CVERetry';

  /// The retry attempt number (1-based).
  final int attempt;

  /// The delay before the next retry attempt.
  final Duration delay;

  @override
  String toString() => 'Retry #$attempt in ${delay.inMilliseconds}ms';
}

/// Event is reporting progress during execution.
///
/// Use [BaseEvent.reportProgress] to emit this state during long-running
/// operations. Listeners can track progress via [BaseEvent.listen] or
/// [EventState.map].
///
/// ```dart
/// class UploadEvent extends BaseEvent<String> {
///   @override
///   Future<String> buildAction(EventManager<AppState> manager) async {
///     for (var i = 0; i <= 100; i += 10) {
///       await uploadChunk(i);
///       reportProgress(i / 100, message: 'Uploading: $i%');
///     }
///     return 'Upload complete';
///   }
/// }
/// ```
class EventProgress extends EventState {
  /// Creates a progress state.
  ///
  /// [value] should be between 0.0 (not started) and 1.0 (complete).
  /// [message] is an optional human-readable progress description.
  EventProgress({required this.value, this.message})
      : assert(value >= 0.0 && value <= 1.0, 'Progress must be 0.0-1.0');

  /// Key used for state tracking.
  static const String key = 'CVEProgress';

  /// Progress value from 0.0 to 1.0.
  final double value;

  /// Optional progress message.
  final String? message;

  /// Progress as percentage (0-100).
  int get percent => (value * 100).round();

  @override
  String toString() => message ?? '$percent%';
}

// +++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// ======================= LOGGER ==========================
// +++++++++++++++++++++++++++++++++++++++++++++++++++++++++

/// {@template mz_core.PropertyStore}
/// A mixin for storing arbitrary key-value properties on events.
///
/// This allows attaching metadata to events that can be accessed during
/// processing or logging without modifying the event's type signature.
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Attach metadata to events:
///
/// ```dart
/// class MyEvent extends BaseEvent<AppState> {
///   @override
///   FutureOr<void> buildAction(EventManager<AppState> manager) {
///     // Store metadata during execution
///     addProperty('startTime', DateTime.now());
///     addProperty('userId', currentUser.id);
///
///     // ... perform action ...
///
///     addProperty('endTime', DateTime.now());
///   }
/// }
///
/// // Access properties later
/// final startTime = event.getProperty('startTime') as DateTime;
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [BaseEvent] - Uses PropertyStore for metadata attachment.
/// * [EventLogger] - Can access event properties during logging.
/// {@endtemplate}
mixin PropertyStore {
  final _properties = <String, dynamic>{};

  /// Adds or updates a property with the given key and value.
  void addProperty(String key, dynamic value) {
    _properties[key] = value;
  }

  /// Removes a property by key.
  void removeProperty(String key) => _properties.remove(key);

  /// Removes multiple properties by their keys.
  void removeProperties(Iterable<String> keys) =>
      keys.forEach(_properties.remove);

  /// Gets a property value by key, or null if not found.
  dynamic getProperty(String key) => _properties[key];

  /// Gets all property values.
  Iterable<dynamic> getProperties() => _properties.values;

  /// Clears all stored properties.
  void clearProperties() {
    _properties.clear();
  }
}

/// {@template mz_core.EventLogger}
/// Logger for tracking event lifecycle with configurable history size.
///
/// Provides colored console output and maintains a bounded event history
/// to prevent memory leaks in long-running applications.
///
/// ## Basic Usage
///
/// {@tool snippet}
/// Create an event logger with the EventManager:
///
/// ```dart
/// final logger = EventLogger<AppState>(
///   debugLabel: 'app-events',
///   maxHistorySize: 100,
/// );
/// final manager = EventManager<AppState>(logger: logger);
/// ```
/// {@end-tool}
///
/// ## Custom Output
///
/// {@tool snippet}
/// Send logs to a third-party service:
///
/// ```dart
/// final logger = EventLogger<AppState>(
///   output: (message) {
///     // Send to Sentry, Crashlytics, or Instabug
///     Sentry.addBreadcrumb(Breadcrumb(message: message));
///   },
/// );
/// ```
/// {@end-tool}
///
/// ## Toggling Logging
///
/// {@tool snippet}
/// Enable/disable logging at runtime:
///
/// ```dart
/// // Disable logging in release mode
/// logger.isEnabled = kDebugMode;
///
/// // Toggle based on user preference
/// logger.isEnabled = userSettings.verboseLogging;
/// ```
/// {@end-tool}
///
/// ## Accessing Event History
///
/// {@tool snippet}
/// Access logged events:
///
/// ```dart
/// // Get all logged events
/// final events = logger.events;
/// print('Logged ${logger.eventCount} events');
///
/// // Clear history
/// logger.clear();
/// ```
/// {@end-tool}
///
/// See also:
///
/// * [SimpleLogger] - Base logger class with filtering support.
/// * [EventManager] - Uses EventLogger to track event lifecycle.
/// * [Controller] - Provides listener notification support.
/// {@endtemplate}
class EventLogger<T> extends SimpleLogger with Controller {
  /// Creates an event logger with optional history size limit.
  ///
  /// [maxHistorySize] limits the number of events kept in memory.
  /// When null (default), history grows unbounded.
  /// Set to a reasonable value (e.g., 100-500) for long-running apps.
  EventLogger({
    super.debugLabel,
    super.output,
    super.filter,
    super.observer,
    this.maxHistorySize,
  });

  /// Maximum number of events to keep in history.
  ///
  /// When set, older events are automatically removed when limit is reached.
  /// This prevents unbounded memory growth in long-running applications.
  final int? maxHistorySize;

  static const String _groupKey = 'groupId';
  static const _ansiEsc = '\x1B[';

  final _events = <BaseEvent<T>>[];

  /// The events currently in history.
  ///
  /// May be truncated based on [maxHistorySize].
  Iterable<BaseEvent<T>> get events => _events;

  /// Number of events currently in history.
  int get eventCount => _events.length;

  /// Adds an event to the logger and starts tracking its lifecycle.
  ///
  /// Respects [isEnabled] - if disabled, no processing occurs.
  void addEvent(BaseEvent<T> event) {
    guard(() {
      // Maintain circular buffer if maxHistorySize is set
      if (maxHistorySize != null && _events.length >= maxHistorySize!) {
        _events.removeAt(0);
      }
      _events.add(event);
      event.listen(
        onQueue: () => _logQueue(event),
        onStart: () => _logStart(event),
        onDone: (data) => _logDone(event, data),
        onError: (error) => _logError(event, error),
        onCancel: (reason) => _logCancel(event, reason),
      );
    });
  }

  // Event-specific logging methods
  EventState? _statusOf(BaseEvent<T> event, String key) =>
      event.getProperty(key) as EventState?;

  DateTime _timeStampFor(BaseEvent<T> event, String key) {
    return _statusOf(event, key)?.timeStamp ?? DateTime.timestamp();
  }

  static int _groupCounter = 0;

  LogGroup _groupFor(BaseEvent<T> event) {
    if (event.getProperty(_groupKey) case final LogGroup group) return group;
    final group = LogGroup(
      id: '${event.hashCode}_${++_groupCounter}',
      title: event.name,
      description: event.description,
    );
    event.addProperty(_groupKey, group);
    startGroup(group); // Register group with SimpleLogger
    return group;
  }

  void _logQueue(BaseEvent<T> event) {
    final entry = LogEntry(
      id: event.id,
      name: 'Queued',
      message: '$event',
      level: LogLevel.info,
      timestamp: _timeStampFor(event, EventQueue.key),
      color: '${_ansiEsc}33m',
    );
    logEntry(entry, groupId: _groupFor(event).id);
  }

  void _logStart(BaseEvent<T> event) {
    final entry = LogEntry(
      id: event.id,
      name: 'Started',
      level: LogLevel.info,
      timestamp: _timeStampFor(event, EventStart.key),
      color: '${_ansiEsc}36m',
    );
    logEntry(entry, groupId: _groupFor(event).id);
  }

  void _logDone(BaseEvent<T> event, Object? data) {
    final start = _timeStampFor(event, EventStart.key);
    final end = _timeStampFor(event, EventComplete.key);
    final entry = LogEntry(
      id: event.id,
      name: 'Completed',
      message: data != null ? '$data' : null,
      level: LogLevel.info,
      timestamp: end,
      duration: end.difference(start),
      metadata: {if (data != null) 'data': data},
      color: '${_ansiEsc}32m',
    );
    final group = _groupFor(event);
    logEntry(entry, groupId: group.id);
    completeGroup(group.id);
  }

  void _logError(BaseEvent<T> event, BaseError error) {
    final start = _timeStampFor(event, EventStart.key);
    final end = _timeStampFor(event, EventError.key);
    final entry = LogEntry(
      id: event.id,
      name: 'Error',
      message: 'Error: ${error.error}',
      level: LogLevel.error,
      timestamp: end,
      duration: end.difference(start),
      metadata: {'error': error},
      color: '${_ansiEsc}31m',
    );
    final group = _groupFor(event);
    logEntry(entry, groupId: group.id);
    completeGroup(group.id);
  }

  void _logCancel(BaseEvent<T> event, Object? reason) {
    final start = _timeStampFor(event, EventStart.key);
    final end = _timeStampFor(event, EventCancel.key);
    final entry = LogEntry(
      id: event.id,
      name: 'Cancelled',
      message: reason != null ? '$reason' : 'Event cancelled',
      level: LogLevel.warning,
      timestamp: end,
      duration: end.difference(start),
      metadata: {'reason': reason},
      color: '${_ansiEsc}33m',
    );
    final group = _groupFor(event);
    logEntry(entry, groupId: group.id);
    completeGroup(group.id);
  }

  @override
  bool logEntry(LogEntry entry, {String? groupId}) {
    final isLogged = super.logEntry(entry, groupId: groupId);
    if (isLogged) notifyListeners(debugKey: entry.name, value: entry);
    return isLogged;
  }

  @override
  bool completeGroup(String groupId) {
    final isCompleted = super.completeGroup(groupId);
    if (isCompleted) notifyListeners(debugKey: groupId);
    return isCompleted;
  }

  /// Clears all logged events and notifies listeners.
  void clear() {
    if (_events.isEmpty) return;
    _events.clear();
    notifyListeners();
  }
}

extension _BaseEventX<T> on BaseEvent<T> {
  String get id => '$runtimeType#$hashCode';
}
