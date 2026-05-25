using MyApi.Models;

namespace MyApi.Services;

public interface IAuthService
{
    Task<User> RegisterAsync(string email, string password, string name, string? firstName = null, string? lastName = null, string? department = null, string? designation = null, string? entity = null, string role = "Staff");
    Task<User?> GetUserByEmailAsync(string email);
    Task<User?> GetUserByIdAsync(string id);
}

public interface ITokenService
{
    string GenerateToken(User user, IReadOnlyList<string>? roles = null, string? themePreference = null);
    string GenerateTokenFromDict(string id, string email, string name, string department = "", string designation = "", IReadOnlyList<string>? roles = null, string? themePreference = null);
    string GeneratePythonStyleToken(string userId, string email, string fullName, IReadOnlyList<string>? roles = null, string? themePreference = null);
    Dictionary<string, object>? VerifyAndExpandToken(string token);
    string? GetUserIdFromToken(string token);
    string EncryptToken(string plainJwt);
    string DecryptToken(string encryptedToken);
    bool IsEncryptedToken(string token);
    Task<string> EncryptTokenAsync(string token);
    Task<string> DecryptTokenAsync(string encryptedToken);
}

public interface ICloudinaryService
{
    Task<string> UploadImageAsync(Stream imageStream, string publicId);
    Task<bool> DeleteImageAsync(string publicId);
}
