import AppKit

public final class ControlWindowController: NSWindowController, NSWindowDelegate {
    public static let shared = ControlWindowController()
    
    private var statusDot: NSTextField!
    private var serverStatus: NSTextField!
    private var activeUrlLabel: NSTextField!
    
    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 490),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "NoxSnap Control Panel"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        
        super.init(window: window)
        window.delegate = self
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        guard let window = self.window else { return }
        
        let visualEffect = NSVisualEffectView(frame: window.contentView!.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        window.contentView?.addSubview(visualEffect)
        
        let container = NSView(frame: visualEffect.bounds)
        container.autoresizingMask = [.width, .height]
        visualEffect.addSubview(container)
        
        // 1. Header (Title + Subtitle)
        let titleLabel = NSTextField(labelWithString: "⚡️ NoxSnap")
        titleLabel.frame = NSRect(x: 20, y: 420, width: 400, height: 32)
        titleLabel.alignment = .center
        titleLabel.font = NSFont.systemFont(ofSize: 26, weight: .bold)
        titleLabel.textColor = .white
        container.addSubview(titleLabel)
        
        let subTitle = NSTextField(labelWithString: "Hardware Magnet Handoff • Option A Embedded")
        subTitle.frame = NSRect(x: 20, y: 395, width: 400, height: 18)
        subTitle.alignment = .center
        subTitle.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        subTitle.textColor = NSColor(calibratedWhite: 0.65, alpha: 1.0)
        container.addSubview(subTitle)
        
        // 2. Server Status Card
        let statusCard = NSBox(frame: NSRect(x: 20, y: 310, width: 400, height: 72))
        statusCard.boxType = .custom
        statusCard.fillColor = NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.16, alpha: 0.9)
        statusCard.borderWidth = 1
        statusCard.borderColor = NSColor(calibratedRed: 0.22, green: 0.26, blue: 0.4, alpha: 0.8)
        statusCard.cornerRadius = 14
        
        statusDot = NSTextField(labelWithString: "🟢")
        statusDot.frame = NSRect(x: 16, y: 26, width: 24, height: 20)
        statusCard.addSubview(statusDot)
        
        serverStatus = NSTextField(labelWithString: "Receiver Active on Port \(NoxSnapServer.shared.port)")
        serverStatus.frame = NSRect(x: 44, y: 36, width: 340, height: 18)
        serverStatus.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        serverStatus.textColor = .white
        statusCard.addSubview(serverStatus)
        
        let bonjourText = NSTextField(labelWithString: "Broadcasting: _noxsnap._tcp • Instant Zero-Config Discovery")
        bonjourText.frame = NSRect(x: 44, y: 16, width: 340, height: 16)
        bonjourText.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        bonjourText.textColor = NSColor(calibratedRed: 0.0, green: 0.9, blue: 1.0, alpha: 1.0)
        statusCard.addSubview(bonjourText)
        container.addSubview(statusCard)
        
        // 3. Option A Directional Bezel Card
        let howCard = NSBox(frame: NSRect(x: 20, y: 95, width: 400, height: 200))
        howCard.boxType = .custom
        howCard.fillColor = NSColor(calibratedRed: 0.06, green: 0.07, blue: 0.13, alpha: 0.85)
        howCard.borderWidth = 1
        howCard.borderColor = NSColor(calibratedRed: 0.16, green: 0.2, blue: 0.32, alpha: 0.7)
        howCard.cornerRadius = 14
        
        let howTitle = NSTextField(labelWithString: "🧭 Option A: Directional Bezel Handoff")
        howTitle.frame = NSRect(x: 16, y: 168, width: 368, height: 20)
        howTitle.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        howTitle.textColor = NSColor(calibratedRed: 0.0, green: 0.95, blue: 1.0, alpha: 1.0)
        howCard.addSubview(howTitle)
        
        let howBody = NSTextField(wrappingLabelWithString: "• 👈 TOP-LEFT LID BEZEL: Mac ➔ Phone\nTouch phone to the top-left lid magnet to pull your active Mac browser tab and open it instantly on your phone.\n\n• 👉 TOP-RIGHT LID BEZEL: Phone ➔ Mac\nTouch phone to the top-right lid magnet to push your phone's active URL/clipboard and open it on your Mac.")
        howBody.frame = NSRect(x: 16, y: 35, width: 368, height: 125)
        howBody.font = NSFont.systemFont(ofSize: 11, weight: .regular)
        howBody.textColor = NSColor(calibratedWhite: 0.8, alpha: 1.0)
        howCard.addSubview(howBody)
        
        activeUrlLabel = NSTextField(labelWithString: "Active Mac Tab: Scanning...")
        activeUrlLabel.frame = NSRect(x: 16, y: 12, width: 368, height: 16)
        activeUrlLabel.font = NSFont.systemFont(ofSize: 10, weight: .medium)
        activeUrlLabel.textColor = NSColor(calibratedRed: 0.4, green: 0.8, blue: 1.0, alpha: 0.9)
        howCard.addSubview(activeUrlLabel)
        container.addSubview(howCard)
        
        // 4. Action Buttons
        let testChimeBtn = NSButton(title: "🔔 Test Arrival Chime", target: self, action: #selector(testChime))
        testChimeBtn.frame = NSRect(x: 20, y: 30, width: 190, height: 32)
        testChimeBtn.bezelStyle = .rounded
        container.addSubview(testChimeBtn)
        
        let refreshTabBtn = NSButton(title: "🔄 Check Active Tab", target: self, action: #selector(checkActiveTab))
        refreshTabBtn.frame = NSRect(x: 230, y: 30, width: 190, height: 32)
        refreshTabBtn.bezelStyle = .rounded
        container.addSubview(refreshTabBtn)
        
        checkActiveTab()
    }
    
    @objc private func testChime() {
        SoundManager.shared.playChime()
    }
    
    @objc private func checkActiveTab() {
        let url = BrowserHandoffManager.shared.getActiveBrowserURL() ?? "No active browser tab found"
        activeUrlLabel.stringValue = "Active Mac Tab: \(url)"
    }
    
    public func show() {
        checkActiveTab()
        self.window?.center()
        self.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
