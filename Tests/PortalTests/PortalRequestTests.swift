import Testing
import Foundation
@testable import Portal

@Suite("PortalRequest")
struct PortalRequestTests {
    @Test func defaultScheme() {
        let request = PortalRequest(method: .get, path: Path(url: "/api", query: nil))
        #expect(request.scheme == .http)
    }

    @Test func nilScheme() {
        let request = PortalRequest(method: .post, path: Path(url: "/api", query: nil), scheme: nil)
        #expect(request.scheme == nil)
    }

    @Test func allHTTPMethods() {
        #expect(PortalRequest.HTTPMethod.get.rawValue == "GET")
        #expect(PortalRequest.HTTPMethod.post.rawValue == "POST")
        #expect(PortalRequest.HTTPMethod.put.rawValue == "PUT")
        #expect(PortalRequest.HTTPMethod.patch.rawValue == "PATCH")
        #expect(PortalRequest.HTTPMethod.delete.rawValue == "DELETE")
    }

    @Test func schemeRawValues() {
        #expect(PortalRequest.Scheme.http.rawValue == "http")
        #expect(PortalRequest.Scheme.https.rawValue == "https")
    }

    @Test func pathStoresValues() {
        let items = [URLQueryItem(name: "page", value: "1")]
        let path = Path(url: "https://api.example.com", query: items)
        #expect(path.url == "https://api.example.com")
        #expect(path.query == items)
    }

    @Test func bodyStoresJsonEncoding() {
        struct Payload: Encodable { let id: Int }
        let body = Body(data: Payload(id: 42), encoding: .json)
        #expect(body.encoding == .json)
    }

    @Test func bodyStoresUrlEncodedEncoding() {
        struct Payload: Encodable { let name: String }
        let body = Body(data: Payload(name: "test"), encoding: .urlEncoded)
        #expect(body.encoding == .urlEncoded)
    }
}
