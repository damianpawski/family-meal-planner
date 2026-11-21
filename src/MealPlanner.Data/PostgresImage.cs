namespace MealPlanner.Data;

/// <summary>
/// The Postgres server the schema is built and tested on. The AppHost and the integration
/// tests run this exact image, and Compose will too (M4a), so every environment runs the
/// same major and minor version.
/// </summary>
public static class PostgresImage
{
    public const string Name = "postgres";
    public const string Tag = "18.7";
    public const string Reference = $"{Name}:{Tag}";
}
