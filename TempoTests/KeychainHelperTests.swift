import XCTest
@testable import Tempo

final class KeychainHelperTests: XCTestCase {

    override func setUp() {
        super.setUp()
        // Clear before each test to ensure isolation.
        KeychainHelper.clearAll()
    }

    override func tearDown() {
        KeychainHelper.clearAll()
        super.tearDown()
    }

    func testSaveAndLoad() {
        KeychainHelper.save("test_token", for: .accessToken)
        XCTAssertEqual(KeychainHelper.load(.accessToken), "test_token")
    }

    func testLoadNonExistent() {
        XCTAssertNil(KeychainHelper.load(.accessToken))
        XCTAssertNil(KeychainHelper.load(.refreshToken))
    }

    func testDelete() {
        KeychainHelper.save("token", for: .accessToken)
        KeychainHelper.delete(.accessToken)
        XCTAssertNil(KeychainHelper.load(.accessToken))
    }

    func testClearAll() {
        KeychainHelper.save("access", for: .accessToken)
        KeychainHelper.save("refresh", for: .refreshToken)
        KeychainHelper.save("user@example.com", for: .userEmail)
        KeychainHelper.clearAll()
        XCTAssertNil(KeychainHelper.load(.accessToken))
        XCTAssertNil(KeychainHelper.load(.refreshToken))
        XCTAssertNil(KeychainHelper.load(.userEmail))
    }
}
