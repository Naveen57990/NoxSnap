import AppKit
import Foundation
import QuartzCore

public final class FuturisticNotchOverlay: @unchecked Sendable {
    public static let shared = FuturisticNotchOverlay()
    
    private var window: NSPanel?
    private var isShowing = false
    private var dismissTimer: Timer?
    
    private var iconLabel: NSTextField!
    private var titleLabel: NSTextField!
    private var subtitleLabel: NSTextField!
    private var borderLayer: CALayer!
    
    private init() {
        DispatchQueue.main.async {
            self.setupWindow()
        }
    }
    
    private func setupWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 390, height: 62),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar + 20
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        
        guard let contentView = panel.contentView else { return }
        contentView.wantsLayer = true
        
        // 1. Frosted Glass Background
        let visualEffect = NSVisualEffectView(frame: contentView.bounds)
        visualEffect.autoresizingMask = [.width, .height]
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.wantsLayer = true
        visualEffect.layer?.cornerRadius = 22
        visualEffect.layer?.masksToBounds = true
        contentView.addSubview(visualEffect)
        
        // 2. Obsidian Glass Surface with glowing neon border
        let border = CALayer()
        border.frame = contentView.bounds
        border.cornerRadius = 22
        border.borderWidth = 1.5
        border.borderColor = NSColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.85).cgColor
        border.backgroundColor = NSColor(red: 0.04, green: 0.06, blue: 0.11, alpha: 0.94).cgColor
        visualEffect.layer?.addSublayer(border)
        self.borderLayer = border
        
        // 3. Icon
        iconLabel = NSTextField(labelWithString: "🚀")
        iconLabel.frame = NSRect(x: 16, y: 15, width: 34, height: 32)
        iconLabel.font = NSFont.systemFont(ofSize: 22)
        iconLabel.alignment = .center
        contentView.addSubview(iconLabel)
        
        // 4. Title
        titleLabel = NSTextField(labelWithString: "NoxSnap • Opened from Phone")
        titleLabel.frame = NSRect(x: 56, y: 32, width: 318, height: 18)
        titleLabel.font = NSFont.systemFont(ofSize: 13, weight: .bold)
        titleLabel.textColor = .white
        contentView.addSubview(titleLabel)
        
        // 5. Subtitle (URL / domain)
        subtitleLabel = NSTextField(labelWithString: "https://...")
        subtitleLabel.frame = NSRect(x: 56, y: 13, width: 318, height: 16)
        subtitleLabel.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .medium)
        subtitleLabel.textColor = NSColor(red: 0.22, green: 0.85, blue: 1.0, alpha: 1.0)
        contentView.addSubview(subtitleLabel)
        
        self.window = panel
    }
    
    public func show(direction: String, url: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let panel = self.window, let screen = NSScreen.main else { return }
            
            self.dismissTimer?.invalidate()
            
            let isPushFromPhone = (direction.lowercased() == "push")
            
            self.iconLabel.stringValue = isPushFromPhone ? "🚀" : "✨"
            self.titleLabel.stringValue = isPushFromPhone ? "NoxSnap • Opened from Phone" : "NoxSnap • Beamed to Phone"
            self.titleLabel.textColor = .white
            
            if isPushFromPhone {
                // Purple / Violet Neon Accent for Push
                self.borderLayer.borderColor = NSColor(red: 0.72, green: 0.35, blue: 1.0, alpha: 0.9).cgColor
                self.subtitleLabel.textColor = NSColor(red: 0.82, green: 0.58, blue: 1.0, alpha: 1.0)
            } else {
                // Cyan Neon Accent for Pull
                self.borderLayer.borderColor = NSColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.9).cgColor
                self.subtitleLabel.textColor = NSColor(red: 0.22, green: 0.85, blue: 1.0, alpha: 1.0)
            }
            
            let displayUrl = url.replacingOccurrences(of: "https://", with: "").replacingOccurrences(of: "http://", with: "")
            self.subtitleLabel.stringValue = displayUrl.isEmpty ? "Clipboard transferred" : displayUrl
            
            // Calculate position directly below the MacBook notch / menu bar
            let screenRect = screen.frame
            let width: CGFloat = 390
            let height: CGFloat = 62
            let x = screenRect.midX - (width / 2)
            let startY = screenRect.maxY + 10 // Start offscreen above notch
            let targetY = screenRect.maxY - height - 12 // Dropdown below notch
            
            panel.setFrame(NSRect(x: x, y: startY, width: width, height: height), display: true)
            panel.alphaValue = 0.0
            panel.orderFrontRegardless()
            
            // Spring dropdown animation
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.45
                context.timingFunction = CAMediaTimingFunction(controlPoints: 0.16, 1.0, 0.3, 1.0) // Easing spring
                panel.animator().setFrame(NSRect(x: x, y: targetY, width: width, height: height), display: true)
                panel.animator().alphaValue = 1.0
            }
            
            // Auto dismiss after 2.8 seconds
            self.dismissTimer = Timer.scheduledTimer(withTimeInterval: 2.8, repeats: false) { [weak self] _ in
                self?.dismiss()
            }
        }
    }
    
    public func dismiss() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self, let panel = self.window, let screen = NSScreen.main else { return }
            
            let screenRect = screen.frame
            let width = panel.frame.width
            let height = panel.frame.height
            let x = panel.frame.origin.x
            let offscreenY = screenRect.maxY + 10
            
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.35
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(NSRect(x: x, y: offscreenY, width: width, height: height), display: true)
                panel.animator().alphaValue = 0.0
            }, completionHandler: {
                panel.orderOut(nil)
            })
        }
    }
}
