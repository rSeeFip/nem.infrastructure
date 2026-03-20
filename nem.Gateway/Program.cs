using Microsoft.AspNetCore.HttpOverrides;
using nem.Contracts.AspNetCore.Cors;
using nem.Contracts.AspNetCore.Security;

var builder = WebApplication.CreateBuilder(args);

var gatewayConfigPath = Path.GetFullPath(Path.Combine(builder.Environment.ContentRootPath, "..", "yarp-gateway.json"));

builder.Configuration
    .AddJsonFile(gatewayConfigPath, optional: false, reloadOnChange: true)
    .AddInMemoryCollection(BuildClusterAddressOverrides());

builder.WebHost.UseUrls($"http://0.0.0.0:{GetSetting("GATEWAY_PORT", "8090")}");

builder.Services.AddHealthChecks();
builder.Services.AddNemSecurityHeaders();
builder.Services.AddNemCors(builder.Configuration, NemCorsProfile.NemPublic);

builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor
        | ForwardedHeaders.XForwardedHost
        | ForwardedHeaders.XForwardedProto;
    options.KnownIPNetworks.Clear();
    options.KnownProxies.Clear();
});

var reverseProxyBuilder = AddReverseProxy(builder.Services);
LoadFromConfig(reverseProxyBuilder, builder.Configuration.GetSection("ReverseProxy"));

var app = builder.Build();

app.UseForwardedHeaders();
app.UseNemSecurityHeaders();

if (app.Environment.IsDevelopment())
{
    app.UseCors(NemCorsExtensions.PolicyName);
}

app.UseWebSockets();

app.MapHealthChecks("/health");
MapReverseProxy(app);

app.Run();

static object AddReverseProxy(Microsoft.Extensions.DependencyInjection.IServiceCollection services)
{
    var extensionsType = GetRequiredType("Microsoft.Extensions.DependencyInjection.ReverseProxyServiceCollectionExtensions");
    var addReverseProxyMethod = extensionsType.GetMethod(
        "AddReverseProxy",
        System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Static,
        binder: null,
        types: [typeof(Microsoft.Extensions.DependencyInjection.IServiceCollection)],
        modifiers: null)
        ?? throw new InvalidOperationException("Could not find YARP AddReverseProxy(IServiceCollection) method.");

    return addReverseProxyMethod.Invoke(null, [services])
        ?? throw new InvalidOperationException("YARP AddReverseProxy(IServiceCollection) returned null.");
}

static void LoadFromConfig(object reverseProxyBuilder, Microsoft.Extensions.Configuration.IConfigurationSection configurationSection)
{
    var extensionsType = GetRequiredType("Microsoft.Extensions.DependencyInjection.ReverseProxyServiceCollectionExtensions");
    var reverseProxyBuilderType = GetRequiredType("Microsoft.Extensions.DependencyInjection.IReverseProxyBuilder");
    var loadFromConfigMethod = extensionsType.GetMethod(
        "LoadFromConfig",
        System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Static,
        binder: null,
        types: [reverseProxyBuilderType, typeof(Microsoft.Extensions.Configuration.IConfiguration)],
        modifiers: null)
        ?? throw new InvalidOperationException("Could not find YARP LoadFromConfig(IReverseProxyBuilder, IConfiguration) method.");

    _ = loadFromConfigMethod.Invoke(null, [reverseProxyBuilder, configurationSection])
        ?? throw new InvalidOperationException("YARP LoadFromConfig returned null.");
}

static void MapReverseProxy(Microsoft.AspNetCore.Routing.IEndpointRouteBuilder endpointRouteBuilder)
{
    var extensionsType = GetRequiredType("Microsoft.AspNetCore.Builder.ReverseProxyIEndpointRouteBuilderExtensions");
    var mapReverseProxyMethod = extensionsType.GetMethod(
        "MapReverseProxy",
        System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Static,
        binder: null,
        types: [typeof(Microsoft.AspNetCore.Routing.IEndpointRouteBuilder)],
        modifiers: null)
        ?? throw new InvalidOperationException("Could not find YARP MapReverseProxy(IEndpointRouteBuilder) method.");

    _ = mapReverseProxyMethod.Invoke(null, [endpointRouteBuilder])
        ?? throw new InvalidOperationException("YARP MapReverseProxy returned null.");
}

