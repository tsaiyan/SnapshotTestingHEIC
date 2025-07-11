// Standalone helper to use HEIC snapshots with SnapshotTesting
// Copy this file into your test target to use the `.imageHEIC` strategies

import Foundation
import UIKit
import SnapshotTesting

// MARK: - HEIC Compression Quality
public enum CompressionQuality: Hashable, RawRepresentable {
    case lossless
    case low
    case medium
    case high
    case maximum
    case custom(CGFloat)

    public init?(rawValue: CGFloat) {
        switch rawValue {
        case 1.0: self = .lossless
        case 0.8: self = .low
        case 0.5: self = .medium
        case 0.2: self = .high
        case 0.0: self = .maximum
        default: self = .custom(rawValue)
        }
    }

    public var rawValue: CGFloat {
        switch self {
        case .lossless: return 1.0
        case .low: return 0.8
        case .medium: return 0.5
        case .high: return 0.2
        case .maximum: return 0.0
        case let .custom(value): return value
        }
    }
}

// MARK: - UIImage HEIC helper
@available(iOSApplicationExtension 11.0, *)
private extension UIImage {
    func heicData(compressionQuality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard
            let imageDestination = CGImageDestinationCreateWithData(
                data, AVFileType.heic as CFString, 1, nil),
            let cgImage = cgImage
        else { return nil }

        let options: NSDictionary? = compressionQuality >= 1 ? nil : [
            kCGImageDestinationLossyCompressionQuality: compressionQuality
        ]
        CGImageDestinationAddImage(imageDestination, cgImage, options)
        guard CGImageDestinationFinalize(imageDestination) else { return nil }
        return data as Data
    }
}

// MARK: - Diffing + Snapshotting for UIImage
public extension Diffing where Value == UIImage {
    static let imageHEIC = Diffing.imageHEIC()

    static func imageHEIC(
        precision: Float = 1,
        perceptualPrecision: Float = 1,
        scale: CGFloat? = nil,
        compressionQuality: CompressionQuality = .lossless
    ) -> Diffing {
        let imageScale = (scale ?? UIScreen.main.scale == 0) ? UIScreen.main.scale : (scale ?? UIScreen.main.scale)
        let emptyHeicData: Data
        if #available(iOS 17.0, *) {
            emptyHeicData = emptyImage().heicData() ?? Data()
        } else {
            emptyHeicData = Data()
        }
        return Diffing(
            toData: { $0.heicData(compressionQuality: compressionQuality.rawValue) ?? emptyHeicData },
            fromData: { UIImage(data: $0, scale: imageScale) ?? emptyImage() },
            diff: { old, new in
                guard let message = compare(old, new,
                                             precision: precision,
                                             perceptualPrecision: perceptualPrecision,
                                             compressionQuality: compressionQuality)
                else { return nil }
                let difference = diffImage(old, new)
                let oldAttachment = XCTAttachment(image: old)
                oldAttachment.name = "reference"
                let isEmptyImage = new.size == .zero
                let newAttachment = XCTAttachment(image: isEmptyImage ? emptyImage() : new)
                newAttachment.name = "failure"
                let diffAttachment = XCTAttachment(image: difference)
                diffAttachment.name = "difference"
                return (message, [oldAttachment, newAttachment, diffAttachment])
            }
        )
    }

    private static func emptyImage() -> UIImage {
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 400, height: 80))
        label.backgroundColor = .red
        label.text = """
            Error: No image could be generated for this view as its size was zero.
            Please set an explicit size in the test.
            """
        label.textAlignment = .center
        label.numberOfLines = 3
        return label.asImage()
    }
}

public extension Snapshotting where Value == UIImage, Format == UIImage {
    static var imageHEIC: Snapshotting {
        .imageHEIC()
    }

    static func imageHEIC(
        precision: Float = 1,
        perceptualPrecision: Float = 1,
        scale: CGFloat? = nil,
        compressionQuality: CompressionQuality = .lossless
    ) -> Snapshotting {
        Snapshotting(
            pathExtension: "heic",
            diffing: Diffing.imageHEIC(
                precision: precision,
                perceptualPrecision: perceptualPrecision,
                scale: scale,
                compressionQuality: compressionQuality
            )
        )
    }
}

private let imageContextColorSpace = CGColorSpace(name: CGColorSpace.sRGB)
private let imageContextBitsPerComponent = 8
private let imageContextBytesPerPixel = 4

