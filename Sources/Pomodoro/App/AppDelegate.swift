import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let preferences = Preferences()
    private let clock: () -> Date = Date.init
    lazy var engine = TimerEngine(preset: preferences.cyclePreset, clock: clock)
    lazy var model = AppModel(engine: engine, preferences: preferences, clock: clock)

    private var statusItemController: StatusItemController?
    private var surfaceController: SurfaceController?
    private var alertCenter: AlertCenter?
    private var welcomeWindowController: WelcomeWindowController?
    private var tickTimer: Timer?
    private var cancellables: Set<AnyCancellable> = []
    #if DEBUG
    private var screenshotMode: ScreenshotMode?
    #endif

    func applicationDidFinishLaunching(_ notification: Notification) {
        #if DEBUG
        if ScreenshotMode.isActive {
            let mode = ScreenshotMode(engine: engine, preferences: preferences)
            screenshotMode = mode
            mode.present()
            return
        }
        #endif
        let statusItemController = StatusItemController(engine: engine, preferences: preferences)
        let surfaceController = SurfaceController(model: model)

        surfaceController.attach(statusButton: statusItemController.button)
        statusItemController.onClick = { [weak surfaceController] in
            surfaceController?.toggle()
        }

        self.statusItemController = statusItemController
        self.surfaceController = surfaceController

        let alertCenter = AlertCenter(preferences: preferences)
        model.alertCenter = alertCenter
        model.onAlert = { [weak alertCenter] kind in
            alertCenter?.fire(kind)
        }
        model.onPeonEvent = { [weak alertCenter] event in
            alertCenter?.firePeon(event)
        }
        self.alertCenter = alertCenter

        model.onRequestReplayOnboarding = { [weak self] in self?.presentOnboarding() }

        observePresetChanges()
        startTicking()

        if !preferences.hasCompletedOnboarding {
            presentOnboarding()
        }
    }

    private func presentOnboarding() {
        guard let alertCenter else { return }
        if let existing = welcomeWindowController {
            existing.present()
            return
        }
        let controller = WelcomeWindowController(
            preferences: preferences,
            alertCenter: alertCenter,
            onComplete: { [weak self] in self?.finishOnboarding() },
            onSkip: { [weak self] in self?.finishOnboarding() }
        )
        welcomeWindowController = controller
        controller.present()
    }

    private func finishOnboarding() {
        preferences.hasCompletedOnboarding = true
        welcomeWindowController?.dismiss()
        welcomeWindowController = nil
        surfaceController?.reveal()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        alertCenter?.refreshAuthorizationStatus()
    }

    private func observePresetChanges() {
        preferences.$cyclePreset
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak engine] preset in engine?.updatePreset(preset) }
            .store(in: &cancellables)
    }

    private func startTicking() {
        let timer = Timer(timeInterval: 1, repeats: true) { [weak engine] _ in
            MainActor.assumeIsolated {
                engine?.tick()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        tickTimer = timer
    }
}
