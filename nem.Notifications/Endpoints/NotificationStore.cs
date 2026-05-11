using System.Collections.Concurrent;
using nem.Contracts.Notifications;

namespace nem.Notifications.Endpoints;

public sealed class NotificationStore
{
    private readonly ConcurrentDictionary<string, List<NemNotification>> _store = new();

    public void Add(string userId, NemNotification notification)
    {
        _store.AddOrUpdate(
            userId,
            _ => [notification],
            (_, existing) => { existing.Add(notification); return existing; });
    }

    public IReadOnlyList<NemNotification> GetForUser(string userId)
        => _store.TryGetValue(userId, out var list) ? list.AsReadOnly() : [];
}
