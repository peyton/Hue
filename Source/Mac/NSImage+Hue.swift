import AppKit

class CountedColor {
  let color: NSColor
  let count: Int

  init(color: NSColor, count: Int) {
    self.color = color
    self.count = count
  }
}

extension NSImage {

  private func resize(_ newSize: CGSize) -> NSImage {
    let scaledImage = NSImage(size: newSize)
    scaledImage.lockFocus()
    let ctx = NSGraphicsContext.current()
    ctx?.imageInterpolation = .high
    draw(in: NSMakeRect(0, 0, newSize.width, newSize.height), from: NSRect.zero, operation: .copy, fraction: 1)
    scaledImage.unlockFocus()
    
    return scaledImage
  }

  public func colors(_ scaleDownSize: CGSize? = nil) -> (background: NSColor, primary: NSColor, secondary: NSColor, detail: NSColor) {
    let cgImage: CGImage

    if let scaleDownSize = scaleDownSize {
      let context = NSGraphicsContext.current()
      cgImage = resize(scaleDownSize).cgImage(forProposedRect: nil, context: context, hints: nil)!
    } else {
      let context = NSGraphicsContext.current()
      let ratio = size.width / size.height
      let r_width: CGFloat = 250
      cgImage = resize(CGSize(width: r_width, height: r_width / ratio)).cgImage(forProposedRect: nil, context: context, hints: nil)!
    }

    let width = cgImage.width
    let height = cgImage.height
    let bytesPerPixel = 4
    let bytesPerRow = width * bytesPerPixel
    let bitsPerComponent = 8
    let randomColorsThreshold = Int(CGFloat(height) * 0.01)
    let blackColor = NSColor(red: 0, green: 0, blue: 0, alpha: 1)
    let whiteColor = NSColor(red: 1, green: 1, blue: 1, alpha: 1)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let raw = malloc(bytesPerRow * height)
    let bitmapInfo = CGImageAlphaInfo.premultipliedFirst.rawValue
    let context = CGContext(data: raw, width: width, height: height, bitsPerComponent: bitsPerComponent, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
    context?.draw(in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)), image: cgImage)
    let data = UnsafePointer<UInt8>(context?.data)
    let imageBackgroundColors = CountedSet(capacity: height)
    let imageColors = CountedSet(capacity: width * height)

    let sortComparator: (CountedColor, CountedColor) -> Bool = { (a, b) -> Bool in
      return a.count <= b.count
    }

    for x in 0..<width {
      for y in 0..<height {
        let pixel = ((width * y) + x) * bytesPerPixel
        let color = NSColor(
          red:   CGFloat((data?[pixel+1])!) / 255,
          green: CGFloat((data?[pixel+2])!) / 255,
          blue:  CGFloat((data?[pixel+3])!) / 255,
          alpha: 1
        )

        if x >= 5 && x <= 10 {
          imageBackgroundColors.add(color)
        }

        imageColors.add(color)
      }
    }
    
    var sortedColors = [CountedColor]()

    for color in imageBackgroundColors {
      guard let color = color as? NSColor else { continue }

      let colorCount = imageBackgroundColors.count(for: color)

      if randomColorsThreshold <= colorCount  {
        sortedColors.append(CountedColor(color: color, count: colorCount))
      }
    }

    sortedColors.sort(isOrderedBefore: sortComparator)

    var proposedEdgeColor = CountedColor(color: blackColor, count: 1)

    if let first = sortedColors.first { proposedEdgeColor = first }

    if proposedEdgeColor.color.isBlackOrWhite && !sortedColors.isEmpty {
      for countedColor in sortedColors where CGFloat(countedColor.count / proposedEdgeColor.count) > 0.3 {
        if !countedColor.color.isBlackOrWhite {
          proposedEdgeColor = countedColor
          break
        }
      }
    }

    let imageBackgroundColor = proposedEdgeColor.color
    let isDarkBackgound = imageBackgroundColor.isDark

    sortedColors.removeAll()

    for imageColor in imageColors {
      guard let imageColor = imageColor as? NSColor else { continue }

      let color = imageColor.colorWithMinimumSaturation(0.15)

      if color.isDark == !isDarkBackgound {
        let colorCount = imageColors.count(for: color)
        sortedColors.append(CountedColor(color: color, count: colorCount))
      }
    }

    sortedColors.sort(isOrderedBefore: sortComparator)

    var primaryColor, secondaryColor, detailColor: NSColor?

    for countedColor in sortedColors {
      let color = countedColor.color

      if primaryColor == nil &&
        color.isContrastingWith(imageBackgroundColor) {
          primaryColor = color
      } else if secondaryColor == nil &&
        primaryColor != nil &&
        primaryColor!.isDistinctFrom(color) &&
        color.isContrastingWith(imageBackgroundColor) {
          secondaryColor = color
      } else if secondaryColor != nil &&
        (secondaryColor!.isDistinctFrom(color) &&
          primaryColor!.isDistinctFrom(color) &&
          color.isContrastingWith(imageBackgroundColor)) {
            detailColor = color
            break
      }
    }

    free(raw)

    return (
      imageBackgroundColor,
      primaryColor   ?? (isDarkBackgound ? whiteColor : blackColor),
      secondaryColor ?? (isDarkBackgound ? whiteColor : blackColor),
      detailColor    ?? (isDarkBackgound ? whiteColor : blackColor))
  }
}
