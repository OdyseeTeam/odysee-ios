import XCTest
@testable import Odysee

final class OdyseeTests: XCTestCase {
    
    func testServerURL() throws {
        
        XCTAssertEqual(OdyseeServer.production.rawValue, "https://odysee.com")
    }
}
