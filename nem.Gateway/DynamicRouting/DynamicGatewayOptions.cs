namespace nem.Gateway.DynamicRouting;

public sealed class DynamicGatewayOptions
{
    public const string SectionName = "DynamicGateway";

    public string McpUrl { get; set; } = "http://localhost:5000";

    public string FederationId { get; set; } = Guid.Empty.ToString();

    public int PollIntervalSeconds { get; set; } = 30;

    public int TimeoutSeconds { get; set; } = 10;
}
