import AppKit
import Foundation
import QuartzCore

// MARK: - Water Repel Shockwave View (Ultra-Premium Liquid Crystal Ripple Waves)
private final class WaterShockwaveView: NSView {
    
    func emitWaterRepel(from origin: CGPoint) {
        // Pure Liquid Water Palette: High-clarity specular whites & crystalline water body
        let specularPure = NSColor(white: 1.0, alpha: 0.88).cgColor
        let crestCrystalline = NSColor(white: 1.0, alpha: 0.60).cgColor
        let refractionBody = NSColor(white: 0.96, alpha: 0.32).cgColor
        let diffuseWater = NSColor(white: 1.0, alpha: 0.14).cgColor
        
        // 1. Dual-Layer Liquid Impact Meniscus (Droplet impact flare at bezel edge)
        // Layer A: Core droplet bright bloom
        let coreBloom = CAGradientLayer()
        coreBloom.type = .radial
        coreBloom.colors = [specularPure, crestCrystalline, NSColor.clear.cgColor]
        coreBloom.startPoint = CGPoint(x: 0.5, y: 0.5)
        coreBloom.endPoint = CGPoint(x: 1.0, y: 1.0)
        coreBloom.bounds = CGRect(x: 0, y: 0, width: 180, height: 180)
        coreBloom.position = origin
        coreBloom.opacity = 0.0
        self.layer?.addSublayer(coreBloom)
        
        let coreAlpha = CAKeyframeAnimation(keyPath: "opacity")
        coreAlpha.values = [0.0, 0.85, 0.40, 0.0]
        coreAlpha.keyTimes = [0.0, 0.12, 0.45, 1.0]
        coreAlpha.duration = 0.85
        coreAlpha.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        let coreScale = CABasicAnimation(keyPath: "transform.scale")
        coreScale.fromValue = 0.15
        coreScale.toValue = 2.1
        coreScale.duration = 0.85
        coreScale.timingFunction = CAMediaTimingFunction(controlPoints: 0.08, 0.9, 0.22, 1.0)
        
        CATransaction.begin()
        CATransaction.setCompletionBlock { coreBloom.removeFromSuperlayer() }
        coreBloom.add(coreAlpha, forKey: "coreAlpha")
        coreBloom.add(coreScale, forKey: "coreScale")
        CATransaction.commit()
        
        // Layer B: Outer ambient water dispersion flare
        let ambientFlare = CAGradientLayer()
        ambientFlare.type = .radial
        ambientFlare.colors = [refractionBody, diffuseWater, NSColor.clear.cgColor]
        ambientFlare.startPoint = CGPoint(x: 0.5, y: 0.5)
        ambientFlare.endPoint = CGPoint(x: 1.0, y: 1.0)
        ambientFlare.bounds = CGRect(x: 0, y: 0, width: 340, height: 340)
        ambientFlare.position = origin
        ambientFlare.opacity = 0.0
        self.layer?.addSublayer(ambientFlare)
        
        let ambientAlpha = CAKeyframeAnimation(keyPath: "opacity")
        ambientAlpha.values = [0.0, 0.45, 0.20, 0.0]
        ambientAlpha.keyTimes = [0.0, 0.18, 0.60, 1.0]
        ambientAlpha.duration = 1.2
        ambientAlpha.timingFunction = CAMediaTimingFunction(name: .easeOut)
        
        let ambientScale = CABasicAnimation(keyPath: "transform.scale")
        ambientScale.fromValue = 0.3
        ambientScale.toValue = 2.8
        ambientScale.duration = 1.2
        ambientScale.timingFunction = CAMediaTimingFunction(controlPoints: 0.05, 0.85, 0.25, 1.0)
        
        CATransaction.begin()
        CATransaction.setCompletionBlock { ambientFlare.removeFromSuperlayer() }
        ambientFlare.add(ambientAlpha, forKey: "ambientAlpha")
        ambientFlare.add(ambientScale, forKey: "ambientScale")
        CATransaction.commit()
        
        // 2. Harmonic Concentric Liquid Water Wavefronts
        // 4 cascading waves with dual-stroke liquid refraction (core crest + soft fluid swell)
        let waveConfigs: [(delay: Double, maxScale: CGFloat, crestAlpha: Float, bodyWidth: CGFloat)] = [
            (delay: 0.00, maxScale: 52.0, crestAlpha: 0.90, bodyWidth: 5.5), // Primary Bow Wave
            (delay: 0.09, maxScale: 46.0, crestAlpha: 0.65, bodyWidth: 4.5), // Secondary Fluid Swell
            (delay: 0.18, maxScale: 39.0, crestAlpha: 0.45, bodyWidth: 3.5), // Harmonic Capillary Wave
            (delay: 0.27, maxScale: 32.0, crestAlpha: 0.28, bodyWidth: 2.5)  // Trailing Whisper Ripple
        ]
        
        for config in waveConfigs {
            DispatchQueue.main.asyncAfter(deadline: .now() + config.delay) { [weak self] in
                guard let self = self, let superlayer = self.layer else { return }
                
                let initialSize: CGFloat = 36
                let circlePath = CGPath(
                    ellipseIn: CGRect(x: 0, y: 0, width: initialSize, height: initialSize),
                    transform: nil
                )
                
                // Outer Soft Fluid Swell (Gives the ripple actual liquid thickness & refraction)
                let swellLayer = CAShapeLayer()
                swellLayer.bounds = CGRect(x: 0, y: 0, width: initialSize, height: initialSize)
                swellLayer.position = origin
                swellLayer.path = circlePath
                swellLayer.fillColor = NSColor.clear.cgColor
                swellLayer.strokeColor = refractionBody
                swellLayer.lineWidth = config.bodyWidth
                swellLayer.lineCap = .round
                superlayer.addSublayer(swellLayer)
                
                // Leading Crisp Specular Crest (The razor-sharp liquid meniscus highlight)
                let crestLayer = CAShapeLayer()
                crestLayer.bounds = CGRect(x: 0, y: 0, width: initialSize, height: initialSize)
                crestLayer.position = origin
                crestLayer.path = circlePath
                crestLayer.fillColor = NSColor.clear.cgColor
                crestLayer.strokeColor = specularPure
                crestLayer.lineWidth = 1.6
                crestLayer.lineCap = .round
                
                // Specular Drop Caustic Glow
                crestLayer.shadowColor = NSColor.white.cgColor
                crestLayer.shadowRadius = 8
                crestLayer.shadowOpacity = 0.75
                crestLayer.shadowOffset = .zero
                superlayer.addSublayer(crestLayer)
                
                // Natural Viscous Fluid Expansion Curve
                let scaleAnim = CABasicAnimation(keyPath: "transform.scale")
                scaleAnim.fromValue = 0.4
                scaleAnim.toValue = config.maxScale
                scaleAnim.duration = 1.35
                scaleAnim.timingFunction = CAMediaTimingFunction(controlPoints: 0.06, 0.90, 0.20, 1.0)
                
                // Evaporative Liquid Fade Out
                let fadeAnim = CABasicAnimation(keyPath: "opacity")
                fadeAnim.fromValue = config.crestAlpha
                fadeAnim.toValue = 0.0
                fadeAnim.duration = 1.35
                fadeAnim.timingFunction = CAMediaTimingFunction(name: .easeOut)
                
                // Swell animation (slightly softer fade)
                let swellFade = CABasicAnimation(keyPath: "opacity")
                swellFade.fromValue = config.crestAlpha * 0.6
                swellFade.toValue = 0.0
                swellFade.duration = 1.35
                swellFade.timingFunction = CAMediaTimingFunction(name: .easeOut)
                
                CATransaction.begin()
                CATransaction.setCompletionBlock {
                    crestLayer.removeFromSuperlayer()
                    swellLayer.removeFromSuperlayer()
                }
                crestLayer.add(scaleAnim, forKey: "scale")
                crestLayer.add(fadeAnim, forKey: "fade")
                swellLayer.add(scaleAnim, forKey: "scale")
                swellLayer.add(swellFade, forKey: "fade")
                CATransaction.commit()
            }
        }
    }
}

