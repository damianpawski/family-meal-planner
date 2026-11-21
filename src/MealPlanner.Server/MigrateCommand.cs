using MealPlanner.Data;
using MealPlanner.ServiceDefaults;
using Microsoft.EntityFrameworkCore;

namespace MealPlanner.Server;

/// <summary>
/// <c>mealplanner migrate</c>: applies the migrations the database doesn't have yet, then
/// exits. The AppHost runs it before the server starts (ADR 7).
/// </summary>
internal static class MigrateCommand
{
    // The database resource's name in the AppHost, which sets ConnectionStrings:mealplanner.
    private const string ConnectionStringName = "mealplanner";

    public static async Task<int> RunAsync(string[] args)
    {
        var builder = Host.CreateApplicationBuilder(args);
        builder.AddServiceDefaults();
        var connectionString = builder.Configuration.GetConnectionString(ConnectionStringName)
            ?? throw new InvalidOperationException($"ConnectionStrings:{ConnectionStringName} isn't set.");
        builder.Services.AddDbContext<MealPlannerDbContext>(options => options.UseMealPlannerDatabase(connectionString));

        // Started, not run, so the telemetry exporters are up while EF Core logs each migration.
        // Stopped even when a migration fails, so that error is flushed too.
        using var host = builder.Build();
        await host.StartAsync();
        try
        {
            // Ctrl+C stops the application, which cancels the migration.
            var stopping = host.Services.GetRequiredService<IHostApplicationLifetime>().ApplicationStopping;
            await using var scope = host.Services.CreateAsyncScope();
            await scope.ServiceProvider.GetRequiredService<MealPlannerDbContext>().Database.MigrateAsync(stopping);
        }
        finally
        {
            await host.StopAsync();
        }
        return 0;
    }
}
