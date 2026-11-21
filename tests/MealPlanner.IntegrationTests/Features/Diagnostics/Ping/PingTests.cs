using System.Net;
using System.Reflection;
using MealPlanner.Server.Features.Diagnostics.Ping;

namespace MealPlanner.IntegrationTests.Features.Diagnostics.Ping;

public sealed class PingTests
{
    [Fact]
    public async Task Ping_returns_200_with_the_version_and_server_time()
    {
        var cancellationToken = TestContext.Current.CancellationToken;
        var now = new DateTimeOffset(2026, 9, 12, 18, 59, 30, TimeSpan.Zero);
        await using var server = new ServerFactory(new FixedClock(now));
        using var client = server.CreateClient();

        using var response = await client.GetAsync("/api/ping", cancellationToken);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var ping = await response.Content.ReadFromJsonAsync<PingResponse>(cancellationToken);
        var serverVersion = typeof(PingResponse).Assembly.GetCustomAttribute<AssemblyInformationalVersionAttribute>()!.InformationalVersion;
        Assert.Equal(new PingResponse(serverVersion, now), ping);
    }

    private sealed class FixedClock(DateTimeOffset now) : TimeProvider
    {
        public override DateTimeOffset GetUtcNow() => now;
    }
}
