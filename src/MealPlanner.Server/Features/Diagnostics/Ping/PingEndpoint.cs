using System.Reflection;

namespace MealPlanner.Server.Features.Diagnostics.Ping;

public sealed record PingResponse(string Version, DateTimeOffset ServerTime);

/// <summary>
/// <c>GET /api/ping</c>: the server's version and clock, to check a phone reaches the server
/// it should and to see how far apart the two clocks are.
/// </summary>
internal static class PingEndpoint
{
    private static readonly string Version =
        typeof(PingEndpoint).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()!.InformationalVersion;

    public static IEndpointRouteBuilder MapPing(this IEndpointRouteBuilder api)
    {
        api.MapGet("/ping", (TimeProvider clock) => new PingResponse(Version, clock.GetUtcNow()));
        return api;
    }
}
