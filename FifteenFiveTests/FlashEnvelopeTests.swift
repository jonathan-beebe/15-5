#if os(macOS)
import Testing
@testable import FifteenFive

struct FlashEnvelopeTests {
    private let dipMiddle = FlashEnvelope.dipStart + FlashEnvelope.dipDuration / 2
    private let dipEnd = FlashEnvelope.dipStart + FlashEnvelope.dipDuration

    @Test(arguments: [false, true]) func invisibleAtBothEnds(pulsing: Bool) {
        #expect(FlashEnvelope.opacity(at: 0, pulsing: pulsing) == 0)
        #expect(FlashEnvelope.opacity(at: FlashEnvelope.duration, pulsing: pulsing) == 0)
    }

    @Test(arguments: [false, true]) func invisibleOutsideTheFlash(pulsing: Bool) {
        #expect(FlashEnvelope.opacity(at: -1, pulsing: pulsing) == 0)
        #expect(FlashEnvelope.opacity(at: FlashEnvelope.duration + 1, pulsing: pulsing) == 0)
    }

    @Test func reachesPeakBeforeAndAfterTheDip() {
        #expect(FlashEnvelope.opacity(at: FlashEnvelope.dipStart, pulsing: true) == FlashEnvelope.peakOpacity)
        #expect(FlashEnvelope.opacity(at: dipEnd, pulsing: true) == FlashEnvelope.peakOpacity)
    }

    @Test func dipsOnceAtItsMidpoint() {
        let expected = FlashEnvelope.peakOpacity * (1 - FlashEnvelope.dipDepth)
        let bottom = FlashEnvelope.opacity(at: dipMiddle, pulsing: true)
        #expect(abs(bottom - expected) < 0.0001)
        #expect(FlashEnvelope.opacity(at: dipMiddle - 0.25, pulsing: true) > bottom)
        #expect(FlashEnvelope.opacity(at: dipMiddle + 0.25, pulsing: true) > bottom)
    }

    @Test func staysAtPeakThroughTheDipWithoutPulsing() {
        #expect(FlashEnvelope.opacity(at: dipMiddle, pulsing: false) == FlashEnvelope.peakOpacity)
    }

    @Test func easesInAndOut() {
        #expect(FlashEnvelope.opacity(at: 0.2, pulsing: true) < FlashEnvelope.opacity(at: 0.5, pulsing: true))
        #expect(FlashEnvelope.opacity(at: 3.2, pulsing: true) > FlashEnvelope.opacity(at: 3.6, pulsing: true))
    }
}
#endif
