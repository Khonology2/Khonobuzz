using MyApi.Models;

namespace MyApi.Services
{
    public interface IAuthService
    {
        Task<User> RegisterAsync(string email, string name, string? firstName = null, string? lastName = null, string? department = null, string? designation = null);
        Task<bool> VerifyOtpAndLoginAsync(string email, string otp);
        Task<User?> GetUserByEmailAsync(string email);
        Task<User?> GetUserByIdAsync(string id);
    }

    public interface IOtpService
    {
        Task<string> GenerateOtpAsync(string email);
        Task<bool> VerifyOtpAsync(string email, string otp);
        Task<bool> IsOtpExpiredAsync(string email);
        Task MarkOtpAsUsedAsync(string email);
        Task<int> GetAttemptsAsync(string email);
        Task IncrementAttemptsAsync(string email);
    }

    public interface IEmailService
    {
        Task SendOtpEmailAsync(string email, string otp);
        Task SendWelcomeEmailAsync(string email, string name);
    }

    public interface ITokenService
    {
        string GenerateToken(User user, IReadOnlyList<string>? roles = null);
        string GenerateTokenFromDict(string id, string email, string name, string department = "", string designation = "", IReadOnlyList<string>? roles = null);
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

    public interface IFirebaseService
    {
        Task SyncUserToFirebaseAsync(User user);
        Task SyncOnboardingToFirebaseAsync(Onboarding onboarding);
    }

    public interface IRateLimiterService
    {
        Task<bool> IsRateLimitedAsync(string identifier);
        Task RecordRequestAsync(string identifier);
    }
}
