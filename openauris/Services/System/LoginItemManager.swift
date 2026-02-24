import Foundation
import ServiceManagement

@MainActor
enum LoginItemManager {
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Keep silent; settings screen can reflect persisted preference independent of OS-level failure.
        }
    }
}
