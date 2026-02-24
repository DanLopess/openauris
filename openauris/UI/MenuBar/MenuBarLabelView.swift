import SwiftUI

struct MenuBarLabelView: View {
    var body: some View {
        Image(Branding.menuBarIconAssetName)
            .resizable()
            .scaledToFit()
            .frame(width: 18, height: 18)
            .accessibilityLabel(OpenAurisConstants.appName)
    }
}
