using MealPlanner.ServiceDefaults;

namespace MealPlanner.Server;

/// <summary>
/// <c>mealplanner</c> without a command: the ASP.NET Core host for the WebAssembly app.
/// </summary>
internal static class ServerApp
{
    public static async Task<int> RunAsync(string[] args)
    {
        var builder = WebApplication.CreateBuilder(args);
        builder.AddServiceDefaults();

        var app = builder.Build();
        app.MapDefaultEndpoints();

        // The client's files, with index.html for every other path that isn't a file, so a
        // link to /family opens the app there (StaticWebAssetSpaFallbackEnabled in the client).
        app.MapStaticAssets();

        await app.RunAsync();
        return 0;
    }
}
