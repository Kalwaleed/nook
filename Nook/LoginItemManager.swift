import ServiceManagement

final class LoginItemManager {
    var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    func enable() throws {
        try SMAppService.mainApp.register()
    }

    func disable() throws {
        try SMAppService.mainApp.unregister()
    }
}
