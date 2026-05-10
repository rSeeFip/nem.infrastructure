using Microsoft.Extensions.Options;
using Microsoft.Extensions.Primitives;
using Yarp.ReverseProxy.Configuration;

namespace nem.Gateway.DynamicRouting;

public sealed class DynamicFederationProxyConfigProvider(
    IHttpClientFactory httpClientFactory,
    IOptionsMonitor<DynamicGatewayOptions> optionsMonitor,
    ILogger<DynamicFederationProxyConfigProvider> logger) : BackgroundService, IProxyConfigProvider
{
    private const string RegistryClientName = "McpRegistry";
    private volatile DynamicProxyConfig _config = new([], []);

    public IProxyConfig GetConfig() => _config;

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                await RefreshConfigAsync(stoppingToken).ConfigureAwait(false);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Failed to refresh dynamic gateway routes from MCP registry.");
            }

            var delay = GetPollInterval();

            try
            {
                await Task.Delay(delay, stoppingToken).ConfigureAwait(false);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
        }
    }

    private async Task RefreshConfigAsync(CancellationToken cancellationToken)
    {
        var options = optionsMonitor.CurrentValue;
        if (!TryGetFederationId(options, out var federationId))
        {
            logger.LogWarning("Dynamic gateway routing skipped because DynamicGateway:FederationId is missing or invalid.");
            UpdateConfig([], []);
            return;
        }

        using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(cancellationToken);
        timeoutCts.CancelAfter(GetTimeout(options));

        var httpClient = httpClientFactory.CreateClient(RegistryClientName);
        var manifestsTask = httpClient.GetFromJsonAsync<List<AppRegistryManifestDto>>("/api/apps/registry", timeoutCts.Token);
        var appsTask = httpClient.GetFromJsonAsync<List<FederationAppDto>>($"/api/federations/{federationId:D}/apps", timeoutCts.Token);

        await Task.WhenAll(manifestsTask!, appsTask!).ConfigureAwait(false);

        var manifests = (await manifestsTask.ConfigureAwait(false) ?? []).ToDictionary(
            x => x.Name,
            StringComparer.OrdinalIgnoreCase);
        var apps = await appsTask.ConfigureAwait(false) ?? [];

        var clusters = new List<ClusterConfig>();
        var routes = new List<RouteConfig>();

        foreach (var app in apps)
        {
            if (!manifests.TryGetValue(app.AppName, out var manifest))
            {
                logger.LogWarning("Skipping dynamic route for app '{AppName}' because no registry manifest was found.", app.AppName);
                continue;
            }

            var normalizedBasePath = NormalizeBasePath(manifest.DefaultBasePath);
            if (string.IsNullOrWhiteSpace(normalizedBasePath))
            {
                logger.LogWarning("Skipping dynamic route for app '{AppName}' because base path '{BasePath}' is invalid for additive routing.", app.AppName, manifest.DefaultBasePath);
                continue;
            }

            var clusterId = $"dynamic-{federationId:N}-{Sanitize(app.AppName)}-cluster";
            var pathPrefix = $"/{normalizedBasePath}";

            clusters.Add(new ClusterConfig
            {
                ClusterId = clusterId,
                Destinations = new Dictionary<string, DestinationConfig>(StringComparer.OrdinalIgnoreCase)
                {
                    ["primary"] = new()
                    {
                        Address = app.AppUrl
                    }
                }
            });

            routes.Add(new RouteConfig
            {
                RouteId = $"dynamic-{federationId:N}-{Sanitize(app.AppName)}-exact-route",
                ClusterId = clusterId,
                Order = -300,
                Match = new RouteMatch
                {
                    Path = pathPrefix
                },
                Transforms =
                [
                    new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                    {
                        ["PathSet"] = "/"
                    }
                ]
            });

            routes.Add(new RouteConfig
            {
                RouteId = $"dynamic-{federationId:N}-{Sanitize(app.AppName)}-catchall-route",
                ClusterId = clusterId,
                Order = -200,
                Match = new RouteMatch
                {
                    Path = $"{pathPrefix}/{{**catch-all}}"
                },
                Transforms =
                [
                    new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
                    {
                        ["PathRemovePrefix"] = pathPrefix
                    }
                ]
            });
        }

        UpdateConfig(routes, clusters);
        logger.LogInformation("Loaded {RouteCount} dynamic routes and {ClusterCount} dynamic clusters for federation {FederationId}.", routes.Count, clusters.Count, federationId);
    }

    private void UpdateConfig(IReadOnlyList<RouteConfig> routes, IReadOnlyList<ClusterConfig> clusters)
    {
        var previous = _config;
        _config = new DynamicProxyConfig(routes, clusters);
        previous.SignalChange();
    }

    private TimeSpan GetPollInterval()
    {
        var seconds = optionsMonitor.CurrentValue.PollIntervalSeconds;
        return TimeSpan.FromSeconds(seconds <= 0 ? 30 : seconds);
    }

    private static TimeSpan GetTimeout(DynamicGatewayOptions options)
    {
        var seconds = options.TimeoutSeconds;
        return TimeSpan.FromSeconds(seconds <= 0 ? 10 : seconds);
    }

    private static bool TryGetFederationId(DynamicGatewayOptions options, out Guid federationId) =>
        Guid.TryParse(options.FederationId, out federationId) && federationId != Guid.Empty;

    private static string NormalizeBasePath(string? basePath)
    {
        if (string.IsNullOrWhiteSpace(basePath))
        {
            return string.Empty;
        }

        var trimmed = basePath.Trim();
        if (trimmed == "/")
        {
            return string.Empty;
        }

        return trimmed.Trim('/');
    }

    private static string Sanitize(string value)
    {
        Span<char> buffer = stackalloc char[value.Length];
        var index = 0;

        foreach (var character in value)
        {
            buffer[index++] = char.IsLetterOrDigit(character) ? char.ToLowerInvariant(character) : '-';
        }

        return new string(buffer[..index]).Trim('-');
    }

    private sealed class DynamicProxyConfig : IProxyConfig
    {
        private readonly CancellationTokenSource _changeToken = new();

        public DynamicProxyConfig(IReadOnlyList<RouteConfig> routes, IReadOnlyList<ClusterConfig> clusters)
        {
            Routes = routes;
            Clusters = clusters;
            ChangeToken = new CancellationChangeToken(_changeToken.Token);
        }

        public IReadOnlyList<RouteConfig> Routes { get; }

        public IReadOnlyList<ClusterConfig> Clusters { get; }

        public IChangeToken ChangeToken { get; }

        internal void SignalChange() => _changeToken.Cancel();
    }

    private sealed record FederationAppDto(
        string Id,
        string FederationId,
        string AppName,
        string AppUrl,
        string HealthCheckUrl,
        DateTimeOffset InstalledAt,
        string Status);

    private sealed record AppRegistryManifestDto(
        string Name,
        string Description,
        string Icon,
        string DefaultBasePath);
}
