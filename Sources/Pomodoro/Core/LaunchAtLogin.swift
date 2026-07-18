import ServiceManagement

protocol LoginItemRegistering {
    func register() throws
    func unregister() throws
}

struct SMAppServiceLoginItemRegistrar: LoginItemRegistering {
    func register() throws {
        try SMAppService.mainApp.register()
    }

    func unregister() throws {
        try SMAppService.mainApp.unregister()
    }
}
