using Microsoft.EntityFrameworkCore;
using MyApi.Data;
using MyApi.Models;
using BCrypt.Net;

namespace MyApi.Services
{
    public class OtpService : IOtpService
    {
        private readonly ApplicationDbContext _context;
        private readonly IConfiguration _configuration;

        public OtpService(ApplicationDbContext context, IConfiguration configuration)
        {
            _context = context;
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

            _context.OTPCodes.Add(otpRecord);
            await _context.SaveChangesAsync();

            return otpCode; // Return plain OTP for email sending
        }

        public async Task<bool> VerifyOtpAsync(string email, string otp)
        {
            var otpRecord = await _context.OTPCodes
                .Where(o => o.Email == email && !o.IsUsed)
                .OrderByDescending(o => o.CreatedAt)
                .FirstOrDefaultAsync();

            if (otpRecord == null || otpRecord.ExpiresAt < DateTime.UtcNow)
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
                await _context.SaveChangesAsync();
                return false;
            }

            return true;
        }

        public async Task<bool> IsOtpExpiredAsync(string email)
        {
            var otpRecord = await _context.OTPCodes
                .Where(o => o.Email == email && !o.IsUsed)
                .OrderByDescending(o => o.CreatedAt)
                .FirstOrDefaultAsync();

            return otpRecord == null || otpRecord.ExpiresAt < DateTime.UtcNow;
        }

        public async Task MarkOtpAsUsedAsync(string email)
        {
            var otpRecord = await _context.OTPCodes
                .Where(o => o.Email == email && !o.IsUsed)
                .OrderByDescending(o => o.CreatedAt)
                .FirstOrDefaultAsync();

            if (otpRecord != null)
            {
                otpRecord.IsUsed = true;
                await _context.SaveChangesAsync();
            }
        }

        public async Task<int> GetAttemptsAsync(string email)
        {
            var otpRecord = await _context.OTPCodes
                .Where(o => o.Email == email && !o.IsUsed)
                .OrderByDescending(o => o.CreatedAt)
                .FirstOrDefaultAsync();

            return otpRecord?.Attempts ?? 0;
        }

        public async Task IncrementAttemptsAsync(string email)
        {
            var otpRecord = await _context.OTPCodes
                .Where(o => o.Email == email && !o.IsUsed)
                .OrderByDescending(o => o.CreatedAt)
                .FirstOrDefaultAsync();

            if (otpRecord != null)
            {
                otpRecord.Attempts++;
                await _context.SaveChangesAsync();
            }
        }

        private async Task CleanupExpiredOtpsAsync()
        {
            var expiredOtps = await _context.OTPCodes
                .Where(o => o.ExpiresAt < DateTime.UtcNow || o.IsUsed)
                .ToListAsync();

            if (expiredOtps.Any())
            {
                _context.OTPCodes.RemoveRange(expiredOtps);
                await _context.SaveChangesAsync();
            }
        }
    }
}
