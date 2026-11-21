using MealPlanner.Data;
using Microsoft.EntityFrameworkCore;
using Npgsql;

namespace MealPlanner.IntegrationTests.Data;

public sealed class NamingConventionTests(PostgresFixture postgres)
{
    [Fact]
    public async Task Naming_convention_is_snake_case()
    {
        var cancellationToken = TestContext.Current.CancellationToken;
        // A database of its own, so the test model never mixes with the app's migrations.
        var connectionString = postgres.ConnectionStringFor("naming_convention");
        var options = new DbContextOptionsBuilder<TestDbContext>();
        options.UseMealPlannerDatabase(connectionString);
        await using (var db = new TestDbContext(options.Options))
        {
            await db.Database.EnsureCreatedAsync(cancellationToken);
        }

        Assert.Equal(["created_at", "family_id", "id"], await ColumnsAsync(connectionString, "test_record", cancellationToken));
        Assert.Equal(["pk_test_record"], await ConstraintsAsync(connectionString, "test_record", cancellationToken));
    }

    // ADR 13 allows EF Core's own history table to keep PascalCase columns. This records
    // that the convention reaches it too, so an upgrade that changes it is noticed.
    [Fact]
    public async Task Migrations_history_table_columns_are_snake_case_too()
    {
        var cancellationToken = TestContext.Current.CancellationToken;

        var columns = await ColumnsAsync(postgres.ConnectionString, MealPlannerDatabase.MigrationsHistoryTable, cancellationToken);

        Assert.Equal(["migration_id", "product_version"], columns);
    }

    private static async Task<List<string>> ColumnsAsync(string connectionString, string table, CancellationToken cancellationToken) =>
        await QueryNamesAsync(
            connectionString,
            "SELECT column_name FROM information_schema.columns WHERE table_schema = 'public' AND table_name = $1 ORDER BY column_name",
            table,
            cancellationToken);

    private static async Task<List<string>> ConstraintsAsync(string connectionString, string table, CancellationToken cancellationToken) =>
        await QueryNamesAsync(
            connectionString,
            "SELECT constraint_name FROM information_schema.table_constraints WHERE table_schema = 'public' AND table_name = $1 AND constraint_type <> 'CHECK' ORDER BY constraint_name",
            table,
            cancellationToken);

    private static async Task<List<string>> QueryNamesAsync(string connectionString, string sql, string table, CancellationToken cancellationToken)
    {
        await using var dataSource = NpgsqlDataSource.Create(connectionString);
        await using var command = dataSource.CreateCommand(sql);
        command.Parameters.AddWithValue(table);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);
        var names = new List<string>();
        while (await reader.ReadAsync(cancellationToken))
        {
            names.Add(reader.GetString(0));
        }
        return names;
    }

    private sealed class TestRecord
    {
        public Guid Id { get; set; }
        public Guid FamilyId { get; set; }
        public DateTimeOffset CreatedAt { get; set; }
    }

    // No DbSet property, so the table is named after the entity type, as the app's will be.
    private sealed class TestDbContext(DbContextOptions<TestDbContext> options) : DbContext(options)
    {
        protected override void OnModelCreating(ModelBuilder modelBuilder) => modelBuilder.Entity<TestRecord>();
    }
}
