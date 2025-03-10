import Foundation

struct NotificationTypesResponse: Codable {
    let notificationTypes: [NotificationType]
}

public struct NotificationType: Codable {
    let type: String
    let apiName: String
    let label: String
    let actionGroups: [ActionGroup]
}

struct ActionGroup: Codable {
    let name: String
    let actions: [Action]
}

struct Action: Codable {
    let name: String
    let identifier: String
    let label: String
    let type: String
}
