import Testing
@testable import Portal

@Suite("Encodable+Dictionary")
struct EncodableDictionaryTests {
    @Test func dictionaryConversion() {
        struct Model: Encodable { let name: String; let age: Int }
        let model = Model(name: "Alice", age: 30)
        let dict = model.dictionary
        #expect(dict != nil)
        #expect(dict?["name"] as? String == "Alice")
        #expect(dict?["age"] as? Int == 30)
    }

    @Test func nonObjectEncodableReturnsNil() {
        let value = [1, 2, 3]
        #expect(value.dictionary == nil)
    }
}
