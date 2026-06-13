using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace nem.Gateway.Authorization;

public sealed class OpaAppRegistryFilter(
    IHttpClientFactory httpClientFactory,
    ILogger<OpaAppRegistryFilter> logger) : IMiddleware
{
    private const string RegistryPath = "/api/apps/registry";
    private const string UserRolesHeader = "X-User-Roles";
    private const string OpaClientName = "OpaClient";

    private static readonly JsonSerializerOptions JsonOptions = new(JsonSerializerDefaults.Web);

    public async Task InvokeAsync(HttpContext context, RequestDelegate next)
    {
        if (!IsRegistryRequest(context))
        {
            await next(context).ConfigureAwait(false);
            return;
        }

        var originalBody = context.Response.Body;
        using var bufferedBody = new MemoryStream();
        context.Response.Body = bufferedBody;

        try
        {
            await next(context).ConfigureAwait(false);

            if (context.Response.StatusCode != StatusCodes.Status200OK ||
                !IsJsonContentType(context.Response.ContentType))
            {
                bufferedBody.Seek(0, SeekOrigin.Begin);
                await bufferedBody.CopyToAsync(originalBody).ConfigureAwait(false);
                return;
            }

            bufferedBody.Seek(0, SeekOrigin.Begin);
            var responseJson = await new StreamReader(bufferedBody).ReadToEndAsync().ConfigureAwait(false);

            var apps = JsonSerializer.Deserialize<List<AppRegistryEntry>>(responseJson, JsonOptions);
            if (apps is null or { Count: 0 })
            {
                await WriteResponseAsync(originalBody, context.Response, responseJson).ConfigureAwait(false);
                return;
            }

            var userRoles = ParseUserRoles(context.Request.Headers[UserRolesHeader].ToString());
            var filteredApps = await FilterAppsByOpaAsync(apps, userRoles, context.RequestAborted).ConfigureAwait(false);

            var filteredJson = JsonSerializer.Serialize(filteredApps, JsonOptions);
            await WriteResponseAsync(originalBody, context.Response, filteredJson).ConfigureAwait(false);
        }
        finally
        {
            context.Response.Body = originalBody;
        }
    }

    private async Task<List<AppRegistryEntry>> FilterAppsByOpaAsync(
        List<AppRegistryEntry> apps,
        string[] userRoles,
        CancellationToken cancellationToken)
    {
        var httpClient = httpClientFactory.CreateClient(OpaClientName);
        var filtered = new List<AppRegistryEntry>(apps.Count);

        foreach (var app in apps)
        {
            var allowed = await IsAllowedByOpaAsync(httpClient, app.Name, userRoles, cancellationToken).ConfigureAwait(false);
            if (allowed)
            {
                filtered.Add(app);
            }
        }

        return filtered;
    }

    private async Task<bool> IsAllowedByOpaAsync(
        HttpClient httpClient,
        string appId,
        string[] userRoles,
        CancellationToken cancellationToken)
    {
        try
        {
            var request = new OpaRequest(new OpaInput(appId, userRoles));
            using var response = await httpClient
                .PostAsJsonAsync("/v1/data/nem/app_registry/allow", request, JsonOptions, cancellationToken)
                .ConfigureAwait(false);

            if (!response.IsSuccessStatusCode)
            {
                logger.LogWarning(
                    "OPA returned non-success status {StatusCode} for app '{AppId}'. Failing open.",
                    (int)response.StatusCode,
                    appId);
                return true; // fail open
            }

            var result = await response.Content
                .ReadFromJsonAsync<OpaResult>(JsonOptions, cancellationToken)
                .ConfigureAwait(false);

            return result?.Result ?? true; // fail open if result is null
        }
        catch (HttpRequestException ex)
        {
            logger.LogWarning(ex, "OPA is unavailable when checking app '{AppId}'. Failing open.", appId);
            return true; // fail open — OPA unreachable
        }
        catch (TaskCanceledException ex) when (!cancellationToken.IsCancellationRequested)
        {
            logger.LogWarning(ex, "OPA request timed out for app '{AppId}'. Failing open.", appId);
            return true; // fail open — timeout
        }
    }

    private static bool IsRegistryRequest(HttpContext context) =>
        context.Request.Method.Equals(HttpMethods.Get, StringComparison.OrdinalIgnoreCase) &&
        context.Request.Path.StartsWithSegments(RegistryPath, StringComparison.OrdinalIgnoreCase);

    private static bool IsJsonContentType(string? contentType) =>
        contentType is not null &&
        contentType.Contains("application/json", StringComparison.OrdinalIgnoreCase);

    private static string[] ParseUserRoles(string headerValue) =>
        string.IsNullOrWhiteSpace(headerValue)
            ? []
            : headerValue
                .Split(',', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

    private static async Task WriteResponseAsync(Stream destination, HttpResponse response, string json)
    {
        var bytes = System.Text.Encoding.UTF8.GetBytes(json);
        response.ContentLength = bytes.Length;
        await destination.WriteAsync(bytes).ConfigureAwait(false);
    }

    // Minimal DTO — only the field used as app_id in OPA
    private sealed record AppRegistryEntry(
        [property: JsonPropertyName("name")] string Name)
    {
        [JsonExtensionData]
        public Dictionary<string, JsonElement>? Extra { get; init; }
    }

    private sealed record OpaRequest(
        [property: JsonPropertyName("input")] OpaInput Input);

    private sealed record OpaInput(
        [property: JsonPropertyName("app_id")] string AppId,
        [property: JsonPropertyName("user_roles")] string[] UserRoles);

    private sealed record OpaResult(
        [property: JsonPropertyName("result")] bool? Result);
}

/// <summary>
/// Extension methods for registering OPA app registry filtering.
/// </summary>
public static class OpaAppRegistryFilterExtensions
{
    private const string OpaClientName = "OpaClient";

    public static IServiceCollection AddOpaAppRegistryFilter(
        this IServiceCollection services,
        string opaBaseUrl = "http://localhost:8181")
    {
        services.AddHttpClient(OpaClientName, client =>
        {
            client.BaseAddress = new Uri(opaBaseUrl, UriKind.Absolute);
            client.Timeout = TimeSpan.FromSeconds(5);
        });

        services.AddScoped<OpaAppRegistryFilter>();

        return services;
    }

    public static IApplicationBuilder UseOpaAppRegistryFilter(this IApplicationBuilder app) =>
        app.UseMiddleware<OpaAppRegistryFilter>();
}
