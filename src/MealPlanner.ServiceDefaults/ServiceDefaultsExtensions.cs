using Microsoft.AspNetCore.Builder;
using Microsoft.AspNetCore.Diagnostics.HealthChecks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Diagnostics.HealthChecks;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using OpenTelemetry;

namespace MealPlanner.ServiceDefaults;

/// <summary>
/// What every process the AppHost starts shares: logs, traces and metrics over OTLP (D8),
/// health checks, and resilience for outgoing HTTP calls.
/// </summary>
public static class ServiceDefaultsExtensions
{
    private const string LiveTag = "live";

    public static TBuilder AddServiceDefaults<TBuilder>(this TBuilder builder) where TBuilder : IHostApplicationBuilder
    {
        builder.ConfigureOpenTelemetry();

        builder.Services.AddHealthChecks()
            .AddCheck("self", () => HealthCheckResult.Healthy(), [LiveTag]);

        builder.Services.ConfigureHttpClientDefaults(http => http.AddStandardResilienceHandler());

        return builder;
    }

    /// <summary>
    /// /health (ready) and /alive (running), in Development only: in production they would
    /// tell anyone on the internet about the server's state.
    /// </summary>
    public static WebApplication MapDefaultEndpoints(this WebApplication app)
    {
        if (app.Environment.IsDevelopment())
        {
            app.MapHealthChecks("/health");
            app.MapHealthChecks("/alive", new HealthCheckOptions { Predicate = check => check.Tags.Contains(LiveTag) });
        }

        return app;
    }

    private static void ConfigureOpenTelemetry<TBuilder>(this TBuilder builder) where TBuilder : IHostApplicationBuilder
    {
        builder.Logging.AddOpenTelemetry(logging =>
        {
            logging.IncludeFormattedMessage = true;
            logging.IncludeScopes = true;
        });

        // ASP.NET Core, HttpClient and the runtime publish their own traces and metrics, so
        // no instrumentation packages are needed, only the names to listen to.
        builder.Services.AddOpenTelemetry()
            .WithMetrics(metrics => metrics.AddMeter(
                "Microsoft.AspNetCore.Hosting",
                "Microsoft.AspNetCore.Server.Kestrel",
                "System.Net.Http",
                "System.Runtime"))
            .WithTracing(tracing => tracing.AddSource("Microsoft.AspNetCore", "System.Net.Http"));

        // The AppHost sets the endpoint; without one (tests, a plain dotnet run) nothing is exported.
        if (!string.IsNullOrWhiteSpace(builder.Configuration["OTEL_EXPORTER_OTLP_ENDPOINT"]))
        {
            builder.Services.AddOpenTelemetry().UseOtlpExporter();
        }
    }
}
