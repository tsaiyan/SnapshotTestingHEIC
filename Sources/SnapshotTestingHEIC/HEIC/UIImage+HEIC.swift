#if os(iOS) || os(tvOS)
import AVFoundation
import UIKit
import ObjectiveC

@available(tvOSApplicationExtension 11.0, *)
private var heicCacheKey: UInt8 = 0

extension UIImage {
    /// Returns HEIC data for the image. Result is cached per compression quality
    /// to avoid repeated expensive conversions during snapshot tests.
    func heicData(compressionQuality: CGFloat) -> Data? {

        // Retrieve cached data if available
        if let cache = objc_getAssociatedObject(self, &heicCacheKey) as? [NSNumber: Data],
           let data = cache[NSNumber(value: Float(compressionQuality))] {
            return data
        }

        let data = NSMutableData()

        guard let imageDestination = CGImageDestinationCreateWithData(
            data, AVFileType.heic as CFString, 1, nil
        )
        else { return nil }

        guard let cgImage = cgImage else { return nil }

        let options: NSDictionary? = compressionQuality >= 1
            ? nil
            : [kCGImageDestinationLossyCompressionQuality: compressionQuality]

        CGImageDestinationAddImage(imageDestination, cgImage, options)

        guard CGImageDestinationFinalize(imageDestination) else { return nil }

        let result = data as Data

        // Cache result for subsequent calls
        var cache = objc_getAssociatedObject(self, &heicCacheKey) as? [NSNumber: Data] ?? [:]
        cache[NSNumber(value: Float(compressionQuality))] = result
        objc_setAssociatedObject(self, &heicCacheKey, cache, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)

        return result
    }
}
#endif
