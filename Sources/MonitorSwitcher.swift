import SwiftUI
import AppKit
import CoreGraphics
import Darwin

// MARK: - DisplayServices private framework (for built-in backlight on Apple Silicon)

private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32

private let dsHandle: UnsafeMutableRawPointer? = dlopen(
    "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
    RTLD_NOW
)

private let setBrightness: SetBrightnessFn? = {
    guard let h = dsHandle, let s = dlsym(h, "DisplayServicesSetBrightness") else { return nil }
    return unsafeBitCast(s, to: SetBrightnessFn.self)
}()

private let getBrightness: GetBrightnessFn? = {
    guard let h = dsHandle, let s = dlsym(h, "DisplayServicesGetBrightness") else { return nil }
    return unsafeBitCast(s, to: GetBrightnessFn.self)
}()

// MARK: - Display info

struct DisplayInfo: Identifiable, Hashable {
    let id: CGDirectDisplayID
    var isBuiltIn: Bool { CGDisplayIsBuiltin(id) != 0 }
    var isMirrored: Bool { CGDisplayMirrorsDisplay(id) != 0 }
    var name: String { isBuiltIn ? "Built-in Display" : "External (\(CGDisplayPixelsWide(id))×\(CGDisplayPixelsHigh(id)))" }
    var resolution: String { "\(CGDisplayPixelsWide(id))×\(CGDisplayPixelsHigh(id))" }
}

// MARK: - DisplayManager

@MainActor
final class DisplayManager: ObservableObject {
    @Published private(set) var displays: [DisplayInfo] = []
    @Published private(set) var builtInOff: Bool = false

    // Persist saved brightness across launches so we can restore even after a crash/quit.
    private let savedBrightnessKey = "MonitorSwitcher.savedBrightness"
    private var savedBrightness: Float {
        get { UserDefaults.standard.object(forKey: savedBrightnessKey) as? Float ?? 0.5 }
        set { UserDefaults.standard.set(newValue, forKey: savedBrightnessKey) }
    }

    init() {
        refresh()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        // Use online list so mirrored secondaries are still included
        var count: UInt32 = 0
        CGGetOnlineDisplayList(0, nil, &count)
        var ids = [CGDirectDisplayID](repeating: 0, count: Int(count))
        CGGetOnlineDisplayList(count, &ids, &count)
        displays = ids.map { DisplayInfo(id: $0) }

        if let builtIn = builtIn {
            let dim = currentBrightness(builtIn.id) < 0.01
            builtInOff = builtIn.isMirrored || dim
        } else {
            builtInOff = false
        }
    }

    var builtIn: DisplayInfo? { displays.first { $0.isBuiltIn } }
    // External = anything not built-in that is also not just a mirror of the built-in
    var firstExternal: DisplayInfo? {
        displays.first { !$0.isBuiltIn && CGDisplayMirrorsDisplay($0.id) == kCGNullDirectDisplay }
            ?? displays.first { !$0.isBuiltIn }
    }
    var hasExternal: Bool { firstExternal != nil }

    private func currentBrightness(_ id: CGDirectDisplayID) -> Float {
        guard let fn = getBrightness else { return -1 }
        var b: Float = 0
        _ = fn(id, &b)
        return b
    }

    func turnOffBuiltIn() {
        guard let builtIn = builtIn, let external = firstExternal else { return }

        let current = currentBrightness(builtIn.id)
        if current > 0.01 { savedBrightness = current }

        var cfg: CGDisplayConfigRef?
        CGBeginDisplayConfiguration(&cfg)
        CGConfigureDisplayMirrorOfDisplay(cfg, builtIn.id, external.id)
        CGCompleteDisplayConfiguration(cfg, .permanently)

        _ = setBrightness?(builtIn.id, 0.0)
        builtInOff = true
    }

    func turnOnBuiltIn() {
        guard let builtIn = builtIn else { return }

        var cfg: CGDisplayConfigRef?
        CGBeginDisplayConfiguration(&cfg)
        CGConfigureDisplayMirrorOfDisplay(cfg, builtIn.id, kCGNullDirectDisplay)
        CGCompleteDisplayConfiguration(cfg, .permanently)

        let restore = max(savedBrightness, 0.5)
        _ = setBrightness?(builtIn.id, restore)
        builtInOff = false
    }
}

// MARK: - UI

struct MenuView: View {
    @EnvironmentObject var dm: DisplayManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "display.2")
                Text("Connected Displays").font(.headline)
                Spacer()
                Button(action: { dm.refresh() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh")
            }

            ForEach(dm.displays) { d in
                HStack(spacing: 8) {
                    Image(systemName: d.isBuiltIn ? "laptopcomputer" : "display")
                        .foregroundColor(d.isBuiltIn ? .accentColor : .green)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(d.name)
                        Text(d.resolution).font(.caption).foregroundColor(.secondary)
                    }
                    Spacer()
                    if d.isMirrored {
                        Text("mirrored").font(.caption2).foregroundColor(.orange)
                    }
                }
                .padding(.vertical, 2)
            }

            Divider()

            if dm.hasExternal {
                Button(action: {
                    if dm.builtInOff { dm.turnOnBuiltIn() } else { dm.turnOffBuiltIn() }
                    dm.refresh()
                }) {
                    HStack {
                        Image(systemName: dm.builtInOff ? "sun.max.fill" : "moon.fill")
                        Text(dm.builtInOff ? "Turn On MacBook Display" : "Turn Off MacBook Display")
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle")
                    Text("Connect an external display to enable toggle")
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }

            Divider()
            Button("Quit MonitorSwitcher") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
        }
        .padding(12)
        .frame(width: 300)
    }
}

// MARK: - App

@main
struct MonitorSwitcherApp: App {
    @StateObject private var dm = DisplayManager()

    var body: some Scene {
        MenuBarExtra {
            MenuView().environmentObject(dm)
        } label: {
            Image(systemName: dm.builtInOff ? "display" : "display.2")
        }
        .menuBarExtraStyle(.window)
    }
}
