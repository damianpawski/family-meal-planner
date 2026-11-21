using MealPlanner.Server.Features.Diagnostics.Ping;
using MealPlanner.ServiceDefaults;

namespace MealPlanner.Server;

/// <summary>
/// <c>mealplanner</c> without a command: the ASP.NET Core host for the API and the
/// WebAssembly app.
/// </summary>
internal static class ServerApp
{
    public static async Task<int> RunAsync(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);
        builder.AddServiceDefaults();
        builder.Services.AddProblemDetails();
        // The only way the server reads the clock (architecture §2), so tests can set it.
        builder.Services.AddSingleton(TimeProvider.System);

        var app = builder.Build();
        app.MapDefaultEndpoints();

        var api = app.MapGroup("/api");
        api.MapPing();
        // Without this, the client's fallback below would answer a mistyped API path with
        // index.html and a 200, which a caller would take as success.
        api.MapFallback("{**path}", () => Results.Problem(statusCode: StatusCodes.Status404NotFound));

        // The client's files, with index.html for every other path that isn't a file, so a
        // link to /family opens the app there (StaticWebAssetSpaFallbackEnabled in the client).
        app.MapStaticAssets();

        await app.RunAsync();
        return 0;
    }
}
