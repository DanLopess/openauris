import Testing
@testable import openauris

struct VersionParserTests {

    @Test func parsesThreeComponentVersion() {
        let v = VersionParser.parse("1.2.3")
        #expect(v?.major == 1)
        #expect(v?.minor == 2)
        #expect(v?.patch == 3)
    }

    @Test func parsesTwoComponentVersion() {
        let v = VersionParser.parse("0.0")
        #expect(v?.major == 0)
        #expect(v?.minor == 0)
        #expect(v?.patch == 0)
    }

    @Test func returnsNilForInvalid() {
        #expect(VersionParser.parse("abc") == nil)
        #expect(VersionParser.parse("") == nil)
        #expect(VersionParser.parse("1") == nil)
    }

    @Test func compareVersions() {
        let a = VersionParser.parse("0.0.1")!
        let b = VersionParser.parse("0.0.2")!
        let c = VersionParser.parse("0.1.0")!
        let d = VersionParser.parse("1.0.0")!
        #expect(a < b)
        #expect(b < c)
        #expect(c < d)
        #expect(a < d)
    }

    @Test func equalVersions() {
        let a = VersionParser.parse("1.2.3")!
        let b = VersionParser.parse("1.2.3")!
        #expect(a == b)
    }

    @Test func nextPatchFromExistingTags() {
        // No existing tags → first version uses patch 1
        let first = VersionParser.nextVersion(majorMinor: "0.0", existingTags: [])
        #expect(first == "0.0.1")

        // One existing tag → increment
        let second = VersionParser.nextVersion(majorMinor: "0.0", existingTags: ["v0.0.1"])
        #expect(second == "0.0.2")

        // Multiple tags, gap in patches → use highest + 1
        let third = VersionParser.nextVersion(majorMinor: "0.1", existingTags: ["v0.1.0", "v0.1.1", "v0.1.3"])
        #expect(third == "0.1.4")

        // New minor with no matching tags → start at .0
        let newMinor = VersionParser.nextVersion(majorMinor: "1.0", existingTags: ["v0.1.0", "v0.9.5"])
        #expect(newMinor == "1.0.0")
    }
}
