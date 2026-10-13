import Foundation

@MainActor
private final class CallbackBox {
    var callback: (@Sendable (Bool) -> Void)?
    var started = false
    private var waiter: CheckedContinuation<Void, Never>?

    func markStarted() {
        started = true
        waiter?.resume()
        waiter = nil
    }

    func waitUntilStarted() async {
        if started { return }
        await withCheckedContinuation { waiter = $0 }
    }
}

@main
struct CheckVoicePermissionGate {
    @MainActor
    static func main() async {
        let success = VoicePermissionGate()
        let granted = try! await success.wait(timeout: .seconds(1)) { callback in
            callback(true)
            callback(false)
        }
        assert(granted)
        assert(success.completionCount == 1)

        let timedOut = VoicePermissionGate()
        let late = CallbackBox()
        do {
            _ = try await timedOut.wait(timeout: .milliseconds(20)) { callback in
                late.callback = callback
                late.markStarted()
            }
            assertionFailure("permission request should time out")
        } catch is VoicePermissionTimedOut {
            assert(timedOut.completionCount == 1)
        } catch {
            assertionFailure("unexpected timeout result: \(error)")
        }
        late.callback?(true)
        await Task.yield()
        assert(timedOut.completionCount == 1)

        let canceled = VoicePermissionGate()
        let pending = CallbackBox()
        let waiter = Task { @MainActor in
            (try? await canceled.wait(timeout: .seconds(5)) { callback in
                pending.callback = callback
                pending.markStarted()
            }) ?? false
        }
        await pending.waitUntilStarted()
        waiter.cancel()
        let canceledResult = await waiter.value
        assert(!canceledResult)
        assert(canceled.completionCount == 1)
        pending.callback?(true)
        await Task.yield()
        assert(canceled.completionCount == 1)
    }
}
