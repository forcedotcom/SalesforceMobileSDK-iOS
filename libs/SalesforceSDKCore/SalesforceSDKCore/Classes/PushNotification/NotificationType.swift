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
    public let type: NotificationActionType
    
    enum CodingKeys: String, CodingKey {
        case name, label, type
        case identifier = "actionKey"
    }
    
    public init(name: String, identifier: String, label: String, type: NotificationActionType) {
        self.name = name
        self.identifier = identifier
        self.label = label
        self.type = type
    }
}

@objc(SFSDKNotificationActionType)
public enum NotificationActionType: Int, Codable {
    case notificationApiAction = 0
    case foregroundAction = 1
    
    var stringValue: String {
        switch self {
        case .notificationApiAction: return "NotificationApiAction"
        case .foregroundAction: return "ForegroundAction"
        }
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "NotificationApiAction": self = .notificationApiAction
        default: self = .foregroundAction
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(stringValue)
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
