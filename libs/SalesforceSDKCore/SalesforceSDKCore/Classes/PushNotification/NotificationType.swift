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
public class NotificationType: NSObject, Codable, NSSecureCoding {
    public static var supportsSecureCoding: Bool { true }
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
    
    // Required by NSSecureCoding (Objective-C protocol)
    public required convenience init?(coder aDecoder: NSCoder) {
        guard let type = aDecoder.decodeObject(of: NSString.self, forKey: "type") as String?,
              let apiName = aDecoder.decodeObject(of: NSString.self, forKey: "apiName") as String?,
              let label = aDecoder.decodeObject(of: NSString.self, forKey: "label") as String? else {
            return nil
        }
        let actionGroups = aDecoder.decodeObject(of: [NSArray.self, ActionGroup.self], forKey: "actionGroups") as? [ActionGroup]
        self.init(type: type, apiName: apiName, label: label, actionGroups: actionGroups)
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(type, forKey: "type")
        aCoder.encode(apiName, forKey: "apiName")
        aCoder.encode(label, forKey: "label")
        aCoder.encode(actionGroups, forKey: "actionGroups")
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
public class ActionGroup: NSObject, Codable, NSSecureCoding {
    public let name: String
    public let actions: [Action]
    public static var supportsSecureCoding: Bool { true }

    public init(name: String, actions: [Action]) {
        self.name = name
        self.actions = actions
    }
    
    // Required by NSSecureCoding (Objective-C protocol)
    public required convenience init?(coder aDecoder: NSCoder) {
        guard let name = aDecoder.decodeObject(of: NSString.self, forKey: "name") as String?,
              let actions = aDecoder.decodeObject(of: [NSArray.self, Action.self], forKey: "actions") as? [Action] else {
            return nil
        }
        self.init(name: name, actions: actions)
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: "name")
        aCoder.encode(actions, forKey: "actions")
    }
}

@objc(SFSDKAction)
@objcMembers
public class Action: NSObject, Codable, NSSecureCoding {
    public static var supportsSecureCoding: Bool { true }
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
    
    // Required by NSSecureCoding (Objective-C protocol)
    public required convenience init?(coder aDecoder: NSCoder) {
        guard let name = aDecoder.decodeObject(of: NSString.self, forKey: "name") as String?,
              let identifier = aDecoder.decodeObject(of: NSString.self, forKey: "identifier") as String?,
              let label = aDecoder.decodeObject(of: NSString.self, forKey: "label") as String?,
              let type = aDecoder.decodeObject(of: NSString.self, forKey: "type") as String? else {
            return nil
        }
        self.init(name: name, identifier: identifier, label: label, type: type)
    }

    public func encode(with aCoder: NSCoder) {
        aCoder.encode(name, forKey: "name")
        aCoder.encode(identifier, forKey: "identifier")
        aCoder.encode(label, forKey: "label")
        aCoder.encode(type, forKey: "type")
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
