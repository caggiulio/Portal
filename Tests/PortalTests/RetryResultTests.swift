import Testing
@testable import Portal

@Suite("RetryResult")
struct RetryResultTests {
    @Test func retryCase() {
        let result = RetryResult.retry
        if case .retry = result { } else { Issue.record("expected .retry") }
    }

    @Test func doNotRetryCase() {
        let result = RetryResult.doNotRetry
        if case .doNotRetry = result { } else { Issue.record("expected .doNotRetry") }
    }
}
