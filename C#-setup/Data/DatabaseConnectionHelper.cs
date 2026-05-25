using Npgsql;

namespace MyApi.Data;

public static class DatabaseConnectionHelper
{
    public static string ResolveConnectionString(IConfiguration configuration)
    {
        var raw = Environment.GetEnvironmentVariable("DATABASE_URL")?.Trim()
            ?? configuration["DATABASE_URL"]?.Trim()
            ?? configuration.GetConnectionString("DefaultConnection")?.Trim();

        if (string.IsNullOrEmpty(raw))
            throw new InvalidOperationException("DATABASE_URL is required.");

        if (raw.StartsWith("postgres://", StringComparison.OrdinalIgnoreCase)
            || raw.StartsWith("postgresql://", StringComparison.OrdinalIgnoreCase))
        {
            var uri = new Uri(raw);
            var userInfo = uri.UserInfo.Split(':', 2);
            var builder = new NpgsqlConnectionStringBuilder
            {
                Host = uri.Host,
                Port = uri.Port > 0 ? uri.Port : 5432,
                Username = Uri.UnescapeDataString(userInfo[0]),
                Password = userInfo.Length > 1 ? Uri.UnescapeDataString(userInfo[1]) : "",
                Database = uri.AbsolutePath.TrimStart('/'),
                SslMode = SslMode.Prefer
            };
            return builder.ConnectionString;
        }

        return raw;
    }
}
