using nem.Contracts.Notifications;

namespace nem.Notifications.Handlers;

public static class SendNotificationHandler
{
    public static void Handle(NemNotification notification, ILogger logger)
    {
        logger.LogInformation(
            "Notification dispatched: {Type} - {Title} (channel: {Channel})",
            notification.Type,
            notification.Title,
            notification.Channel ?? "global");
    }
}
