import SwiftUI

struct DashboardShellView<Sidebar: View, Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    @ViewBuilder let sidebar: Sidebar
    @ViewBuilder let content: Content

    init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder content: () -> Content) {
        self.sidebar = sidebar()
        self.content = content()
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .background(DashboardTheme.windowBackground(colorScheme))
        } detail: {
            ZStack(alignment: .topLeading) {
                DashboardTheme.windowBackground(colorScheme)

                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }
}
