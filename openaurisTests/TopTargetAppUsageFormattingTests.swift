import Testing
@testable import openauris

struct TopTargetAppUsageFormattingTests {
    @Test
    func displayNameUsesUnknownFallback() {
        #expect(TopTargetAppUsage.displayName(for: "unknown") == "Unknown App")
        #expect(TopTargetAppUsage.displayName(for: "   ") == "Unknown App")
    }

    @Test
    func displayNameKeepsPascalCaseAppName() {
        #expect(TopTargetAppUsage.displayName(for: "com.apple.TextEdit") == "TextEdit")
    }

    @Test
    func displayNameCapitalizesLowercaseComponent() {
        #expect(TopTargetAppUsage.displayName(for: "com.apple.terminal") == "Terminal")
    }

    @Test
    func displayNameHumanizesSeparatedComponents() {
        #expect(TopTargetAppUsage.displayName(for: "com.acme.my_app-editor") == "My App Editor")
    }
}
