// Use iPhone 8 for tests
import XCTest
import SnapshotTesting
import SwiftUI

@testable import SnapshotTestingHEIC

final class SnapshotTestingHEICTests: XCTestCase {

#if os(iOS)
    var sut: TestViewController!

    override func setUp() {
        super.setUp()
        sut = TestViewController()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

//    // ViewController Tests
    func test_without_HEIC() {
        assertSnapshot(of: sut, as: .image(on: .iPadPro12_9))
    }

    func test_HEIC_compressionQuality_lossless() {
        assertSnapshot(of: sut, as: .imageHEIC(on: .iPadPro12_9, compressionQuality: .lossless))
    }

    func test_HEIC_compressionQuality_medium() {
        assertSnapshot(of: sut, as: .imageHEIC(on: .iPadPro12_9, compressionQuality: .medium))
    }

    func test_HEIC_compressionQuality_maximum() {
        assertSnapshot(of: sut, as: .imageHEIC(on: .iPadPro12_9, compressionQuality: .maximum))
    }

    func test_HEIC_compressionQuality_custom() {
        assertSnapshot(of: sut, as: .imageHEIC(on: .iPadPro12_9, compressionQuality: .custom(0.75) ))
    }

    func test_HEIC_compressionQuality_custom_minus() {
        assertSnapshot(of: sut, as: .imageHEIC(on: .iPadPro12_9, compressionQuality: .custom(-20) ))
    }

    // SwiftUI Tests

    func test_swiftui_without_HEIC() {
        let view: some SwiftUI.View = SwiftUIView()

        assertSnapshot(of: view, as: .imageHEIC(layout: .device(config: .iPadPro12_9)))
    }

    func test_swiftui_HEIC_compressionQuality_lossless() {
        let view: some SwiftUI.View = SwiftUIView()

        assertSnapshot(of: view,
                        as: .imageHEIC(
                        layout: .device(config: .iPadPro12_9),
                        compressionQuality: .lossless
                        )
        )
    }

    func test_swiftui_HEIC_compressionQuality_medium() {
        let view: some SwiftUI.View = SwiftUIView()

        assertSnapshot(of: view,
                        as: .imageHEIC(
                        layout: .device(config: .iPadPro12_9),
                        compressionQuality: .medium
                       )
        )
    }

    func test_swiftui_HEIC_compressionQuality_maximum() {
        let view: some SwiftUI.View = SwiftUIView()

        assertSnapshot(of: view,
                        as: .imageHEIC(
                        layout: .device(config: .iPadPro12_9),
                        compressionQuality: .maximum
                       )
        )
    }

    func test_swiftui_HEIC_compressionQuality_custom() {
        let view: some SwiftUI.View = SwiftUIView()

        assertSnapshot(of: view,
                       as: .imageHEIC(
                        layout: .device(config: .iPadPro12_9),
                        compressionQuality: .custom(0.75)
                       )
        )
    }
#endif

}
