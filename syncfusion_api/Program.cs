using System.Net;
using System.Text.Json;
using Syncfusion.Licensing;
using ShamsPdfApi;

// Read the key from this process's environment. Never send it to Flutter.
var key = Environment.GetEnvironmentVariable("SYNCFUSION_LICENSE_KEY");
if (string.IsNullOrWhiteSpace(key))
{
    Console.Error.WriteLine(
        "Set SYNCFUSION_LICENSE_KEY in this environment, then run again.");
    Environment.ExitCode = 1;
    return;
}

SyncfusionLicenseProvider.RegisterLicense(key.Trim());
FontCatalog.CustomDirectory = Path.Combine(AppContext.BaseDirectory, "fonts");

if (args.Contains("--self-test"))
{
    SmokeTests.Run();
    return;
}

var builder = WebApplication.CreateBuilder(args);

// Render supplies PORT. If PORT is absent, keep the existing local setup.
var renderPortText = Environment.GetEnvironmentVariable("PORT");
var isRender = int.TryParse(renderPortText, out var renderPort);

builder.WebHost.ConfigureKestrel(options =>
{
    if (isRender)
    {
        // Render requires the service to listen on all interfaces.
        options.ListenAnyIP(renderPort);
    }
    else
    {
        // Local development stays private to this computer.
        options.Listen(IPAddress.Loopback, 8765);
    }

    options.Limits.MaxRequestBodySize = 42 * 1024 * 1024;
    options.Limits.MaxConcurrentConnections = 8;
});

// Local origins remain allowed.
// Set PUBLIC_WEB_ORIGIN on Render after the GitHub Pages URL is known.
var publicWebOrigin =
    Environment.GetEnvironmentVariable("PUBLIC_WEB_ORIGIN")?.TrimEnd('/');

var allowedOrigins = new List<string>
{
    "http://localhost:8080",
    "http://127.0.0.1:8080",
};

if (!string.IsNullOrWhiteSpace(publicWebOrigin))
{
    allowedOrigins.Add(publicWebOrigin);
}

builder.Services.AddCors(options =>
    options.AddDefaultPolicy(policy => policy
        .WithOrigins(allowedOrigins.ToArray())
        .WithMethods("POST", "GET")
        .WithHeaders("Content-Type")));

builder.Logging.SetMinimumLevel(LogLevel.Warning);

var app = builder.Build();

app.Use(async (context, next) =>
{
    context.Response.Headers.CacheControl = "no-store";

    if (!isRender)
    {
        // Preserve the original localhost-only protection during local use.
        var host = context.Request.Host.Host;
        var origin = context.Request.Headers.Origin.ToString();

        if ((host != "localhost" && host != "127.0.0.1") ||
            (origin.Length > 0 &&
             origin != "http://localhost:8080" &&
             origin != "http://127.0.0.1:8080"))
        {
            context.Response.StatusCode = 403;
            await context.Response.WriteAsJsonAsync(
                new { error = "Origin or host is not allowed." });
            return;
        }
    }

    await next();
});

app.UseCors();

app.MapGet("/health", () => Results.Json(new
{
    status = "ready",
    engine = "Syncfusion .NET",
    version = "34.2.8",
    licenseKeyLoaded = true
}));

using var gate = new SemaphoreSlim(1, 1);

app.MapPost("/edit", async Task<IResult> (HttpContext context) =>
{
    if (!context.Request.HasJsonContentType())
    {
        return Results.Json(
            new { error = "Send application/json." },
            statusCode: 415);
    }

    if (!await gate.WaitAsync(0))
    {
        return Results.Json(
            new { error = "The editor is busy. Try again shortly." },
            statusCode: 429);
    }

    try
    {
        var request = await context.Request.ReadFromJsonAsync<EditRequest>();

        if (request is null)
        {
            throw new EditException("Request is empty.");
        }

        return Results.Json(PdfTextEditor.Process(request));
    }
    catch (EditException ex)
    {
        return Results.Json(
            new { error = ex.Message },
            statusCode: 422);
    }
    catch (Exception ex)
        when (ex is JsonException or FormatException or BadHttpRequestException)
    {
        return Results.Json(
            new { error = "Invalid or oversized request." },
            statusCode: 400);
    }
    catch (Exception)
    {
        // Do not expose document contents, local paths or license details.
        return Results.Json(
            new
            {
                error =
                    "Syncfusion could not process this PDF. No edited file was returned. Check that the PDF is valid and the Document SDK trial matches version 34.2.8."
            },
            statusCode: 422);
    }
    finally
    {
        gate.Release();
    }
});

if (isRender)
{
    Console.WriteLine(
        $"Shams Syncfusion service listening on Render port {renderPort}.");
}
else
{
    Console.WriteLine(
        "Shams Syncfusion service: http://127.0.0.1:8765/health");
}

await app.RunAsync();