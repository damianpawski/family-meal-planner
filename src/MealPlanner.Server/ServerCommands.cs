namespace MealPlanner.Server;

/// <summary>
/// The server executable's command line. Without a command it serves the app; with
/// <c>migrate</c> it brings the database schema up to date and exits (D6). Host options such
/// as <c>--urls</c> or <c>--environment=Production</c> may follow either and become configuration.
/// </summary>
public sealed class ServerCommands(Func<string[], Task<int>> serve, Func<string[], Task<int>> migrate)
{
    /// <summary>The exit code for a command line that isn't understood.</summary>
    public const int Refused = 2;

    private const string Migrate = "migrate";

    public static IReadOnlyList<string> Names { get; } = [Migrate];

    public Task<int> RunAsync(string[] args, TextWriter error) => args switch
    {
        [] => serve(args),
        [var first, ..] when first.StartsWith('-') => serve(args),
        [Migrate, .. var hostArgs] => migrate(hostArgs),
        [var unknown, ..] => RefuseAsync(unknown, error),
    };

    private static async Task<int> RefuseAsync(string command, TextWriter error)
    {
        await error.WriteLineAsync($"Unknown command '{command}'. Commands: {string.Join(", ", Names)}. Without a command, the server serves the app.");
        return Refused;
    }
}
