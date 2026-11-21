using MealPlanner.Server;

var commands = new ServerCommands(serve: ServerApp.RunAsync, migrate: MigrateCommand.RunAsync);
return await commands.RunAsync(args, Console.Error);
