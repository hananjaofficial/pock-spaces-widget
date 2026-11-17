import Cocoa

@_silgen_name("SLSMainConnectionID")
func SLSMainConnectionID() -> Int32

@_silgen_name("SLSCopyManagedDisplaySpaces")
func SLSCopyManagedDisplaySpaces(_ cid: Int32) -> CFArray?

@_silgen_name("SLSCopySpacesForWindows")
func SLSCopySpacesForWindows(_ cid: Int32, _ mask: Int32, _ windowIDs: CFArray) -> CFArray?

@objc(PKWidget)
protocol PKWidget: NSObjectProtocol {
    var identifier: NSTouchBarItem.Identifier { get }
    var customizationLabel: String { get }
    var view: NSView! { get }
    init()
}

struct MacSpace {
    let id: UInt64
    let uuid: String
    let type: Int
    let isCurrent: Bool
    let ownerPID: pid_t?
}

@objc(SpacesWidget)
class SpacesWidget: NSObject, PKWidget {
    var identifier: NSTouchBarItem.Identifier = NSTouchBarItem.Identifier("com.custom.pock.Spaces")
    var customizationLabel: String = "Spaces"
    var view: NSView!
    
    private let stackView = NSStackView()
    private var buttons: [NSButton] = []
    private var spaces: [MacSpace] = []
    private var snapshots: [UInt64: NSImage] = [:]
    private var timer: Timer?
    
