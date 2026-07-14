import Testing
import Foundation
@testable import Portal

// MARK: - URLProtocol stubs

final class StubURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else { return }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class NonHTTPURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let url = request.url ?? URL(string: "https://api.example.com")!
        let response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

// MARK: - Helpers

func makeStubTransport() -> (URLSessionTransport, URLSession) {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [StubURLProtocol.self]
    let session = URLSession(configuration: config)
    return (URLSessionTransport(session: session), session)
}

func stubResponse(_ statusCode: Int, data: Data = Data()) {
    StubURLProtocol.handler = { req in
        let response = HTTPURLResponse(
            url: req.url ?? URL(string: "https://api.example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (response, data)
    }
}

// MARK: - Tests

@Suite("URLSessionTransport", .serialized)
struct URLSessionTransportTests {
    @Test func returnsDataAndStatusCode() async throws {
        let body = "{\"id\":1}".data(using: .utf8)!
        stubResponse(200, data: body)
        let (transport, _) = makeStubTransport()
        let request = PortalRequest(method: .get, path: Path(url: "https://api.example.com/test", query: nil), scheme: nil)
        let (data, code) = try await transport.execute(request)
        #expect(code == 200)
        #expect(data == body)
    }

    @Test func invalidURLThrows() async throws {
        let (transport, _) = makeStubTransport()
        let request = PortalRequest(method: .get, path: Path(url: "https://[invalid", query: nil), scheme: nil)
        await #expect(throws: PortalError.self) {
            _ = try await transport.execute(request)
        }
    }

    @Test func invalidHTTPResponseThrows() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [NonHTTPURLProtocol.self]
        let transport = URLSessionTransport(session: URLSession(configuration: config))
        let request = PortalRequest(method: .get, path: Path(url: "https://api.example.com/test", query: nil), scheme: nil)
        await #expect(throws: PortalError.self) {
            _ = try await transport.execute(request)
        }
    }

    @Test func stringHeadersForwarded() async throws {
        var receivedHeader: String?
        StubURLProtocol.handler = { req in
            receivedHeader = req.value(forHTTPHeaderField: "X-Custom")
            let response = HTTPURLResponse(url: req.url ?? URL(string: "https://api.example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let (transport, _) = makeStubTransport()
        let request = PortalRequest(
            method: .get,
            path: Path(url: "https://api.example.com/test", query: nil),
            header: [Header(key: "X-Custom", value: "hello")],
            scheme: nil
        )
        _ = try await transport.execute(request)
        #expect(receivedHeader == "hello")
    }

    @Test func jsonBodySetsContentType() async throws {
        var receivedContentType: String?
        StubURLProtocol.handler = { req in
            receivedContentType = req.value(forHTTPHeaderField: "Content-Type")
            let response = HTTPURLResponse(url: req.url ?? URL(string: "https://api.example.com")!, statusCode: 201, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let (transport, _) = makeStubTransport()
        struct Payload: Encodable { let name: String }
        let request = PortalRequest(
            method: .post,
            path: Path(url: "https://api.example.com/test", query: nil),
            body: Body(data: Payload(name: "Alice"), encoding: .json),
            scheme: nil
        )
        let (_, code) = try await transport.execute(request)
        #expect(code == 201)
        #expect(receivedContentType == "application/json")
    }

    @Test func urlEncodedBodySetsContentType() async throws {
        var receivedContentType: String?
        StubURLProtocol.handler = { req in
            receivedContentType = req.value(forHTTPHeaderField: "Content-Type")
            let response = HTTPURLResponse(url: req.url ?? URL(string: "https://api.example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let (transport, _) = makeStubTransport()
        struct Payload: Encodable { let key: String }
        let request = PortalRequest(
            method: .post,
            path: Path(url: "https://api.example.com/test", query: nil),
            body: Body(data: Payload(key: "val"), encoding: .urlEncoded),
            scheme: nil
        )
        let (_, code) = try await transport.execute(request)
        #expect(code == 200)
        #expect(receivedContentType == "application/x-www-form-urlencoded")
    }

    @Test func queryParamsAppended() async throws {
        var receivedURL: URL?
        StubURLProtocol.handler = { req in
            receivedURL = req.url
            let response = HTTPURLResponse(url: req.url ?? URL(string: "https://api.example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        let (transport, _) = makeStubTransport()
        let query = [URLQueryItem(name: "page", value: "2")]
        let request = PortalRequest(method: .get, path: Path(url: "https://api.example.com/list", query: query), scheme: nil)
        _ = try await transport.execute(request)
        #expect(receivedURL?.query?.contains("page=2") == true)
    }

    @Test func returns404StatusCode() async throws {
        stubResponse(404)
        let (transport, _) = makeStubTransport()
        let request = PortalRequest(method: .get, path: Path(url: "https://api.example.com/test", query: nil), scheme: nil)
        let (_, code) = try await transport.execute(request)
        #expect(code == 404)
    }
}
