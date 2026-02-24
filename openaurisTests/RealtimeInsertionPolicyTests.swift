import Testing
@testable import openauris

struct RealtimeInsertionPolicyTests {
    @Test
    func autoLanguageDisablesRealtimeInsertion() {
        #expect(RealtimeInsertionPolicy.shouldInsertPartials(languageOverride: "auto") == false)
    }

    @Test
    func blankLanguageDisablesRealtimeInsertion() {
        #expect(RealtimeInsertionPolicy.shouldInsertPartials(languageOverride: "   ") == false)
    }

    @Test
    func nilLanguageDisablesRealtimeInsertion() {
        #expect(RealtimeInsertionPolicy.shouldInsertPartials(languageOverride: nil) == false)
    }

    @Test
    func explicitLanguageEnablesRealtimeInsertion() {
        #expect(RealtimeInsertionPolicy.shouldInsertPartials(languageOverride: "pt") == true)
    }

    @Test
    func uppercaseAutoDisablesRealtimeInsertion() {
        #expect(RealtimeInsertionPolicy.shouldInsertPartials(languageOverride: "AUTO") == false)
    }
}