    required override init() {
        super.init()
        setupView()
        refreshSpaces()
        
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.refreshSpaces()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
    
    private func setupView() {
        stackView.orientation = .horizontal
        stackView.spacing = 6
        stackView.alignment = .centerY
        self.view = stackView
    }
    
    // Findet für jede Space-ID die zugehörige App-PID über die Fensterliste
    private func mapSpaceToAppPID() -> [UInt64: pid_t] {
        var mapping: [UInt64: pid_t] = [:]
        let cid = SLSMainConnectionID()
        
        guard let windowList = CGWindowListCopyWindowInfo([.excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return mapping
        }
        
        for win in windowList {
            guard let winID = win[kCGWindowNumber as String] as? UInt32,
                  let pid = win[kCGWindowOwnerPID as String] as? pid_t,
                  let layer = win[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let ownerName = win[kCGWindowOwnerName as String] as? String,
                  ownerName != "Dock" && ownerName != "Window Server" && ownerName != "PockV3" else {
                continue
            }
            
            let winArray = [NSNumber(value: winID)] as CFArray
            if let spaceIDs = SLSCopySpacesForWindows(cid, 0x7, winArray) as? [NSNumber] {
                for spNum in spaceIDs {
                    let spID = spNum.uint64Value
                    if mapping[spID] == nil {
                        mapping[spID] = pid
                    }
                }
            }
        }
        return mapping
    }
    
    private func fetchManagedSpaces() -> [MacSpace] {
        let cid = SLSMainConnectionID()
        guard let rawDisplays = SLSCopyManagedDisplaySpaces(cid) as? [[String: Any]],
              let mainDisplay = rawDisplays.first else {
            return []
        }
        
        let currentSpaceDict = mainDisplay["Current Space"] as? [String: Any]
        let currentID = (currentSpaceDict?["id64"] as? NSNumber)?.uint64Value ?? 0
        let pidMap = mapSpaceToAppPID()
        
        var result: [MacSpace] = []
        if let rawSpaces = mainDisplay["Spaces"] as? [[String: Any]] {
            for sp in rawSpaces {
                let type = sp["type"] as? Int ?? 0
                if type == 0 || type == 4 {
                    let id = (sp["id64"] as? NSNumber)?.uint64Value ?? 0
                    let uuid = sp["uuid"] as? String ?? ""
                    let directPID = (sp["pid"] as? NSNumber)?.int32Value
                    let resolvedPID = directPID ?? pidMap[id]
                    result.append(MacSpace(id: id, uuid: uuid, type: type, isCurrent: id == currentID, ownerPID: resolvedPID))
                }
            }
        }
        return result
    }
    
    private func refreshSpaces() {
        let fetched = fetchManagedSpaces()
        let oldIDs = spaces.map { $0.id }
        let newIDs = fetched.map { $0.id }
        let oldActive = spaces.first(where: { $0.isCurrent })?.id
        let newActive = fetched.first(where: { $0.isCurrent })?.id
        
        self.spaces = fetched
        
        if oldIDs != newIDs {
            rebuildButtons()
        }
        
        updateSelection()
        
        if let activeID = newActive, (oldActive != newActive || snapshots[activeID] == nil) {
            captureCurrentSpace(for: activeID)
        }
    }
    
    private func rebuildButtons() {
        buttons.forEach { stackView.removeArrangedSubview($0); $0.removeFromSuperview() }
        buttons.removeAll()
        
        let baseWallpaper = getWallpaperThumbnail()
        
        for (index, space) in spaces.enumerated() {
            let button = NSButton(frame: NSRect(x: 0, y: 0, width: 46, height: 26))
            button.title = ""
            button.isBordered = false
            button.wantsLayer = true
            button.layer?.cornerRadius = 5
            button.layer?.masksToBounds = true
            button.tag = index
            button.target = self
            button.action = #selector(switchSpace(_:))
            
            button.image = snapshots[space.id] ?? baseWallpaper
            button.imageScaling = .scaleAxesIndependently
            
            button.widthAnchor.constraint(equalToConstant: 46).isActive = true
            button.heightAnchor.constraint(equalToConstant: 26).isActive = true
            
            buttons.append(button)
            stackView.addArrangedSubview(button)
        }
    }
    
    private func captureCurrentSpace(for spaceID: UInt64) {
        DispatchQueue.global(qos: .userInitiated).async {
            let tmpPath = "/tmp/pock_space_\(spaceID).jpg"
            let task = Process()
            task.launchPath = "/usr/sbin/screencapture"
            task.arguments = ["-x", "-t", "jpg", tmpPath]
            task.launch()
            task.waitUntilExit()
            
            guard let fullImage = NSImage(contentsOfFile: tmpPath) else { return }
            let thumbSize = NSSize(width: 92, height: 52)
            let thumb = NSImage(size: thumbSize)
            
            thumb.lockFocus()
            fullImage.draw(
                in: NSRect(origin: .zero, size: thumbSize),
                from: NSRect(origin: .zero, size: fullImage.size),
                operation: .copy,
                fraction: 1.0
            )
            thumb.unlockFocus()
            
            DispatchQueue.main.async {
                self.snapshots[spaceID] = thumb
                if let idx = self.spaces.firstIndex(where: { $0.id == spaceID }), idx < self.buttons.count {
                    self.buttons[idx].image = thumb
                }
            }
        }
    }
    
    private func getWallpaperThumbnail() -> NSImage? {
        guard let screen = NSScreen.main,
              let url = NSWorkspace.shared.desktopImageURL(for: screen),
              let fullImage = NSImage(contentsOf: url) else { return nil }
        
        let thumbSize = NSSize(width: 92, height: 52)
        let thumb = NSImage(size: thumbSize)
        thumb.lockFocus()
        fullImage.draw(in: NSRect(origin: .zero, size: thumbSize),
                       from: NSRect(origin: .zero, size: fullImage.size),
                       operation: .copy,
                       fraction: 1.0)
        thumb.unlockFocus()
        return thumb
    }
    
    private func updateSelection() {
        for (idx, btn) in buttons.enumerated() where idx < spaces.count {
            if spaces[idx].isCurrent {
                btn.layer?.borderWidth = 2.0
                btn.layer?.borderColor = NSColor.white.cgColor
                btn.alphaValue = 1.0
            } else {
                btn.layer?.borderWidth = 1.0
                btn.layer?.borderColor = NSColor.darkGray.cgColor
                btn.alphaValue = 0.7
            }
        }
    }
    
    @objc private func switchSpace(_ sender: NSButton) {
        let targetIndex = sender.tag
        guard targetIndex < spaces.count else { return }
        let targetSpace = spaces[targetIndex]
        
        if targetSpace.isCurrent {
            captureCurrentSpace(for: targetSpace.id)
            return
        }
        
        if let current = spaces.first(where: { $0.isCurrent }) {
            captureCurrentSpace(for: current.id)
        }
        
        // Wenn auf dem Ziel-Space eine App läuft (Vollbild-App oder normales Fenster), diese sauber aktivieren
        if let pid = targetSpace.ownerPID,
           let app = NSRunningApplication(processIdentifier: pid),
           let bundleURL = app.bundleURL {
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: bundleURL, configuration: config)
        } else {
            // Wenn der Ziel-Space ein leerer Schreibtisch ist -> Finder öffnen, damit macOS sauber dorthin wechselt
            let finderURL = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true
            NSWorkspace.shared.openApplication(at: finderURL, configuration: config)
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            self.refreshSpaces()
            self.captureCurrentSpace(for: targetSpace.id)
        }
    }
}
