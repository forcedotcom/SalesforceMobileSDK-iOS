import XCTest
@testable import SalesforceSDKCore

class MockBootConfig: BootstrappingConfig {
    var mockShouldAuthenticateOnFirstLaunch: Bool = false
    var shouldAuthenticateOnFirstLaunch: Bool {
        return mockShouldAuthenticateOnFirstLaunch
    }
}

class LoginContextTests: XCTestCase {
    func testShouldLogin_withLoginHintAndHost_returnsTrue() {
        // Given
        let context = LoginContext(
            loginHint: "hint",
            loginHost: "host",
            userAccountManager: nil,
            appConfig: nil
        )
        
        // When and Then
        XCTAssertTrue(context.shouldLogin())
    }

    func testShouldLogin_noHintOrHost_noUser_shouldAuthenticate_returnsTrue() {
        // Given
        let mockManager = MockUserAccountManager()
        mockManager.mockUserAccount = nil
        let mockConfig = MockBootConfig()
        mockConfig.mockShouldAuthenticateOnFirstLaunch = true
        let context = LoginContext(
            loginHint: nil,
            loginHost: nil,
            userAccountManager: mockManager,
            appConfig: mockConfig
        )
        
        // When and Then
        XCTAssertTrue(context.shouldLogin())
    }

    func testShouldLogin_noHintOrHost_withUser_returnsFalse() {
        // Given
        let mockManager = MockUserAccountManager()
        mockManager.mockUserAccount = UserAccount()
        let mockConfig = MockBootConfig()
        mockConfig.mockShouldAuthenticateOnFirstLaunch = true
        let context = LoginContext(
            loginHint: nil,
            loginHost: nil,
            userAccountManager: mockManager,
            appConfig: mockConfig
        )
        
        // Then and When
        XCTAssertFalse(context.shouldLogin())
    }

    func testShouldLogin_noHintOrHost_noUser_shouldAuthenticateFalse_returnsFalse() {
        // Given
        let mockManager = MockUserAccountManager()
        mockManager.mockUserAccount = nil
        let mockConfig = MockBootConfig()
        mockConfig.mockShouldAuthenticateOnFirstLaunch = false
        let context = LoginContext(
            loginHint: nil,
            loginHost: nil,
            userAccountManager: mockManager,
            appConfig: mockConfig
        )
        
        // Then and When
        XCTAssertFalse(context.shouldLogin())
    }

    func testShouldLogin_emptyStrings_returnsFalse() {
        // Given
        let context = LoginContext(
            loginHint: "",
            loginHost: "",
            userAccountManager: nil,
            appConfig: nil
        )
        
        // Then and When
        XCTAssertFalse(context.shouldLogin())
    }

    func testShouldLogin_nilManagerOrConfig_returnsFalse() {
        // Given
        let context = LoginContext(
            loginHint: nil,
            loginHost: nil,
            userAccountManager: nil,
            appConfig: nil
        )
        
        // Then and When
        XCTAssertFalse(context.shouldLogin())
    }
} 
