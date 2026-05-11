using nem.Contracts.Notifications;
using Wolverine;

namespace nem.Notifications.Endpoints;

public static class NotificationsEndpoints
{
    public static IEndpointRouteBuilder MapNotificationsEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/notifications", async (
            SendNotificationRequest request,
            IMessageBus bus,
            NotificationStore store) =>
        {
            var notification = new NemNotification
            {
                Type = request.Type,
                Title = request.Title,
                Body = request.Body,
                Channel = request.UserId,
                Data = request.Data
            };

            if (request.UserId is not null)
                store.Add(request.UserId, notification);

            await bus.PublishAsync(notification);

            return Results.Accepted();
        });

        app.MapGet("/api/notifications/{userId}", (string userId, NotificationStore store) =>
        {
            var notifications = store.GetForUser(userId);
            return Results.Ok(notifications);
        });

        return app;
    }
}

public sealed record SendNotificationRequest(
    NotificationType Type,
    string Title,
    string Body,
    string? UserId,
    IDictionary<string, object>? Data);
