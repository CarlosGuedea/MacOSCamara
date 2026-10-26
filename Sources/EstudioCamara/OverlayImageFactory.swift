import AppKit
import CoreImage

@MainActor
enum OverlayImageFactory {
    static func make(text: String, position: OverlayPosition, scale: Double, aspectRatio: VideoAspectRatio) -> CIImage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let canvas = aspectRatio.outputSize
        let fontSize = min(canvas.width, canvas.height) * 0.068 * CGFloat(scale)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        paragraph.lineBreakMode = .byWordWrapping
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.65)
        shadow.shadowBlurRadius = 8
        shadow.shadowOffset = CGSize(width: 0, height: 2)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph,
            .shadow: shadow
        ]
        let string = NSAttributedString(string: trimmed, attributes: attributes)
        let maxWidth = canvas.width * 0.84
        let bounds = string.boundingRect(
            with: CGSize(width: maxWidth, height: canvas.height * 0.5),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let textSize = CGSize(width: ceil(bounds.width), height: ceil(bounds.height))
        let margin = min(canvas.width, canvas.height) * 0.07
        let y: CGFloat
        switch position {
        case .top: y = canvas.height - margin - textSize.height
        case .center: y = (canvas.height - textSize.height) / 2
        case .bottom: y = margin
        }
        let textRect = CGRect(origin: CGPoint(x: (canvas.width - textSize.width) / 2, y: y), size: textSize)
        let image = NSImage(size: canvas)
        image.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        let paddingX = fontSize * 0.42
        let paddingY = fontSize * 0.24
        let capsule = CGRect(
            x: max(18, textRect.minX - paddingX),
            y: textRect.minY - paddingY,
            width: min(canvas.width - 36, textRect.width + paddingX * 2),
            height: textRect.height + paddingY * 2
        )
        NSColor.black.withAlphaComponent(0.38).setFill()
        NSBezierPath(roundedRect: capsule, xRadius: capsule.height * 0.28, yRadius: capsule.height * 0.28).fill()
        string.draw(in: textRect)
        image.unlockFocus()
        guard let data = image.tiffRepresentation else { return nil }
        return CIImage(data: data)
    }
}
