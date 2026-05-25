using System.Collections.Concurrent;
using MyApi.Models;
using BCrypt.Net;

namespace MyApi.Services
{
    public class OtpService : IOtpService
    {
        // In-memory storage for OTP codes
        private static readonly ConcurrentDictionary<string, OTPCode> _otpCodes = new();

        private readonly IConfiguration _configuration;

        public OtpService(IConfiguration configuration)
        {
            _configuration = configuration;
        }

        public async Task<string> GenerateOtpAsync(string email)
        {
            // Clean up expired OTPs first
            await CleanupExpiredOtpsAsync();

            var otpCode = new Random().Next(100000, 999999).ToString();
            var hashedOtp = BCrypt.Net.BCrypt.HashPassword(otpCode);

            var expirationMinutes = _configuration.GetValue<int>("Otp:ExpirationMinutes", 5);
            var expiresAt = DateTime.UtcNow.AddMinutes(expirationMinutes);

            var otpRecord = new OTPCode
            {
                Id = Guid.NewGuid().ToString(),
                Email = email,
                Code = hashedOtp,
                ExpiresAt = expiresAt,
                Attempts = 0
            };

            _otpCodes[email] = otpRecord;

            return otpCode; // Return plain OTP for email sending
        }

        public async Task<bool> VerifyOtpAsync(string email, string otp)
        {
            if (!_otpCodes.TryGetValue(email, out var otpRecord))
            {
                return false;
            }

            if (otpRecord.ExpiresAt < DateTime.UtcNow || otpRecord.IsUsed)
            {
                return false;
            }

            var maxAttempts = _configuration.GetValue<int>("Otp:MaxAttempts", 3);
            if (otpRecord.Attempts >= maxAttempts)
            {
                return false;
            }

            var isValid = BCrypt.Net.BCrypt.Verify(otp, otpRecord.Code);
            if (!isValid)
            {
                otpRecord.Attempts++;
                return false;
            }

            return true;
        }

        public async Task<bool> IsOtpExpiredAsync(string email)
        {
            if (!_otpCodes.TryGetValue(email, out var otpRecord))
            {
                return true;
            }

            return otpRecord.ExpiresAt < DateTime.UtcNow || otpRecord.IsUsed;
        }

        public async Task MarkOtpAsUsedAsync(string email)
        {
            if (_otpCodes.TryGetValue(email, out var otpRecord))
            {
                otpRecord.IsUsed = true;
            }
        }

        public async Task<int> GetAttemptsAsync(string email)
        {
            if (_otpCodes.TryGetValue(email, out var otpRecord))
            {
                return otpRecord.Attempts;
            }
            return 0;
        }

        public async Task IncrementAttemptsAsync(string email)
        {
            if (_otpCodes.TryGetValue(email, out var otpRecord))
            {
                otpRecord.Attempts++;
            }
        }

        private async Task CleanupExpiredOtpsAsync()
        {
            var expiredKeys = _otpCodes.Where(kvp =>
                kvp.Value.ExpiresAt < DateTime.UtcNow || kvp.Value.IsUsed)
                .Select(kvp => kvp.Key)
                .ToList();

            foreach (var key in expiredKeys)
            {
                _otpCodes.TryRemove(key, out _);
            }
        }
    }
}
