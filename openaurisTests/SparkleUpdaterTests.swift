import Testing
import Sparkle
@testable import openauris

@MainActor
struct SparkleUpdaterTests {

    @Test func appContainerExposesUpdaterController() {
        let container = AppContainer()
        let _: SPUStandardUpdaterController = container.updaterController
        #expect(container.updaterController.updater.feedURL != nil)
    }

    @Test func updaterFeedURLMatchesExpected() {
        let container = AppContainer()
        let feedURL = container.updaterController.updater.feedURL
        #expect(feedURL?.absoluteString ==
            "https://raw.githubusercontent.com/DanLopess/openauris/main/appcast.xml")
    }
}