static System.Type GetRequiredType(string fullTypeName)
{
    return Type.GetType($"{fullTypeName}, Yarp.ReverseProxy")
        ?? throw new InvalidOperationException($"Could not load required YARP type '{fullTypeName}'.");
}

static Dictionary<string, string?> BuildClusterAddressOverrides()
{
    return new Dictionary<string, string?>
    {
        ["ReverseProxy:Clusters:mcp-cluster:Destinations:primary:Address"] = GetSetting("MCP_CLUSTER_ADDRESS", "http://localhost:5254"),
        ["ReverseProxy:Clusters:knowhub-cluster:Destinations:primary:Address"] = GetSetting("KNOWHUB_CLUSTER_ADDRESS", "http://localhost:5001"),
        ["ReverseProxy:Clusters:holisticworld-cluster:Destinations:primary:Address"] = GetSetting("HOLISTICWORLD_CLUSTER_ADDRESS", "http://localhost:5002"),
        ["ReverseProxy:Clusters:assetcore-cluster:Destinations:primary:Address"] = GetSetting("ASSETCORE_CLUSTER_ADDRESS", "http://localhost:5003"),
        ["ReverseProxy:Clusters:mediahub-cluster:Destinations:primary:Address"] = GetSetting("MEDIAHUB_CLUSTER_ADDRESS", "http://localhost:5004"),
        ["ReverseProxy:Clusters:shell-cluster:Destinations:primary:Address"] = GetSetting("SHELL_CLUSTER_ADDRESS", "http://localhost:3000"),
        ["ReverseProxy:Clusters:cognitive-cluster:Destinations:primary:Address"] = GetSetting("COGNITIVE_CLUSTER_ADDRESS", "http://localhost:3001"),
        ["ReverseProxy:Clusters:knowhub-frontend-cluster:Destinations:primary:Address"] = GetSetting("KNOWHUB_FRONTEND_CLUSTER_ADDRESS", "http://localhost:3002"),
        ["ReverseProxy:Clusters:mcp-frontend-cluster:Destinations:primary:Address"] = GetSetting("MCP_FRONTEND_CLUSTER_ADDRESS", "http://localhost:3003"),
        ["ReverseProxy:Clusters:assetcore-frontend-cluster:Destinations:primary:Address"] = GetSetting("ASSETCORE_FRONTEND_CLUSTER_ADDRESS", "http://localhost:3004"),
        ["ReverseProxy:Clusters:mimir-cluster:Destinations:primary:Address"] = GetSetting("MIMIR_CLUSTER_ADDRESS", "http://localhost:3005"),
        ["ReverseProxy:Clusters:world-cluster:Destinations:primary:Address"] = GetSetting("WORLD_CLUSTER_ADDRESS", "http://localhost:3006"),
        ["ReverseProxy:Clusters:mediahub-frontend-cluster:Destinations:primary:Address"] = GetSetting("MEDIAHUB_FRONTEND_CLUSTER_ADDRESS", "http://localhost:3007"),
        ["ReverseProxy:Clusters:home-cluster:Destinations:primary:Address"] = GetSetting("HOME_CLUSTER_ADDRESS", "http://localhost:3008"),
        ["ReverseProxy:Clusters:scheduler-cluster:Destinations:primary:Address"] = GetSetting("SCHEDULER_CLUSTER_ADDRESS", "http://localhost:3009")
    };
}

static string GetSetting(string key, string defaultValue)
{
    var value = Environment.GetEnvironmentVariable(key);
    return string.IsNullOrWhiteSpace(value) ? defaultValue : value;
}
