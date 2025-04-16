import Foundation

@objc(SFSDKNotificationCategoryFactory)
@objcMembers
public class NotificationCategoryFactory: NSObject {
    
    public static let shared = NotificationCategoryFactory()
    
    private override init() {
        super.init()
    }
    
    public func createCategories(from types: [NotificationType]) -> Set<UNNotificationCategory> {
        let categories = types.flatMap { createNotificationCategory(from: $0) }
        return Set(categories)
    }
    
    private func createNotificationCategory(from type: NotificationType) -> [UNNotificationCategory] {
        guard let actionGroups = type.actionGroups else { return [] }
        
        return actionGroups.map { group in
            let actions = createActions(from: group)
            return UNNotificationCategory(
                identifier: group.name,
                actions: actions,
                intentIdentifiers: []
            )
        }
    }
    
    private func createActions(from actionGroup: ActionGroup?) -> [UNNotificationAction] {
        guard let actionGroup = actionGroup else {
            return []
        }
        
        return actionGroup.actions.compactMap { action in
            let options: UNNotificationActionOptions = action.type == .notificationApiAction ? [.authenticationRequired] : [.foreground]
            return UNNotificationAction(
                identifier: action.identifier,
                title: action.label,
                options: options
            )
        }
    }
}
