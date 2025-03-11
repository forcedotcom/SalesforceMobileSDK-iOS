import Foundation

@objcMembers
public class NotificationTypesResponse: NSObject, Codable {
    public let notificationTypes: [NotificationType]

    public init(notificationTypes: [NotificationType]) {
        self.notificationTypes = notificationTypes
    }
}

@objcMembers
public class NotificationType: NSObject, Codable {
    public let type: String
    public let apiName: String
    public let label: String
    public let actionGroups: [ActionGroup]

    public init(type: String, apiName: String, label: String, actionGroups: [ActionGroup]) {
        self.type = type
        self.apiName = apiName
        self.label = label
        self.actionGroups = actionGroups
    }

    @objc public class func from(jsonData: Data) -> [NotificationType] {
        let decoder = JSONDecoder()
        do {
            let response = try decoder.decode(NotificationTypesResponse.self, from: jsonData)
            return response.notificationTypes
        } catch {
            print("Failed to decode NotificationType: \(error)")
            return []
        }
    }
}

@objcMembers
public class ActionGroup: NSObject, Codable {
    public let name: String
    public let actions: [Action]

    public init(name: String, actions: [Action]) {
        self.name = name
        self.actions = actions
    }
}

@objcMembers
public class Action: NSObject, Codable {
    public let name: String
    public let identifier: String
    public let label: String
    public let type: String

    public init(name: String, identifier: String, label: String, type: String) {
        self.name = name
        self.identifier = identifier
        self.label = label
        self.type = type
    }
}
