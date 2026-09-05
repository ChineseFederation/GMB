import Foundation
import XCTest
@testable import CitizenSDK

final class CitizenSDKNativeAbiTests: XCTestCase {
    func testImportedCoreAbiStructuresAreVersioned() {
        XCTAssertGreaterThan(MemoryLayout<citizensdk_create_options_t>.size, 0)
        XCTAssertGreaterThan(MemoryLayout<citizensdk_host_services_v1_t>.size, 0)
        XCTAssertGreaterThan(MemoryLayout<citizensdk_event_t>.size, 0)
        XCTAssertEqual(citizenSDKHostBytesWrappedDEK, 1)
    }

    func testHeaderExportsExactlySeventyThreeUniqueCitizenSdkSymbols() throws {
        let testFile = URL(fileURLWithPath: #filePath)
        let sdkRoot = testFile.deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let header = sdkRoot.appendingPathComponent("include/citizensdk.h")
        let source = try String(contentsOf: header, encoding: .utf8)
        let regex = try NSRegularExpression(pattern: #"\bcitizensdk_[a-z0-9_]+\s*\("#)
        let range = NSRange(source.startIndex..<source.endIndex, in: source)
        let names = Set(regex.matches(in: source, range: range).compactMap { match -> String? in
            guard let swiftRange = Range(match.range, in: source) else { return nil }
            return source[swiftRange].split(separator: "(").first.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        })
        XCTAssertEqual(names.count, 73)
    }
}
