using System.Net;
using Microsoft.AspNetCore.Mvc;

namespace MealPlanner.IntegrationTests.Server;

public sealed class FallbackTests
{
    [Fact]
    public async Task Unknown_api_path_returns_404_problem_details_not_html()
    {
        var cancellationToken = TestContext.Current.CancellationToken;
        await using var server = new ServerFactory();
        using var client = server.CreateClient();

        using var response = await client.GetAsync("/api/typo", cancellationToken);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        Assert.Equal("application/problem+json", response.Content.Headers.ContentType?.MediaType);
        var problem = await response.Content.ReadFromJsonAsync<ProblemDetails>(cancellationToken);
        Assert.Equal((int)HttpStatusCode.NotFound, problem?.Status);
    }

    // The other side of the test above: the fallback the API is kept out of is really there.
    [Fact]
    public async Task Unknown_app_path_returns_the_client_index_html()
    {
        var cancellationToken = TestContext.Current.CancellationToken;
        await using var server = new ServerFactory();
        using var client = server.CreateClient();

        using var response = await client.GetAsync("/family", cancellationToken);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("text/html", response.Content.Headers.ContentType?.MediaType);
        Assert.Contains("_framework/blazor.webassembly", await response.Content.ReadAsStringAsync(cancellationToken), StringComparison.Ordinal);
    }
}
