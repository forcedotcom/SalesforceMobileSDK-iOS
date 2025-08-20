import XCTest
@testable import SalesforceSDKCore

class ActionTypeTests: XCTestCase {
    func testActionTypeDecoding() throws {
        // Given
        let json = """
        {
            "name": "test",
            "actionKey": "test_key",
            "label": "Test Label",
            "type": "NotificationApiAction"
        }
        """
        let jsonData = json.data(using: .utf8)!
        // When
        let action = try JSONDecoder().decode(Action.self, from: jsonData)
        // Then
        XCTAssertEqual(action.type, "NotificationApiAction")
    }

    func testActionTypeDecodingForeground() throws {
        // Given
        let json = """
        {
            "name": "test",
            "actionKey": "test_key",
            "label": "Test Label",
            "type": "foreground"
        }
        """
        let jsonData = json.data(using: .utf8)!
        // When
        let action = try JSONDecoder().decode(Action.self, from: jsonData)
        // Then
        XCTAssertEqual(action.type, "foreground")
    }

    func testActionTypeDecodingInvalidType() throws {
        // Given
        let json = """
        {
            "name": "test",
            "actionKey": "test_key",
            "label": "Test Label",
            "invalidType": "invalidType"
        }
        """
        let jsonData = json.data(using: .utf8)!
        // When, Then
        XCTAssertThrowsError(try JSONDecoder().decode(Action.self, from: jsonData))
    }
}

extension ActionTypeTests {
    func testAction_NSSecureCoding_RoundTrip() throws {
        // Given
        let original = Action(name: "test", identifier: "test_key", label: "Test Label", type: "NotificationApiAction")
        // When
        let data = try NSKeyedArchiver.archivedData(withRootObject: original, requiringSecureCoding: true)
        let unarchived = try NSKeyedUnarchiver.unarchivedObject(ofClass: Action.self, from: data)
        // Then
        XCTAssertNotNil(unarchived)
        XCTAssertEqual(unarchived?.name, original.name)
        XCTAssertEqual(unarchived?.identifier, original.identifier)
        XCTAssertEqual(unarchived?.label, original.label)
        XCTAssertEqual(unarchived?.type, original.type)
    }

    func testActionGroup_NSSecureCoding_RoundTrip() throws {
        // Given
        let action = Action(name: "test", identifier: "test_key", label: "Test Label", type: "NotificationApiAction")
        let original = ActionGroup(name: "group1", actions: [action])
        // When
        let data = try NSKeyedArchiver.archivedData(withRootObject: original, requiringSecureCoding: true)
        let unarchived = try NSKeyedUnarchiver.unarchivedObject(ofClass: ActionGroup.self, from: data)
        // Then
        XCTAssertNotNil(unarchived)
        XCTAssertEqual(unarchived?.name, original.name)
        XCTAssertEqual(unarchived?.actions.count, 1)
        XCTAssertEqual(unarchived?.actions.first?.name, action.name)
    }

    func testNotificationType_NSSecureCoding_RoundTrip() throws {
        // Given
        let action = Action(name: "test", identifier: "test_key", label: "Test Label", type: "NotificationApiAction")
        let group = ActionGroup(name: "group1", actions: [action])
        let original = NotificationType(type: "type1", apiName: "api1", label: "Label1", actionGroups: [group])
        // When
        let data = try NSKeyedArchiver.archivedData(withRootObject: original, requiringSecureCoding: true)
        let unarchived = try NSKeyedUnarchiver.unarchivedObject(ofClass: NotificationType.self, from: data)
        // Then
        XCTAssertNotNil(unarchived)
        XCTAssertEqual(unarchived?.type, original.type)
        XCTAssertEqual(unarchived?.apiName, original.apiName)
        XCTAssertEqual(unarchived?.label, original.label)
        XCTAssertEqual(unarchived?.actionGroups?.count, 1)
        XCTAssertEqual(unarchived?.actionGroups?.first?.name, group.name)
        XCTAssertEqual(unarchived?.actionGroups?.first?.actions.first?.name, action.name)
    }
}
