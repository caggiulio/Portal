import Testing
import Foundation
@testable import Portal

final class IntegrationStubURLProtocol: URLProtocol {
    private static var _statusCode = 200
    private static var _data = Data()

    static func stub(statusCode: Int, data: Data) {
        _statusCode = statusCode
        _data = data
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url ?? URL(string: "https://api.example.com")!
        let response = HTTPURLResponse(url: url, statusCode: Self._statusCode, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self._data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

@Suite("Portal + URLSessionTransport integration", .serialized)
struct PortalURLSessionIntegrationTests {
    func makePortal(statusCode: Int, responseData: Data) -> Portal {
        IntegrationStubURLProtocol.stub(statusCode: statusCode, data: responseData)
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [IntegrationStubURLProtocol.self]
        let transport = URLSessionTransport(session: URLSession(configuration: config))
        return Portal(baseURL: "https://api.example.com", transport: transport)
    }

    @Test func multipartSend() async throws {
        let portal = makePortal(statusCode: 200, responseData: try! JSONEncoder().encode(Response(id: 77)))
        let media = PortalMedia(data: Data([0x01, 0x02]), key: "file", filename: "img.jpg", mimeType: "image/jpeg")
        let response: Response = try await portal.send(
            request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil)),
            medias: [media],
            boundary: "boundary123"
        )
        #expect(response.id == 77)
    }

    @Test func multipartWithBodyParams() async throws {
        let portal = makePortal(statusCode: 200, responseData: try! JSONEncoder().encode(Response(id: 88)))
        struct Params: Encodable { let name: String }
        let media = PortalMedia(data: Data([0xFF]), key: "doc", filename: "doc.pdf", mimeType: "application/pdf")
        let response: Response = try await portal.send(
            request: PortalRequest(method: .post, path: Path(url: "/upload", query: nil), body: Body(data: Params(name: "test"), encoding: .json)),
            medias: [media],
            boundary: "b42"
        )
        #expect(response.id == 88)
    }
}
