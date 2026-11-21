using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;

namespace MealPlanner.IntegrationTests;

/// <summary>
/// The real server on Kestrel, so its limits apply as in production, in the Production
/// environment, so no development-only behaviour is tested by accident.
/// </summary>
public sealed class ServerFactory : WebApplicationFactory<Program>
{
    private readonly TimeProvider? _clock;

    public ServerFactory(TimeProvider? clock = null)
    {
        _clock = clock;
        UseKestrel(0);
    }

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment(Environments.Production);
        // Production serves the client from the published wwwroot, which a build doesn't
        // have; this serves the built files instead, as a development run does.
        builder.UseStaticWebAssets();
        if (_clock is not null)
        {
            builder.ConfigureTestServices(services => services.AddSingleton(_clock));
        }
    }
}
