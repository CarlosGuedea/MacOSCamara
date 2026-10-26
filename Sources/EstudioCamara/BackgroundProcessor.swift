import CoreImage
import CoreVideo
import Vision

final class BackgroundProcessor: @unchecked Sendable {
    private let settings: RenderSettingsStore
    private let context: CIContext
    private var cachedImageURL: URL?
    private var cachedBackground: CIImage?

    init(settings: RenderSettingsStore, context: CIContext) {
        self.settings = settings
        self.context = context
    }

    func render(_ source: CIImage, pixelBuffer: CVPixelBuffer) -> CIImage {
        let current = settings.current()
        let foreground = source.oriented(forExifOrientation: 1)
        let extent = foreground.extent
        let sceneExtent = cropRect(for: extent, to: current.aspectRatio)
        let transform = personTransform(settings: current, sceneExtent: sceneExtent)
        var composed = foreground

        switch current.kind {
        case .original:
            break
        case .blur:
            if let mask = personMask(for: pixelBuffer, extent: extent) {
                let blurred = foreground.clampedToExtent()
                    .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 24])
                    .cropped(to: extent)
                composed = blend(foreground: foreground, background: blurred, mask: mask, extent: extent, transform: transform)
            }
        case let .color(color):
            if let mask = personMask(for: pixelBuffer, extent: extent), let ciColor = CIColor(color: color) {
                let background = CIImage(color: ciColor).cropped(to: extent)
                composed = blend(foreground: foreground, background: background, mask: mask, extent: extent, transform: transform)
            }
        case let .image(url):
            let background: CIImage?
            if cachedImageURL == url {
                background = cachedBackground
            } else {
                background = CIImage(contentsOf: url, options: [.applyOrientationProperty: true])
                cachedImageURL = url
                cachedBackground = background
            }
            if let mask = personMask(for: pixelBuffer, extent: extent), let background {
                let fitted = current.backgroundFit == .fit
                    ? aspectFitWithBlur(background, to: sceneExtent)
                    : aspectFill(background, to: sceneExtent)
                composed = blend(foreground: foreground, background: fitted, mask: mask, extent: extent, transform: transform)
            }
        }
        var output = cropAndScale(composed, to: current.aspectRatio)
        output = applyEffects(output, settings: current)
        if let overlay = current.overlayImage {
            output = overlay.applyingFilter("CISourceOverCompositing", parameters: [
                kCIInputBackgroundImageKey: output
            ]).cropped(to: output.extent)
        }
        return output
    }

    private func applyEffects(_ image: CIImage, settings: RenderSettings) -> CIImage {
        var output = image.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: settings.saturation,
            kCIInputContrastKey: settings.contrast
        ])
        if settings.exposure != 0 {
            output = output.applyingFilter("CIExposureAdjust", parameters: [
                kCIInputEVKey: settings.exposure
            ])
        }
        switch settings.filter {
        case .none:
            return output
        case .vivid:
            return output.applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 1.35 * settings.saturation,
                kCIInputContrastKey: 1.08 * settings.contrast
            ])
        case .cinema:
            return output.applyingFilter("CIPhotoEffectProcess")
        case .warm:
            return output.applyingFilter("CIPhotoEffectInstant")
        case .mono:
            return output.applyingFilter("CIPhotoEffectNoir")
        }
    }

    private func cropRect(for source: CGRect, to aspectRatio: VideoAspectRatio) -> CGRect {
        let targetRatio = aspectRatio.outputSize.width / aspectRatio.outputSize.height
        let sourceRatio = source.width / source.height
        let cropSize = sourceRatio > targetRatio
            ? CGSize(width: source.height * targetRatio, height: source.height)
            : CGSize(width: source.width, height: source.width / targetRatio)
        return CGRect(
            x: source.midX - cropSize.width / 2,
            y: source.midY - cropSize.height / 2,
            width: cropSize.width,
            height: cropSize.height
        )
    }

    private func cropAndScale(_ image: CIImage, to aspectRatio: VideoAspectRatio) -> CIImage {
        let target = aspectRatio.outputSize
        let crop = cropRect(for: image.extent, to: aspectRatio)
        let centered = image.cropped(to: crop).transformed(by: CGAffineTransform(
            translationX: -crop.origin.x,
            y: -crop.origin.y
        ))
        return centered.transformed(by: CGAffineTransform(
            scaleX: target.width / crop.width,
            y: target.height / crop.height
        ))
    }

    private func personMask(for pixelBuffer: CVPixelBuffer, extent: CGRect) -> CIImage? {
        let request = VNGeneratePersonSegmentationRequest()
        request.qualityLevel = .balanced
        request.outputPixelFormat = kCVPixelFormatType_OneComponent8
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        do {
            try handler.perform([request])
            guard let result = request.results?.first else { return nil }
            let mask = CIImage(cvPixelBuffer: result.pixelBuffer)
            let scaleX = extent.width / mask.extent.width
            let scaleY = extent.height / mask.extent.height
            return mask.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
        } catch {
            return nil
        }
    }

    private func personTransform(settings: RenderSettings, sceneExtent: CGRect) -> CGAffineTransform {
        let scale = CGFloat(settings.personScale)
        let centerX = sceneExtent.midX + sceneExtent.width * CGFloat(settings.personOffsetX)
        let centerY = sceneExtent.midY + sceneExtent.height * CGFloat(settings.personOffsetY)
        return CGAffineTransform(translationX: centerX, y: centerY)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -sceneExtent.midX, y: -sceneExtent.midY)
    }

    private func blend(foreground: CIImage, background: CIImage, mask: CIImage, extent: CGRect, transform: CGAffineTransform) -> CIImage {
        foreground.transformed(by: transform).applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: background,
            kCIInputMaskImageKey: mask.transformed(by: transform)
        ]).cropped(to: extent)
    }

    private func aspectFitWithBlur(_ image: CIImage, to extent: CGRect) -> CIImage {
        let fill = aspectFill(image, to: extent)
        let blurred = fill.clampedToExtent()
            .applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 36])
            .cropped(to: extent)
        let scale = min(extent.width / image.extent.width, extent.height / image.extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let x = extent.midX - scaled.extent.midX
        let y = extent.midY - scaled.extent.midY
        let fitted = scaled.transformed(by: CGAffineTransform(translationX: x, y: y))
        return fitted.applyingFilter("CISourceOverCompositing", parameters: [
            kCIInputBackgroundImageKey: blurred
        ]).cropped(to: extent)
    }

    private func aspectFill(_ image: CIImage, to extent: CGRect) -> CIImage {
        let scale = max(extent.width / image.extent.width, extent.height / image.extent.height)
        let scaled = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let x = extent.midX - scaled.extent.midX
        let y = extent.midY - scaled.extent.midY
        return scaled.transformed(by: CGAffineTransform(translationX: x, y: y)).cropped(to: extent)
    }
}
