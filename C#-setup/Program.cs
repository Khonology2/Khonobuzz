using DotNetEnv;
using Microsoft.AspNetCore.ResponseCompression;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Caching.Memory;
using MyApi.Data;
using MyApi.Services;
using Serilog;

Env.TraversePath().Load();
var backendEnvPath = Path.GetFullPath(Path.Combine(Directory.GetCurrentDirectory(), "..", "backend", ".env"));
if (File.Exists(backendEnvPath))
    DotNetEnv.Env.Load(backendEnvPath);

var builder = WebApplication.CreateBuilder(args);

Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .CreateLogger();
builder.Host.UseSerilog();

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddMemoryCache();
builder.Services.AddResponseCompression(options =>
{
    options.EnableForHttps = true;
    options.Providers.Add<GzipCompressionProvider>();
});

var connectionString = DatabaseConnectionHelper.ResolveConnectionString(builder.Configuration);
builder.Services.AddDbContext<KhonoDbContext>(options => options.UseNpgsql(connectionString));
builder.Services.AddScoped<IKhonoRelationalService, KhonoRelationalService>();
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<ITokenService, TokenService>();
builder.Services.AddScoped<ICloudinaryService, CloudinaryService>();
builder.Services.AddScoped<ISsoPgSyncService, SsoPgSyncService>();

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowFrontend", policy =>
    {
        var corsOrigins = builder.Configuration.GetSection("Cors:Origins").Get<string[]>() ?? Array.Empty<string>();
        policy.WithOrigins(corsOrigins)
              .AllowAnyMethod()
              .AllowAnyHeader()
              .AllowCredentials();
    });
});

var app = builder.Build();

using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<KhonoDbContext>();
    db.Database.EnsureCreated();
}

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseResponseCompression();
app.UseHttpsRedirection();
app.UseCors("AllowFrontend");

app.MapGet("/", () => new
{
    status = "ok",
    message = "Khonology Backend API is running",
    environment = app.Environment.IsProduction() ? "production" : "development"
}).AllowAnonymous();

app.MapGet("/health", () => new
{
    status = "healthy",
    timestamp = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
}).AllowAnonymous();

app.MapGet("/api/version", async (IWebHostEnvironment env, IMemoryCache cache) =>
{
    const string cacheKey = "version_json";
    if (cache.TryGetValue(cacheKey, out object? cached) && cached != null)
        return Results.Json(cached);

    var path = Path.Combine(env.ContentRootPath, "..", "version.json");
    if (!File.Exists(path))
        return Results.NotFound(new { error = "version.json not found" });
    var json = await File.ReadAllTextAsync(path);
    var data = System.Text.Json.JsonSerializer.Deserialize<object>(json);
    cache.Set(cacheKey, data, TimeSpan.FromSeconds(60));
    return Results.Json(data);
}).AllowAnonymous();

app.MapControllers();
app.Run();
