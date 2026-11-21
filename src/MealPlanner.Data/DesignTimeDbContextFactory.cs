using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace MealPlanner.Data;

/// <summary>
/// Lets the EF Core tools build the model to generate a migration. They never connect: the
/// database is only changed by <c>mealplanner migrate</c> and by the test fixtures.
/// </summary>
internal sealed class DesignTimeDbContextFactory : IDesignTimeDbContextFactory<MealPlannerDbContext>
{
    public MealPlannerDbContext CreateDbContext(string[] args)
    {
        var options = new DbContextOptionsBuilder<MealPlannerDbContext>();
        options.UseMealPlannerDatabase("Host=localhost");
        return new MealPlannerDbContext(options.Options);
    }
}
