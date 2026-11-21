using MealPlanner.Data;
using MealPlanner.IntegrationTests;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using Testcontainers.PostgreSql;

[assembly: AssemblyFixture(typeof(PostgresFixture))]

namespace MealPlanner.IntegrationTests;

/// <summary>
/// One Postgres container for the whole test run, on the same image as the AppHost. The
/// fixture migrates the app's database itself, as the server never changes the schema (D6).
/// </summary>
public sealed class PostgresFixture : IAsyncLifetime
{
    private readonly PostgreSqlContainer _container = new PostgreSqlBuilder(PostgresImage.Reference).Build();

    public string ConnectionString => _container.GetConnectionString();

    /// <summary>A connection string for another database on the same server.</summary>
    public string ConnectionStringFor(string database) =>
        new NpgsqlConnectionStringBuilder(ConnectionString) { Database = database }.ConnectionString;

    public async ValueTask InitializeAsync()
    {
        await _container.StartAsync();

        var options = new DbContextOptionsBuilder<MealPlannerDbContext>();
        options.UseMealPlannerDatabase(ConnectionString);
        await using var db = new MealPlannerDbContext(options.Options);
        await db.Database.MigrateAsync();
    }

    public ValueTask DisposeAsync() => _container.DisposeAsync();
}
