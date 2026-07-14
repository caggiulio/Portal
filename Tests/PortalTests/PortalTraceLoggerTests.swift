import Testing
@testable import Portal

@Suite("PortalTraceLoggerLevel")
struct PortalTraceLoggerLevelTests {
    @Test func levelsExist() {
        let levels: [PortalTraceLoggerLevel] = [.none, .debug, .release]
        #expect(levels.count == 3)
    }

    @Test func noneNotEqualDebug() {
        #expect(PortalTraceLoggerLevel.none != .debug)
    }

    @Test func debugNotEqualRelease() {
        #expect(PortalTraceLoggerLevel.debug != .release)
    }
}