private func compare(
    _ old: UIImage,
    _ new: UIImage,
    precision: Float,
    perceptualPrecision: Float,
    compressionQuality: CompressionQuality
) -> String? {
    guard let oldCgImage = old.cgImage else {
        return "Reference image could not be loaded."
    }
    guard let newCgImage = new.cgImage else {
        return "Newly-taken snapshot could not be loaded."
    }
    guard newCgImage.width != 0, newCgImage.height != 0 else {
        return "Newly-taken snapshot is empty."
    }
    guard oldCgImage.width == newCgImage.width, oldCgImage.height == newCgImage.height else {
        return "Newly-taken snapshot@\(new.size) does not match reference@\(old.size)."
    }
    let pixelCount = oldCgImage.width * oldCgImage.height
    let byteCount = imageContextBytesPerPixel * pixelCount
    var oldBytes = [UInt8](repeating: 0, count: byteCount)
    guard let oldData = context(for: oldCgImage, data: &oldBytes)?.data else {
        return "Reference image's data could not be loaded."
    }
    if let newContext = context(for: newCgImage), let newData = newContext.data {
        if memcmp(oldData, newData, byteCount) == 0 { return nil }
    }
    var newerBytes = [UInt8](repeating: 0, count: byteCount)
    guard
        let heicData = new.heicData(compressionQuality: compressionQuality.rawValue),
        let newerCgImage = UIImage(data: heicData)?.cgImage,
        let newerContext = context(for: newerCgImage, data: &newerBytes),
        let newerData = newerContext.data
    else {
        return "Newly-taken snapshot's data could not be loaded."
    }
    if memcmp(oldData, newerData, byteCount) == 0 { return nil }
    if precision >= 1, perceptualPrecision >= 1 {
        return "Newly-taken snapshot does not match reference."
    }
    if perceptualPrecision < 1, #available(iOS 11.0, *) {
        return perceptuallyCompare(
            CIImage(cgImage: oldCgImage),
            CIImage(cgImage: newCgImage),
            pixelPrecision: precision,
            perceptualPrecision: perceptualPrecision
        )
    } else {
        let byteCountThreshold = Int((1 - precision) * Float(byteCount))
        var differentByteCount = 0
        for offset in 0..<byteCount {
            if oldBytes[offset] != newerBytes[offset] {
                differentByteCount += 1
            }
        }
        if differentByteCount > byteCountThreshold {
            let actualPrecision = 1 - Float(differentByteCount) / Float(byteCount)
            return "Actual image precision \(actualPrecision) is less than required \(precision)"
        }
    }
    return nil
}

private func context(for cgImage: CGImage, data: UnsafeMutableRawPointer? = nil) -> CGContext? {
    let bytesPerRow = cgImage.width * imageContextBytesPerPixel
    guard
        let colorSpace = imageContextColorSpace,
        let context = CGContext(
            data: data,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: imageContextBitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    else { return nil }
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
    return context
}

private func diffImage(_ old: UIImage, _ new: UIImage) -> UIImage {
    let width = max(old.size.width, new.size.width)
    let height = max(old.size.height, new.size.height)
    let scale = max(old.scale, new.scale)
    UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), true, scale)
    new.draw(at: .zero)
    old.draw(at: .zero, blendMode: .difference, alpha: 1)
    let differenceImage = UIGraphicsGetImageFromCurrentImageContext()!
    UIGraphicsEndImageContext()
    return differenceImage
}

@available(iOS 10.0, *)
private func perceptuallyCompare(_ old: CIImage, _ new: CIImage, pixelPrecision: Float, perceptualPrecision: Float) -> String? {
    let deltaOutputImage = old.applyingFilter("CILabDeltaE", parameters: ["inputImage2": new])
    let thresholdOutputImage: CIImage
    do {
        thresholdOutputImage = try ThresholdImageProcessorKernel.apply(
            withExtent: new.extent,
            inputs: [deltaOutputImage],
            arguments: [ThresholdImageProcessorKernel.inputThresholdKey: (1 - perceptualPrecision) * 100]
        )
    } catch {
        return "Newly-taken snapshot's data could not be loaded. \(error)"
    }
    var averagePixel: Float = 0
    let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull()])
    context.render(
        thresholdOutputImage.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: new.extent]),
        toBitmap: &averagePixel,
        rowBytes: MemoryLayout<Float>.size,
        bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
        format: .Rf,
        colorSpace: nil
    )
    let actualPixelPrecision = 1 - averagePixel
    guard actualPixelPrecision < pixelPrecision else { return nil }
    var maximumDeltaE: Float = 0
    context.render(
        deltaOutputImage.applyingFilter("CIAreaMaximum", parameters: [kCIInputExtentKey: new.extent]),
        toBitmap: &maximumDeltaE,
        rowBytes: MemoryLayout<Float>.size,
        bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
        format: .Rf,
        colorSpace: nil
    )
    let actualPerceptualPrecision = 1 - maximumDeltaE / 100
    if pixelPrecision < 1 {
        return """
    Actual image precision \(actualPixelPrecision) is less than required \(pixelPrecision)
    Actual perceptual precision \(actualPerceptualPrecision) is less than required \(perceptualPrecision)
    """
    } else {
        return "Actual perceptual precision \(actualPerceptualPrecision) is less than required \(perceptualPrecision)"
    }
}

@available(iOS 10.0, *)
private final class ThresholdImageProcessorKernel: CIImageProcessorKernel {
    static let inputThresholdKey = "thresholdValue"
    static let device = MTLCreateSystemDefaultDevice()

