import AppKit

// MARK: - Color Builders

public extension NSColor {

  public static func hex(_ string: String) -> NSColor {
    var hex = string.hasPrefix("#")
      ? String(string.characters.dropFirst())
      : string

    guard hex.characters.count == 3 || hex.characters.count == 6
      else { return NSColor.white().withAlphaComponent(0.0) }

    if hex.characters.count == 3 {
      for (index, char) in hex.characters.enumerated() {
        hex.insert(char, at: hex.index(hex.startIndex, offsetBy: index * 2))
      }
    }

    return NSColor(
      red:   CGFloat((Int(hex, radix: 16)! >> 16) & 0xFF) / 255.0,
      green: CGFloat((Int(hex, radix: 16)! >> 8) & 0xFF) / 255.0,
      blue:  CGFloat((Int(hex, radix: 16)!) & 0xFF) / 255.0, alpha: 1.0)
  }

  public func colorWithMinimumSaturation(_ minSaturation: CGFloat) -> NSColor {
    var (hue, saturation, brightness, alpha): (CGFloat, CGFloat, CGFloat, CGFloat) = (0.0, 0.0, 0.0, 0.0)
    getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

    return saturation < minSaturation
      ? NSColor(hue: hue, saturation: minSaturation, brightness: brightness, alpha: alpha)
      : self
  }

  public func alpha(_ value: CGFloat) -> NSColor {
    return withAlphaComponent(value)
  }
}

// MARK: - Helpers

public extension NSColor {

  public func hex(withPrefix: Bool = true) -> String {
    var (r, g, b, a): (CGFloat, CGFloat, CGFloat, CGFloat) = (0.0, 0.0, 0.0, 0.0)
    usingColorSpace(NSColorSpace.genericRGB())!.getRed(&r, green: &g, blue: &b, alpha: &a)

    let prefix = withPrefix ? "#" : ""

    return String(format: "\(prefix)%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
  }

  public var isDark: Bool {
    let RGB = cgColor.components
    return (0.2126 * RGB![0] + 0.7152 * RGB![1] + 0.0722 * RGB![2]) < 0.5
  }

  public var isBlackOrWhite: Bool {
    let RGB = cgColor.components
    return (RGB![0] > 0.91 && RGB![1] > 0.91 && RGB![2] > 0.91) || (RGB![0] < 0.09 && RGB![1] < 0.09 && RGB![2] < 0.09)
  }

  public var isBlack: Bool {
    let RGB = cgColor.components
    return (RGB![0] < 0.09 && RGB![1] < 0.09 && RGB![2] < 0.09)
  }

  public var isWhite: Bool {
    let RGB = cgColor.components
    return (RGB![0] > 0.91 && RGB![1] > 0.91 && RGB![2] > 0.91)
  }

  public func isDistinctFrom(_ color: NSColor) -> Bool {
    let bg = cgColor.components
    let fg = color.cgColor.components
    let threshold: CGFloat = 0.25
    var result = false

    if fabs((bg?[0])! - (fg?[0])!) > threshold || fabs((bg?[1])! - (fg?[1])!) > threshold || fabs((bg?[2])! - (fg?[2])!) > threshold {
      if fabs((bg?[0])! - (bg?[1])!) < 0.03 && fabs((bg?[0])! - (bg?[2])!) < 0.03 {
        if fabs((fg?[0])! - (fg?[1])!) < 0.03 && fabs((fg?[0])! - (fg?[2])!) < 0.03 {
          result = false
        }
      }
      result = true
    }

    return result
  }

  public func isContrastingWith(_ color: NSColor) -> Bool {
    let bg = components()
    let fg = color.components()
    
    let coefs : [CGFloat] = [0.2126, 0.7152, 0.0722]
    
    let lum = { (comps : [CGFloat]) in zip(comps, coefs).map { (lhs, rhs) in lhs + rhs }.reduce(0) { $0 + $1 } }
    
    let bgLum = lum(bg)
    let fgLum = lum(fg)
    let contrast = bgLum > fgLum
      ? (bgLum + 0.05) / (fgLum + 0.05)
      : (fgLum + 0.05) / (bgLum + 0.05)

    return 1.6 < contrast
  }
    
    private func components() -> [CGFloat] {
        let bufPtr = UnsafeBufferPointer(start: cgColor.components, count: cgColor.numberOfComponents)
        return Array(bufPtr)
    }
}

// MARK: - Gradient

public extension Array where Element : NSColor {

