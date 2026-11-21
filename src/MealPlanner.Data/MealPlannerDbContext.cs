using Microsoft.EntityFrameworkCore;

namespace MealPlanner.Data;

public sealed class MealPlannerDbContext(DbContextOptions<MealPlannerDbContext> options) : DbContext(options);
