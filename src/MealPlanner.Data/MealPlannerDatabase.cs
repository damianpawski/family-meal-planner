using Microsoft.EntityFrameworkCore;

namespace MealPlanner.Data;

public static class MealPlannerDatabase
{
    public const string MigrationsHistoryTable = "__ef_migrations_history";

    /// <summary>
    /// The one place the database connection is configured, so the server, the mealplanner
    /// commands and the tests can't configure it differently. Names in the database are
    /// snake_case, so hand-written SQL needs no quoted identifiers (ADR 13).
    /// </summary>
    public static DbContextOptionsBuilder UseMealPlannerDatabase(this DbContextOptionsBuilder options, string connectionString) =>
        options
            .UseNpgsql(connectionString, npgsql => npgsql.MigrationsHistoryTable(MigrationsHistoryTable))
            .UseSnakeCaseNamingConvention();
}
