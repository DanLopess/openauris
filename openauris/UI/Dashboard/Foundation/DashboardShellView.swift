import SwiftUI

struct DashboardShellView<Sidebar: View, Content: View>: View {
    @ViewBuilder let sidebar: Sidebar
    @ViewBuilder let content: Content

    init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder content: () -> Content) {
        self.sidebar = sidebar()
        self.content = content()
    }

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            content
                .padding(DashboardTheme.pagePadding)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }
}
