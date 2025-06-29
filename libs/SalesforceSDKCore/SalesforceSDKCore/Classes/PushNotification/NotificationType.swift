import Foundation

@objc(SFSDKNotificationTypesResponse)
@objcMembers
public class NotificationTypesResponse: NSObject, Codable {
    public let notificationTypes: [NotificationType]
    
    public init(notificationTypes: [NotificationType]) {
        self.notificationTypes = notificationTypes
    }
}

@objc(SFSDKNotificationType)
@objcMembers
public class NotificationType: NSObject, Codable {
    public let type: String
    public let apiName: String
    public let label: String
    public let actionGroups: [ActionGroup]?
    
    public init(type: String, apiName: String, label: String, actionGroups: [ActionGroup]?) {
        self.type = type
        self.apiName = apiName
        self.label = label
        self.actionGroups = actionGroups
    }
    
    /** Creates a new NotificationType with only the specified actions
     * - Parameter allowedActionTypes: Set of action types to keep
     * - Returns: A new NotificationType with filtered actions
     **/
    @objc
    public func filteredCopy(keepingActions allowedActionTypes: Set<String>) -> NotificationType {
        let filteredGroups = actionGroups?.map { group in
            let filteredActions = group.actions.filter { action in
                allowedActionTypes.contains(action.type)
            }
            return ActionGroup(name: group.name, actions: filteredActions)
        }
        return NotificationType(type: type, apiName: apiName, label: label, actionGroups: filteredGroups)
    }
    
    @objc public class func from(jsonData: Data) -> [NotificationType] {
        let decoder = JSONDecoder()
        do {
            let response = try decoder.decode(NotificationTypesResponse.self, from: jsonData)
            return response.notificationTypes
        } catch {
            SFSDKCoreLogger.e(NotificationType.self, message: "Failed to decode NotificationType: \(error)")
            return []
        }
    }
}

@objc(SFSDKActionGroup)
@objcMembers
public class ActionGroup: NSObject, Codable {
    public let name: String
    public let actions: [Action]
    
    public init(name: String, actions: [Action]) {
        self.name = name
        self.actions = actions
    }
}

@objc(SFSDKAction)
@objcMembers
public class Action: NSObject, Codable {
    public let name: String
    public let identifier: String
    public let label: String
    public let type: String
    
    enum CodingKeys: String, CodingKey {
        case name, label, type
        case identifier = "actionKey"
    }
    
    public init(name: String, identifier: String, label: String, type: String) {
        self.name = name
        self.identifier = identifier
        self.label = label
        self.type = type
    }
}

@objc(SFSDKActionResultRepresentation)
@objcMembers
public class ActionResultRepresentation: NSObject, Codable {
    public let message: String
    
    public init(message: String) {
        self.message = message
    }
}