    override class func process(with inputs: [CIImageProcessorInput]?, arguments: [String : Any]?, output: CIImageProcessorOutput) throws {
        guard
            let device = device,
            let commandBuffer = output.metalCommandBuffer,
            let input = inputs?.first,
            let sourceTexture = input.metalTexture,
            let destinationTexture = output.metalTexture,
            let thresholdValue = arguments?[inputThresholdKey] as? Float else {
            return
        }
        let threshold = MPSImageThresholdBinary(
            device: device,
            thresholdValue: thresholdValue,
            maximumValue: 1.0,
            linearGrayColorTransform: nil
        )
        threshold.encode(
            commandBuffer: commandBuffer,
            sourceTexture: sourceTexture,
            destinationTexture: destinationTexture
        )
    }
}

extension UIView {
    func asImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
}

// MARK: - Snapshotting for UIView and UIViewController
public extension Snapshotting where Value == UIView, Format == UIImage {
    static var imageHEIC: Snapshotting { .imageHEIC() }

    static func imageHEIC(
        drawHierarchyInKeyWindow: Bool = false,
        precision: Float = 1,
        perceptualPrecision: Float = 1,
        size: CGSize? = nil,
        traits: UITraitCollection = .init(),
        compressionQuality: CompressionQuality = .lossless
    ) -> Snapshotting {
        let base = Snapshotting<UIView, UIImage>.image(
            drawHierarchyInKeyWindow: drawHierarchyInKeyWindow,
            precision: precision,
            perceptualPrecision: perceptualPrecision,
            size: size,
            traits: traits
        )
        return Snapshotting<UIView, UIImage>(
            pathExtension: "heic",
            diffing: Diffing.imageHEIC(
                precision: precision,
                perceptualPrecision: perceptualPrecision,
                scale: traits.displayScale,
                compressionQuality: compressionQuality
            ),
            asyncSnapshot: base.snapshot
        )
    }
}

public extension Snapshotting where Value == UIViewController, Format == UIImage {
    static var imageHEIC: Snapshotting { .imageHEIC() }

    static func imageHEIC(
        on config: ViewImageConfig,
        precision: Float = 1,
        perceptualPrecision: Float = 1,
        size: CGSize? = nil,
        traits: UITraitCollection = .init(),
        compressionQuality: CompressionQuality = .lossless
    ) -> Snapshotting {
        let base = Snapshotting<UIViewController, UIImage>.image(
            on: config,
            precision: precision,
            perceptualPrecision: perceptualPrecision,
            size: size,
            traits: traits
        )
        return Snapshotting<UIViewController, UIImage>(
            pathExtension: "heic",
            diffing: Diffing.imageHEIC(
                precision: precision,
                perceptualPrecision: perceptualPrecision,
                scale: traits.displayScale,
                compressionQuality: compressionQuality
            ),
            asyncSnapshot: base.snapshot
        )
    }

    static func imageHEIC(
        drawHierarchyInKeyWindow: Bool = false,
        precision: Float = 1,
        perceptualPrecision: Float = 1,
        size: CGSize? = nil,
        traits: UITraitCollection = .init(),
        compressionQuality: CompressionQuality = .lossless
    ) -> Snapshotting {
        let base = Snapshotting<UIViewController, UIImage>.image(
            drawHierarchyInKeyWindow: drawHierarchyInKeyWindow,
            precision: precision,
            perceptualPrecision: perceptualPrecision,
            size: size,
            traits: traits
        )
        return Snapshotting<UIViewController, UIImage>(
            pathExtension: "heic",
            diffing: Diffing.imageHEIC(
                precision: precision,
                perceptualPrecision: perceptualPrecision,
                scale: traits.displayScale,
                compressionQuality: compressionQuality
            ),
            asyncSnapshot: base.snapshot
        )
    }
}

#if canImport(SwiftUI)
import SwiftUI
@available(iOS 13.0, *)
public extension Snapshotting where Value: SwiftUI.View, Format == UIImage {
    static var imageHEIC: Snapshotting {
        .imageHEIC()
    }

    static func imageHEIC(
        drawHierarchyInKeyWindow: Bool = false,
        precision: Float = 1,
        perceptualPrecision: Float = 1,
        layout: SwiftUISnapshotLayout = .sizeThatFits,
        traits: UITraitCollection = .init(),
        compressionQuality: CompressionQuality = .lossless
    ) -> Snapshotting {
        let base = Snapshotting<Value, UIImage>.image(
            drawHierarchyInKeyWindow: drawHierarchyInKeyWindow,
            precision: precision,
            perceptualPrecision: perceptualPrecision,
            layout: layout,
            traits: traits
        )
        return Snapshotting<Value, UIImage>(
            pathExtension: "heic",
            diffing: Diffing.imageHEIC(
                precision: precision,
                perceptualPrecision: perceptualPrecision,
                scale: traits.displayScale,
                compressionQuality: compressionQuality
            ),
            asyncSnapshot: base.snapshot
        )
    }
}
#endif
