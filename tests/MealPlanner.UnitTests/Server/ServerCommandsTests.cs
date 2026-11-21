using MealPlanner.Server;

namespace MealPlanner.UnitTests.Server;

public sealed class ServerCommandsTests : IDisposable
{
    private const int ServeExitCode = 10;
    private const int MigrateExitCode = 20;

    private readonly List<(string Command, string[] HostArgs)> _ran = [];
    private readonly StringWriter _error = new();

    [Fact]
    public async Task Migrate_runs_the_migration_and_not_the_server()
    {
        var exitCode = await RunAsync("migrate");

        Assert.Equal(MigrateExitCode, exitCode);
        var (command, hostArgs) = Assert.Single(_ran);
        Assert.Equal("migrate", command);
        Assert.Empty(hostArgs);
    }

    [Fact]
    public async Task Host_options_after_migrate_are_passed_to_the_migration()
    {
        await RunAsync("migrate", "--environment=Production");

        var (command, hostArgs) = Assert.Single(_ran);
        Assert.Equal("migrate", command);
        Assert.Equal(["--environment=Production"], hostArgs);
    }

    [Fact]
    public async Task No_command_serves_the_app()
    {
        var exitCode = await RunAsync();

        Assert.Equal(ServeExitCode, exitCode);
        var (command, _) = Assert.Single(_ran);
        Assert.Equal("serve", command);
    }

    [Fact]
    public async Task Host_options_without_a_command_serve_the_app()
    {
        await RunAsync("--urls", "http://localhost:5000");

        var (command, hostArgs) = Assert.Single(_ran);
        Assert.Equal("serve", command);
        Assert.Equal(["--urls", "http://localhost:5000"], hostArgs);
    }

    [Fact]
    public async Task Unknown_command_is_refused_with_the_list_of_commands()
    {
        var exitCode = await RunAsync("seed-demo");

        Assert.Equal(ServerCommands.Refused, exitCode);
        Assert.Empty(_ran);
        Assert.Equal(
            "Unknown command 'seed-demo'. Commands: migrate. Without a command, the server serves the app.",
            _error.ToString().Trim());
    }

    public void Dispose() => _error.Dispose();

    private Task<int> RunAsync(params string[] args)
    {
        var commands = new ServerCommands(
            serve: hostArgs => Record("serve", hostArgs, ServeExitCode),
            migrate: hostArgs => Record("migrate", hostArgs, MigrateExitCode));
        return commands.RunAsync(args, _error);
    }

    private Task<int> Record(string command, string[] hostArgs, int exitCode)
    {
        _ran.Add((command, hostArgs));
        return Task.FromResult(exitCode);
    }
}
