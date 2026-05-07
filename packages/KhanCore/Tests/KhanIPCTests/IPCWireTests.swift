import XCTest
@testable import KhanIPC

final class IPCWireTests: XCTestCase {
    func testRoundTripNotify() throws {
        let payload = IPCNotifyPayload(
            title: "hi",
            body: "world",
            displayMode: .fix,
            source: .claudeCode,
            sourceAppId: "claude-code",
            clickAction: .openURL(URL(string: "https://example.com")!),
            broadcast: .allDevices
        )
        let request = IPCRequest(kind: .notify, payload: .notify(payload))
        let data = try IPCEncoding.encoder.encode(request)
        let decoded = try IPCEncoding.decoder.decode(IPCRequest.self, from: data)
        XCTAssertEqual(decoded.id, request.id)
        guard case .notify(let decodedPayload) = decoded.payload else {
            return XCTFail("expected notify payload")
        }
        XCTAssertEqual(decodedPayload.title, "hi")
        XCTAssertEqual(decodedPayload.broadcast, .allDevices)
    }

    func testHMACSignAndVerify() throws {
        let secret = KhanHMAC.generateSecret()
        let payload = IPCNotifyPayload(title: "x")
        let request = IPCRequest(kind: .notify, payload: .notify(payload))
        let signed = try KhanHMAC.sign(request, with: secret)
        XCTAssertNotNil(signed.hmac)
        XCTAssertNoThrow(try KhanHMAC.verify(signed, with: secret))

        var tampered = signed
        tampered = IPCRequest(id: tampered.id, kind: .notify, payload: .notify(IPCNotifyPayload(title: "evil")))
        tampered.hmac = signed.hmac
        XCTAssertThrowsError(try KhanHMAC.verify(tampered, with: secret))
    }

    func testGlob() {
        XCTAssertTrue(Glob.match("*", candidate: "foo"))
        XCTAssertTrue(Glob.match("claude-code", candidate: "claude-code"))
        XCTAssertTrue(Glob.match("deploy.*", candidate: "deploy.staging"))
        XCTAssertFalse(Glob.match("deploy.*", candidate: "release"))
    }
}
