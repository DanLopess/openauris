import SwiftUI

enum Branding {
    static let menuBarIconAssetName = "MenuBarIcon"
    static let appLogoAssetName = "BrandMark"
}

struct AppBrandLogo: View {
    var size: CGFloat = 56

    var body: some View {
        Image(Branding.appLogoAssetName)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}
