using System.IdentityModel.Tokens.Jwt;
using System.Text;
using System.Text.Json;
using Cryptography;
using Microsoft.IdentityModel.Tokens;
using MyApi.Models;

namespace MyApi.Services;

public class TokenService : ITokenService
{
    private readonly IConfiguration _configuration;

    public TokenService(IConfiguration configuration) => _configuration = configuration;

    private string GetJwtSecret() =>
        Environment.GetEnvironmentVariable("JWT_SECRET_KEY")?.Trim()
        ?? _configuration["Jwt:SecretKey"]?.Trim()
        ?? throw new InvalidOperationException("JWT_SECRET_KEY or Jwt:SecretKey not configured");

    private string GetEncryptionKey()
    {
        var key = Environment.GetEnvironmentVariable("ENCRYPTION_KEY")?.Trim()
            ?? _configuration["Encryption:Key"]?.Trim();
        if (string.IsNullOrEmpty(key))
            throw new InvalidOperationException("ENCRYPTION_KEY or Encryption:Key not configured");
        return key;
    }

    public string GenerateToken(User user, IReadOnlyList<string>? roles = null, string? themePreference = null) =>
        GeneratePythonStyleToken(user.Id, user.Email, user.Name ?? "", roles, themePreference ?? "dark");

    public string GenerateTokenFromDict(string id, string email, string name, string department = "", string designation = "", IReadOnlyList<string>? roles = null, string? themePreference = null) =>
        GeneratePythonStyleToken(id, email, name, roles, themePreference);

    public string GeneratePythonStyleToken(string userId, string email, string fullName, IReadOnlyList<string>? roles = null, string? themePreference = null)
    {
        var expirationHours = _configuration.GetValue<int>("Jwt:ExpirationHours", 24);
        var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        var exp = now + (expirationHours * 3600L);
        var payload = new JwtPayload
        {
            { "user_id", userId },
            { "email", email },
            { "full_name", fullName ?? "" },
            { "roles", roles?.ToList() ?? new List<string>() },
            { "theme", ModuleRoleParser.NormalizeThemePreference(themePreference) },
            { "iat", now },
            { "exp", exp }
        };
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(GetJwtSecret()));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var token = new JwtSecurityToken(new JwtHeader(creds), payload);
        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public Dictionary<string, object>? VerifyAndExpandToken(string token)
    {
        try
        {
            var jwt = token;
            if (IsEncryptedToken(token))
                jwt = DecryptToken(token);

            var handler = new JwtSecurityTokenHandler();
            var parameters = new TokenValidationParameters
            {
                ValidateIssuerSigningKey = true,
                IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(GetJwtSecret())),
                ValidateIssuer = false,
                ValidateAudience = false,
                ValidateLifetime = true,
                ClockSkew = TimeSpan.Zero
            };
            handler.ValidateToken(jwt, parameters, out var validated);
            var jwtToken = (JwtSecurityToken)validated;

            if (jwtToken.Payload.TryGetValue("user_id", out var uid) || jwtToken.Payload.TryGetValue("uid", out uid))
            {
                var roles = new List<string>();
                if (jwtToken.Payload.TryGetValue("roles", out var rolesObj))
                {
                    if (rolesObj is JsonElement je && je.ValueKind == JsonValueKind.Array)
                        roles = je.EnumerateArray().Select(x => x.GetString() ?? "").Where(x => x.Length > 0).ToList();
                    else if (rolesObj is IEnumerable<object> list)
                        roles = list.Select(x => x?.ToString() ?? "").Where(x => x.Length > 0).ToList();
                }
                return new Dictionary<string, object>
                {
                    ["user_id"] = uid?.ToString() ?? "",
                    ["email"] = jwtToken.Payload.TryGetValue("email", out var em) ? em?.ToString() ?? "" : "",
                    ["full_name"] = jwtToken.Payload.TryGetValue("full_name", out var fn) ? fn?.ToString() ?? "" : "",
                    ["roles"] = roles,
                    ["theme"] = jwtToken.Payload.TryGetValue("theme", out var th) ? th?.ToString() ?? "dark" : "dark",
                    ["exp"] = jwtToken.Payload.TryGetValue("exp", out var exp) ? exp : 0,
                    ["iat"] = jwtToken.Payload.TryGetValue("iat", out var iat) ? iat : 0
                };
            }

            return jwtToken.Payload.ToDictionary(k => k.Key, k => k.Value ?? "");
        }
        catch
        {
            return null;
        }
    }

    public string EncryptToken(string plainJwt) => Fernet.Encrypt(GetEncryptionKey(), plainJwt);
    public string DecryptToken(string encryptedToken) => Fernet.Decrypt(GetEncryptionKey(), encryptedToken);

    public bool IsEncryptedToken(string token) =>
        !string.IsNullOrEmpty(token) && (token.StartsWith("gAAAA", StringComparison.Ordinal) || !token.Contains('.'));

    public string? GetUserIdFromToken(string token)
    {
        var payload = VerifyAndExpandToken(token);
        if (payload == null) return null;
        if (payload.TryGetValue("user_id", out var uid) && uid?.ToString() is { Length: > 0 } id) return id;
        if (payload.TryGetValue("sub", out var sub) && sub?.ToString() is { Length: > 0 } subId) return subId;
        return null;
    }

    public Task<string> EncryptTokenAsync(string token) => Task.FromResult(EncryptToken(token));
    public Task<string> DecryptTokenAsync(string encryptedToken) => Task.FromResult(DecryptToken(encryptedToken));
}
