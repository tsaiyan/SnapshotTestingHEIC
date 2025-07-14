#if os(macOS)
import AVFoundation
import Cocoa
import ObjectiveC

private var nsHeicCacheKey: UInt8 = 0

extension NSImage {
    /// Returns HEIC data for the image. Result is cached per compression quality
    /// to reduce conversion overhead when snapshotting.
    func heicData(compressionQuality: CompressionQuality) -> Data? {
        if let cache = objc_getAssociatedObject(self, &nsHeicCacheKey) as? [NSNumber: Data],
           let data = cache[NSNumber(value: Float(compressionQuality.rawValue))] {
            return data
        }

        let data = NSMutableData()

        guard let imageDestination = CGImageDestinationCreateWithData(
            data, AVFileType.heic as CFString, 1, nil
        )
        else { return nil }

        guard let cgImage = cgImage(forProposedRect: nil,
                                    context: nil,
                                    hints: nil)
        else { return nil }

        let options: NSDictionary = [
            kCGImageDestinationLossyCompressionQuality: compressionQuality.rawValue
        ]

        CGImageDestinationAddImage(imageDestination, cgImage, options)

        guard CGImageDestinationFinalize(imageDestination) else { return nil }

        let result = data as Data

        var cache = objc_getAssociatedObject(self, &nsHeicCacheKey) as? [NSNumber: Data] ?? [:]
        cache[NSNumber(value: Float(compressionQuality.rawValue))] = result
        objc_setAssociatedObject(self, &nsHeicCacheKey, cache, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        return result
    }
}
#endif

