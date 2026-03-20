using System.Collections.Concurrent;
using MyApi.Models;

namespace MyApi.Services
{
    public class AuthService : IAuthService
    {
        // In-memory storage for demonstration - replace with proper persistence as needed
        private static readonly ConcurrentDictionary<string, User> _users = new();
        private static readonly ConcurrentDictionary<string, Onboarding> _onboardings = new();

        private readonly IOtpService _otpService;
        private readonly ITokenService _tokenService;
        private readonly IFirebaseService _firebaseService;
        private readonly IEmailService _emailService;

        public AuthService(
            IOtpService otpService,
            ITokenService tokenService,
            IFirebaseService firebaseService,
            IEmailService emailService)
        {
            _otpService = otpService;
            _tokenService = tokenService;
            _firebaseService = firebaseService;
            _emailService = emailService;
        }

        public async Task<User> RegisterAsync(string email, string name, string? firstName = null, string? lastName = null, string? department = null, string? designation = null)
        {
            if (_users.Values.Any(u => u.Email == email))
            {
                throw new InvalidOperationException("User already exists");
            }

            var user = new User
            {
                Id = Guid.NewGuid().ToString(),
                Email = email,
                Name = "Default User",
                FirstName = "",
                LastName = "",
                Role = "user",
                Status = "pending",
                Department = "",
                Designation = "",
                Manager = "",
                Entity = "",
                ModuleAccess = "",
                ModuleRole = "",
                ModuleAccessRole = "",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _users[user.Id] = user;

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

            var user = _users.Values.FirstOrDefault(u => u.Email == email);
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

                // Send welcome email
                await _emailService.SendWelcomeEmailAsync(email, user.Name);

                // Sync to Firebase
                await _firebaseService.SyncUserToFirebaseAsync(user);
            }

            return true;
        }

        public async Task<User?> GetUserByEmailAsync(string email)
        {
            return _users.Values.FirstOrDefault(u => u.Email == email);
        }

        public async Task<User?> GetUserByIdAsync(string id)
        {
            _users.TryGetValue(id, out var user);
            if (user != null && _onboardings.TryGetValue(id, out var onboarding))
            {
                user.Onboarding = onboarding;
            }
            return user;
        }
    }
}
