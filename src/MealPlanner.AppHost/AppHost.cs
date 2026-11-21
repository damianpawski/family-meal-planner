using MealPlanner.Data;

var builder = DistributedApplication.CreateBuilder(args);

// An explicit dev-only password, from appsettings.Development.json. A generated one would
// live in user secrets, and losing them would lock the data volume.
var postgresPassword = builder.AddParameter("postgres-password", secret: true);
var database = builder.AddPostgres("postgres", password: postgresPassword)
    .WithImage(PostgresImage.Name, PostgresImage.Tag)
    .WithDataVolume()
    .AddDatabase("mealplanner");

builder.AddMailPit("mailpit");

// The server never changes the schema (D6): `mealplanner migrate` runs first, on its own,
// and the server starts only once it has finished successfully.
var migrate = builder.AddProject<Projects.MealPlanner_Server>("migrate", launchProfileName: null)
    .WithArgs("migrate")
    .WithReference(database)
    .WaitFor(database);

builder.AddProject<Projects.MealPlanner_Server>("server")
    .WithHttpHealthCheck("/health")
    .WaitForCompletion(migrate);

builder.Build().Run();
