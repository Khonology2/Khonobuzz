using Microsoft.EntityFrameworkCore;
using MyApi.Data;
using MyApi.Models;

namespace MyApi.Services
{
    public class AuthService : IAuthService
    {
        private readonly ApplicationDbContext _context;
        private readonly IOtpService _otpService;
        private readonly ITokenService _tokenService;
        private readonly IFirebaseService _firebaseService;
        private readonly IEmailService _emailService;

        public AuthService(
            ApplicationDbContext context,
            IOtpService otpService,
            ITokenService tokenService,
            IFirebaseService firebaseService,
            IEmailService emailService)
        {
            _context = context;
            _otpService = otpService;
            _tokenService = tokenService;
            _firebaseService = firebaseService;
            _emailService = emailService;
        }

        public async Task<User> RegisterAsync(string email, string name, string? firstName = null, string? lastName = null, string? department = null, string? designation = null)
        {
            var existingUser = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
            if (existingUser != null)
            {
                throw new InvalidOperationException("User already exists");
            }

            var user = new User
            {
                Id = Guid.NewGuid().ToString(),
                Email = email,
                Name = name,
                FirstName = firstName ?? "",
                LastName = lastName ?? "",
                Department = department ?? "",
                Designation = designation ?? "",
                Status = "pending",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _context.Users.Add(user);
            await _context.SaveChangesAsync();

            // Generate OTP for email verification
            var otp = await _otpService.GenerateOtpAsync(email);
            await _emailService.SendOtpEmailAsync(email, otp);

            return user;
        }

        public async Task<bool> VerifyOtpAndLoginAsync(string email, string otp)
        {
            var isValid = await _otpService.VerifyOtpAsync(email, otp);
            if (!isValid)
            {
                return false;
            }

            var user = await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
            if (user == null)
            {
                return false;
            }

            // Mark OTP as used
            await _otpService.MarkOtpAsUsedAsync(email);

            // Update user status if pending
            if (user.Status == "pending")
            {
                user.Status = "active";
                user.UpdatedAt = DateTime.UtcNow;
                await _context.SaveChangesAsync();

                // Send welcome email
                await _emailService.SendWelcomeEmailAsync(email, user.Name);

                // Sync to Firebase
                await _firebaseService.SyncUserToFirebaseAsync(user);
            }

            return true;
        }

        public async Task<User?> GetUserByEmailAsync(string email)
        {
            return await _context.Users.FirstOrDefaultAsync(u => u.Email == email);
        }

        public async Task<User?> GetUserByIdAsync(string id)
        {
            return await _context.Users
                .Include(u => u.Onboarding)
                .FirstOrDefaultAsync(u => u.Id == id);
        }
    }
}
