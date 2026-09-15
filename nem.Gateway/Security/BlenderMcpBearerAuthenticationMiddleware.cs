using System.Net.Http.Headers;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Primitives;

namespace nem.Gateway.Security;

internal sealed class BlenderMcpBearerAuthenticationMiddleware(RequestDelegate next, IConfiguration configuration)
{
    private const string ProtectedPath = "/blender-mcp";
    private const string BearerTokenConfigurationKey = "BlenderMcp:BearerToken";

    public async Task InvokeAsync(HttpContext context)
    {
        if (!context.Request.Path.StartsWithSegments(ProtectedPath, StringComparison.OrdinalIgnoreCase))
        {
            await next(context).ConfigureAwait(false);
            return;
        }

        var expectedToken = configuration[BearerTokenConfigurationKey];
        if (!IsValidBearerToken(context.Request.Headers.Authorization, expectedToken))
        {
            context.Response.StatusCode = StatusCodes.Status401Unauthorized;
            context.Response.Headers.WWWAuthenticate = "Bearer";
            return;
        }

        await next(context).ConfigureAwait(false);
    }

    internal static bool IsValidBearerToken(StringValues authorizationHeader, string? expectedToken)
    {
        if (string.IsNullOrWhiteSpace(expectedToken) || authorizationHeader.Count != 1
            || !AuthenticationHeaderValue.TryParse(authorizationHeader[0], out var authorization)
			|| !string.Equals(authorization.Scheme, "Bearer", StringComparison.OrdinalIgnoreCase)
            || string.IsNullOrWhiteSpace(authorization.Parameter))
        {
            return false;
        }

        var expectedHash = SHA256.HashData(Encoding.UTF8.GetBytes(expectedToken));
        var suppliedHash = SHA256.HashData(Encoding.UTF8.GetBytes(authorization.Parameter));
        return CryptographicOperations.FixedTimeEquals(expectedHash, suppliedHash);
    }
}
