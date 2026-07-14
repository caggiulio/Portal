import Testing
import Foundation
@testable import Portal

@Suite("PortalMedia")
struct PortalMediaTests {
    @Test func initStoresAllProperties() {
        let data = Data([0x01, 0x02])
        let media = PortalMedia(data: data, key: "file", filename: "photo.jpg", mimeType: "image/jpeg")
        #expect(media.data == data)
        #expect(media.key == "file")
        #expect(media.filename == "photo.jpg")
        #expect(media.mimeType == "image/jpeg")
    }
}