  public func gradient(_ transform: ((inout gradient: CAGradientLayer) -> CAGradientLayer)? = nil) -> CAGradientLayer {
    var gradient = CAGradientLayer()
    gradient.colors = self.map { $0.cgColor }

    if let transform = transform {
      let _ = transform(gradient: &gradient)
    }

    return gradient
  }
}

// MARK: - Components

public extension NSColor {

  func getRed() -> CGFloat {
    if (self.colorSpace == NSColorSpace.genericGray() ||
      self.colorSpace == NSColorSpace.deviceGray()) {
      return self.whiteComponent
    }

    var r : CGFloat = 0
    self.getRed(&r, green: nil , blue: nil, alpha: nil)
    return r
  }

  func getGreen() -> CGFloat {
    if (self.colorSpace == NSColorSpace.genericGray() ||
      self.colorSpace == NSColorSpace.deviceGray()) {
      return self.whiteComponent
    }

    var g : CGFloat = 0
    self.getRed(nil, green: &g , blue: nil, alpha: nil)
    return g
  }

  func getBlue() -> CGFloat {
    if (self.colorSpace == NSColorSpace.genericGray() ||
      self.colorSpace == NSColorSpace.deviceGray()) {
      return self.whiteComponent
    }

    var b : CGFloat = 0
    self.getRed(nil, green: nil , blue: &b, alpha: nil)
    return b
  }

  func getAlpha() -> CGFloat {
    if (self.colorSpace == NSColorSpace.genericGray() ||
      self.colorSpace == NSColorSpace.deviceGray()) {
      return self.alphaComponent
    }

    var a : CGFloat = 0
    self.getRed(nil, green: nil , blue: nil, alpha: &a)
    return a
  }
}

// MARK: - Blending

public extension NSColor {

  /**adds hue, saturation, and brightness to the HSB components of this color (self)*/
  public func addHue(_ hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) -> NSColor {
    var (oldHue, oldSat, oldBright, oldAlpha) : (CGFloat, CGFloat, CGFloat, CGFloat) = (0,0,0,0)
    self.getHue(&oldHue, saturation: &oldSat, brightness: &oldBright, alpha: &oldAlpha)
    return NSColor(hue: oldHue + hue, saturation: oldSat + saturation, brightness: oldBright + brightness, alpha: oldAlpha + alpha)
  }

  /**adds red, green, and blue to the RGB components of this color (self)*/
  public func addRed(_ red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) -> NSColor {
    return NSColor(red: self.getRed() + red, green: self.getGreen() + green, blue: self.getBlue() + blue, alpha: self.getAlpha() + alpha)
  }

  public func addHSB(_ color: NSColor) -> NSColor {
    var (h,s,b,a) : (CGFloat, CGFloat, CGFloat, CGFloat) = (0,0,0,0)
    color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    return self.addHue(h, saturation: s, brightness: b, alpha: 0)
  }

  public func addRGB(_ color: NSColor) -> NSColor {
    return self.addRed(color.getRed(), green: color.getGreen(), blue: color.getBlue(), alpha: 0)
  }

  public func addHSBA(_ color: NSColor) -> NSColor {
    var (h,s,b,a) : (CGFloat, CGFloat, CGFloat, CGFloat) = (0,0,0,0)
    color.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
    return self.addHue(h, saturation: s, brightness: b, alpha: a)
  }

  /**adds the rgb components of two colors*/
  public func addRGBA(_ color: NSColor) -> NSColor {
    return self.addRed(color.getRed(), green: color.getGreen(), blue: color.getBlue(), alpha: color.getAlpha())
  }
}
