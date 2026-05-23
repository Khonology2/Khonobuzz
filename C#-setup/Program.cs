using DotNetEnv;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.IdentityModel.Tokens;
using System.Text;
using Serilog;
using MyApi.Services;

Env.TraversePath().Load();

var builder = WebApplication.CreateBuilder(args);

// Configure Serilog
Log.Logger = new LoggerConfiguration()
    .ReadFrom.Configuration(builder.Configuration)
    .CreateLogger();
builder.Host.UseSerilog();

// Add services to the container.
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// JWT Authentication (decrypt Fernet-encrypted tokens before validation)
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        var jwtSecretKey = builder.Configuration["Jwt:SecretKey"] ?? throw new InvalidOperationException("JWT SecretKey not configured");
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuerSigningKey = true,
            IssuerSigningKey = new SymmetricSecurityKey(
                Encoding.UTF8.GetBytes(jwtSecretKey)),
            ValidateIssuer = false,
            ValidateAudience = false,
            ValidateLifetime = true,
            ClockSkew = TimeSpan.Zero
        };
        options.Events = new JwtBearerEvents
        {
            OnMessageReceived = ctx =>
            {
                var token = ctx.Request.Headers.Authorization.ToString().Replace("Bearer ", "").Trim();
                if (!string.IsNullOrEmpty(token))
                {
                    var tokenService = ctx.HttpContext.RequestServices.GetService<ITokenService>();
                    if (tokenService != null && tokenService.IsEncryptedToken(token))
                    {
                        try
                        {
                            var decrypted = tokenService.DecryptToken(token);
                            ctx.Token = decrypted;
                        }
                        catch { }
                    }
                }
                return Task.CompletedTask;
            }
        };
    });

// CORS
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

// Firestore (matches Python backend - no PostgreSQL)
builder.Services.AddSingleton<IFirestoreService, FirestoreService>();
builder.Services.AddSingleton<IPdhFirestoreService, PdhFirestoreService>();

// Register services
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IOtpService, OtpService>();
builder.Services.AddScoped<IEmailService, EmailService>();
builder.Services.AddScoped<ITokenService, TokenService>();
builder.Services.AddScoped<ICloudinaryService, CloudinaryService>();
builder.Services.AddScoped<IFirebaseService, FirebaseService>();
builder.Services.AddScoped<IRateLimiterService, RateLimiterService>();

// Background services
builder.Services.AddHostedService<OtpCleanupService>();
builder.Services.AddHostedService<RateLimitCleanupService>();

var app = builder.Build();

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors("AllowFrontend");
app.UseAuthentication();
app.UseAuthorization();

// Health and version endpoints (match Python backend)
app.MapGet("/", () => new
{
    status = "ok",
    message = "Khonology Backend API is running",
    environment = app.Environment.IsProduction() ? "production" : "development"
}).AllowAnonymous();

app.MapGet("/health", () => new
{
    status = "healthy",
    timestamp = DateTime.UtcNow.ToString("o") + "Z"
}).AllowAnonymous();

app.MapGet("/api/version", async (IWebHostEnvironment env) =>
{
    var path = Path.Combine(env.ContentRootPath, "..", "version.json");
    if (!File.Exists(path))
        return Results.NotFound(new { error = "version.json not found" });
    var json = await File.ReadAllTextAsync(path);
    var data = System.Text.Json.JsonSerializer.Deserialize<object>(json);
    return Results.Json(data);
}).AllowAnonymous();

app.MapControllers();

app.Run();
