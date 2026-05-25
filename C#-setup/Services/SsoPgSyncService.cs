using MyApi.Data;
using Npgsql;

namespace MyApi.Services;

public interface ISsoPgSyncService
{
    Task SyncUserLoginAsync(string uid, Dictionary<string, object>? userData, Dictionary<string, object>? onboardingData);
}

public class SsoPgSyncService : ISsoPgSyncService
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<SsoPgSyncService> _logger;

    public SsoPgSyncService(IConfiguration configuration, ILogger<SsoPgSyncService> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    public async Task SyncUserLoginAsync(string uid, Dictionary<string, object>? userData, Dictionary<string, object>? onboardingData)
    {
        userData ??= new Dictionary<string, object>();
        onboardingData ??= new Dictionary<string, object>();
        var urls = GetConnectionUrls();
        foreach (var (name, url) in urls)
        {
            try
            {
                var connStr = DatabaseConnectionHelper.ResolveConnectionString(new ConfigurationBuilder().AddInMemoryCollection(new Dictionary<string, string?> { ["DATABASE_URL"] = url }).Build());
                await using var conn = new NpgsqlConnection(connStr);
                await conn.OpenAsync();
                var email = Coalesce(userData.GetValueOrDefault("email"), onboardingData.GetValueOrDefault("email"))?.ToString()?.Trim().ToLowerInvariant();
                if (string.IsNullOrEmpty(email)) continue;

                var fullName = Coalesce(onboardingData.GetValueOrDefault("fullName"), userData.GetValueOrDefault("name"))?.ToString() ?? email;
                var tableName = await DetectTableAsync(conn, "sso_user_login", "users");
                if (tableName == "users")
                    await UpsertUsersTableAsync(conn, uid, email, fullName, userData, onboardingData);
                else
                    await UpsertSsoUserLoginAsync(conn, uid, email, fullName, userData, onboardingData);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "SSO sync failed for target {Target}", name);
            }
        }
    }

    private Dictionary<string, string> GetConnectionUrls()
    {
        var urls = new Dictionary<string, string>();
        void Add(string key, params string[] envNames)
        {
            foreach (var env in envNames)
            {
                var val = Environment.GetEnvironmentVariable(env)?.Trim();
                if (!string.IsNullOrEmpty(val)) { urls[key] = val; return; }
            }
        }
        Add("skills_heatmap", "Skills_Heatmap", "SKILLS_HEATMAP");
        Add("sign_off_hub", "sign_off_hub", "SIGN_OFF_HUB", "Sign_Off_Hub", "sign_off_heatmap", "SIGN_OFF_HEATMAP", "Sign_Off_Heatmap");
        return urls;
    }

    private static object? Coalesce(params object?[] values)
    {
        foreach (var v in values)
        {
            if (v == null) continue;
            if (v is string s && string.IsNullOrWhiteSpace(s)) continue;
            return v;
        }
        return null;
    }

    private static async Task<string> DetectTableAsync(NpgsqlConnection conn, string primary, string fallback)
    {
        await using var cmd = new NpgsqlCommand(
            "SELECT CASE WHEN to_regclass(@p) IS NOT NULL THEN @p ELSE @f END", conn);
        cmd.Parameters.AddWithValue("p", primary);
        cmd.Parameters.AddWithValue("f", fallback);
        var result = await cmd.ExecuteScalarAsync();
        return result?.ToString() ?? fallback;
    }

    private static async Task UpsertSsoUserLoginAsync(NpgsqlConnection conn, string uid, string email, string fullName,
        Dictionary<string, object> userData, Dictionary<string, object> onboardingData)
    {
        const string sql = """
            INSERT INTO sso_user_login (user_id, email, name, full_name, role, status, updated_at)
            VALUES (@uid, @email, @name, @full_name, @role, @status, NOW())
            ON CONFLICT (email) DO UPDATE SET
                name = EXCLUDED.name,
                full_name = EXCLUDED.full_name,
                role = EXCLUDED.role,
                status = EXCLUDED.status,
                updated_at = NOW()
            """;
        await using var cmd = new NpgsqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("uid", uid);
        cmd.Parameters.AddWithValue("email", email);
        cmd.Parameters.AddWithValue("name", fullName);
        cmd.Parameters.AddWithValue("full_name", fullName);
        cmd.Parameters.AddWithValue("role", userData.GetValueOrDefault("role")?.ToString() ?? "Staff");
        cmd.Parameters.AddWithValue("status", userData.GetValueOrDefault("status")?.ToString() ?? "Active");
        await cmd.ExecuteNonQueryAsync();
    }

    private static async Task UpsertUsersTableAsync(NpgsqlConnection conn, string uid, string email, string fullName,
        Dictionary<string, object> userData, Dictionary<string, object> onboardingData)
    {
        const string sql = """
            INSERT INTO users (id, email, name, role, is_active, email_verified, created_at, updated_at)
            VALUES (@id::uuid, @email, @name, @role, true, true, NOW(), NOW())
            ON CONFLICT (email) DO UPDATE SET
                name = EXCLUDED.name,
                role = EXCLUDED.role,
                is_active = true,
                email_verified = true,
                updated_at = NOW()
            """;
        await using var cmd = new NpgsqlCommand(sql, conn);
        cmd.Parameters.AddWithValue("id", Guid.TryParse(uid, out var g) ? g : Guid.NewGuid());
        cmd.Parameters.AddWithValue("email", email);
        cmd.Parameters.AddWithValue("name", fullName);
        cmd.Parameters.AddWithValue("role", NormalizeSignOffRole(userData.GetValueOrDefault("role")?.ToString()));
        await cmd.ExecuteNonQueryAsync();
    }

    private static string NormalizeSignOffRole(string? role)
    {
        var raw = (role ?? "").Trim().ToLowerInvariant();
        return raw switch
        {
            "admin" or "system admin" or "systemadmin" => "systemAdmin",
            "manager" or "delivery manager" or "delivery lead" => "deliveryLead",
            "client" or "client reviewer" or "clientreviewer" => "clientReviewer",
            _ => "teamMember"
        };
    }
}
