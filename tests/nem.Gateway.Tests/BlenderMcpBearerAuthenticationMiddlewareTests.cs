using Microsoft.AspNetCore.Http;
using Microsoft.Extensions.Configuration;
using nem.Gateway.Security;
using Xunit;

namespace nem.Gateway.Tests;

public sealed class BlenderMcpBearerAuthenticationMiddlewareTests
{
    [Theory]
    [InlineData("/blender-mcp/mcp")]
    [InlineData("/BLENDER-MCP/mcp")]
    [InlineData("/Blender-Mcp")]
    public async Task InvokeAsync_ReturnsUnauthorized_WhenProtectedPathHasNoBearerToken(string path)
    {
        var context = CreateContext(path);
        var middleware = CreateMiddleware("configured-token", _ => Task.CompletedTask);

        await middleware.InvokeAsync(context);

        Assert.Equal(StatusCodes.Status401Unauthorized, context.Response.StatusCode);
        Assert.Equal("Bearer", context.Response.Headers.WWWAuthenticate);
    }

    [Fact]
    public async Task InvokeAsync_ReturnsUnauthorized_WhenBearerTokenIsInvalid()
    {
        var context = CreateContext("/blender-mcp/mcp");
        context.Request.Headers.Authorization = "Bearer invalid-token";
        var middleware = CreateMiddleware("configured-token", _ => Task.CompletedTask);

        await middleware.InvokeAsync(context);

        Assert.Equal(StatusCodes.Status401Unauthorized, context.Response.StatusCode);
    }

    [Fact]
	public async Task InvokeAsync_AllowsProtectedPath_WhenBearerTokenIsValid()
    {
        var context = CreateContext("/blender-mcp/mcp");
        context.Request.Headers.Authorization = "Bearer configured-token";
        var invoked = false;
        var middleware = CreateMiddleware("configured-token", _ =>
        {
            invoked = true;
            return Task.CompletedTask;
        });

        await middleware.InvokeAsync(context);

        Assert.True(invoked);
		Assert.Equal(StatusCodes.Status200OK, context.Response.StatusCode);
	}

	[Fact]
	public async Task InvokeAsync_AllowsCaseInsensitiveBearerScheme()
	{
		var context = CreateContext("/blender-mcp/mcp");
		context.Request.Headers.Authorization = "bearer configured-token";
		var invoked = false;
		var middleware = CreateMiddleware("configured-token", _ =>
		{
			invoked = true;
			return Task.CompletedTask;
		});

		await middleware.InvokeAsync(context);

		Assert.True(invoked);
	}

    [Fact]
    public async Task InvokeAsync_FailsClosed_WhenProtectedPathHasNoConfiguredToken()
    {
        var context = CreateContext("/blender-mcp/mcp");
        context.Request.Headers.Authorization = "Bearer configured-token";
        var middleware = CreateMiddleware(null, _ => Task.CompletedTask);

        await middleware.InvokeAsync(context);

        Assert.Equal(StatusCodes.Status401Unauthorized, context.Response.StatusCode);
    }

    [Fact]
    public async Task InvokeAsync_DoesNotProtectUnrelatedPaths()
    {
        var context = CreateContext("/health");
        var invoked = false;
        var middleware = CreateMiddleware(null, _ =>
        {
            invoked = true;
            return Task.CompletedTask;
        });

        await middleware.InvokeAsync(context);

        Assert.True(invoked);
        Assert.Equal(StatusCodes.Status200OK, context.Response.StatusCode);
    }

    [Fact]
    public async Task InvokeAsync_DoesNotProtectPathsWithTheSamePrefix()
    {
        var context = CreateContext("/blender-mcp-extra");
        var invoked = false;
        var middleware = CreateMiddleware(null, _ =>
        {
            invoked = true;
            return Task.CompletedTask;
        });

        await middleware.InvokeAsync(context);

        Assert.True(invoked);
        Assert.Equal(StatusCodes.Status200OK, context.Response.StatusCode);
    }

    private static DefaultHttpContext CreateContext(string path)
    {
        var context = new DefaultHttpContext();
        context.Request.Path = path;
        return context;
    }

    private static BlenderMcpBearerAuthenticationMiddleware CreateMiddleware(string? token, RequestDelegate next)
    {
        var values = token is null
            ? new Dictionary<string, string?>()
            : new Dictionary<string, string?> { ["BlenderMcp:BearerToken"] = token };
        var configuration = new ConfigurationBuilder().AddInMemoryCollection(values).Build();
        return new BlenderMcpBearerAuthenticationMiddleware(next, configuration);
    }
}