// MARK: - Master Magnetic / Water Repel Overlay (Pure Water Effect, No HUD Boxes)
public final class MagneticRepelOverlay: @unchecked Sendable {
    public static let shared = MagneticRepelOverlay()
    
    private var window: NSPanel?
    private var shockwaveView: WaterShockwaveView?
    private var dismissTimer: Timer?
    
    private init() {
        DispatchQueue.main.async {
            self.setupWindow()
        }
    }
    
    private func setupWindow() {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.frame
        
        let panel = NSPanel(
            contentRect: screenRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar + 25
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        
        let container = NSView(frame: screenRect)
        container.wantsLayer = true
        
        let shockwave = WaterShockwaveView(frame: screenRect)
        shockwave.wantsLayer = true
        container.addSubview(shockwave)
        self.shockwaveView = shockwave
        
        panel.contentView = container
        self.window = panel
    }
    
    public func triggerRepelEffect(side: String = "right") {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let screen = NSScreen.main,
                  let shockwave = self.shockwaveView else { return }
            
            let screenRect = screen.frame
            self.window?.setFrame(screenRect, display: true)
            self.window?.orderFrontRegardless()
            
            self.dismissTimer?.invalidate()
            
            let isLeft = (side.lowercased() == "left")
            
            // Origin at the touched bezel edge
            let cornerOrigin = isLeft ?
                CGPoint(x: 14, y: screenRect.height - 24) :
                CGPoint(x: screenRect.width - 14, y: screenRect.height - 24)
            
            // Radiate pure liquid water repel wave from the touched side
            shockwave.emitWaterRepel(from: cornerOrigin)
            
            // Dismiss transparent panel after wave dissipates
            self.dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.75, repeats: false) { [weak self] _ in
                self?.window?.orderOut(nil)
            }
        }
    }
    
    // Convenience overload matching old callers
    public func triggerRepelEffect(direction: String, url: String) {
        let side = (direction.lowercased() == "pull" || direction.lowercased() == "left") ? "left" : "right"
        triggerRepelEffect(side: side)
    }
}
