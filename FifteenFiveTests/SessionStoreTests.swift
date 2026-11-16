import Foundation
import Testing
@testable import FifteenFive

struct SessionStoreTests {
    private let start = Date(timeIntervalSinceReferenceDate: 1_000)

    /// A suite of its own per call, removed when the body returns, so tests never see each
    /// other's keys or the app's.
    private func withDefaults(_ body: (UserDefaults) throws -> Void) throws {
        let suite = "SessionStoreTests-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(defaults)
    }

    @Test func stoppedByDefault() throws {
        try withDefaults { defaults in
            #expect(SessionStore(defaults: defaults).state == .stopped)
        }
    }

    @Test func runningReadsBack() throws {
        try withDefaults { defaults in
            let store = SessionStore(defaults: defaults)
            store.save(.running(start: start))
            #expect(store.state == .running(start: start))
            #expect(defaults.object(forKey: "startDate") as? Date == start)
        }
    }

    @Test func pausedClearsTheStart() throws {
        try withDefaults { defaults in
            let store = SessionStore(defaults: defaults)
            store.save(.running(start: start))
            store.save(.paused(elapsed: 42))
            #expect(store.state == .paused(elapsed: 42))
            #expect(defaults.object(forKey: "startDate") == nil)
            #expect(defaults.object(forKey: "pausedElapsed") as? Double == 42)
        }
    }

    @Test func runningClearsThePause() throws {
        try withDefaults { defaults in
            let store = SessionStore(defaults: defaults)
            store.save(.paused(elapsed: 42))
            store.save(.running(start: start))
            #expect(store.state == .running(start: start))
            #expect(defaults.object(forKey: "pausedElapsed") == nil)
        }
    }

    @Test func stoppedClearsBoth() throws {
        try withDefaults { defaults in
            let store = SessionStore(defaults: defaults)
            store.save(.running(start: start))
            store.save(.stopped)
            #expect(store.state == .stopped)
            store.save(.paused(elapsed: 42))
            store.save(.stopped)
            #expect(store.state == .stopped)
            #expect(defaults.object(forKey: "startDate") == nil)
            #expect(defaults.object(forKey: "pausedElapsed") == nil)
        }
    }

    @Test func cycleDefaultsToStandardAndRoundTrips() throws {
        try withDefaults { defaults in
            let store = SessionStore(defaults: defaults)
            #expect(store.cycle == .standard)
            let custom = Cycle(focus: 25 * 60, rest: 10 * 60)
            store.save(custom)
            #expect(store.cycle == custom)
            #expect(SavedCycle.load(from: defaults) == custom)
        }
    }

    @Test func migrationMovesEveryKeyIntoAnEmptyStore() throws {
        try withDefaults { source in
            try withDefaults { target in
                let custom = Cycle(focus: 25 * 60, rest: 10 * 60)
                let old = SessionStore(defaults: source)
                old.save(.running(start: start))
                old.save(custom)

                let store = SessionStore(defaults: target)
                store.migrate(from: source)
                #expect(store.state == .running(start: start))
                #expect(store.cycle == custom)
                #expect(old.state == .stopped)
                #expect(old.cycle == .standard)
                #expect(source.object(forKey: "startDate") == nil)
                #expect(source.object(forKey: "pausedElapsed") == nil)
                #expect(source.object(forKey: "focusSeconds") == nil)
                #expect(source.object(forKey: "restSeconds") == nil)
            }
        }
    }

    @Test func migrationMovesAPausedSession() throws {
        try withDefaults { source in
            try withDefaults { target in
                SessionStore(defaults: source).save(.paused(elapsed: 42))
                let store = SessionStore(defaults: target)
                store.migrate(from: source)
                #expect(store.state == .paused(elapsed: 42))
                #expect(source.object(forKey: "pausedElapsed") == nil)
            }
        }
    }

    @Test func migrationLeavesAStoreWithStateAlone() throws {
        try withDefaults { source in
            try withDefaults { target in
                let old = SessionStore(defaults: source)
                old.save(.paused(elapsed: 42))
                let store = SessionStore(defaults: target)
                store.save(.running(start: start))

                store.migrate(from: source)
                #expect(store.state == .running(start: start))
                #expect(old.state == .paused(elapsed: 42))
            }
        }
    }

    @Test func migrationFromItselfDoesNothing() throws {
        try withDefaults { defaults in
            let store = SessionStore(defaults: defaults)
            store.save(.running(start: start))
            store.migrate(from: defaults)
            #expect(store.state == .running(start: start))
        }
    }
}
