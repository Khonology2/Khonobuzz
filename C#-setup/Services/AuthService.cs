using MyApi.Models;

namespace MyApi.Services
{
    public class AuthService : IAuthService
    {
        private readonly IOtpService _otpService;
        private readonly ITokenService _tokenService;
        private readonly IFirebaseService _firebaseService;
        private readonly IFirestoreService _firestore;
        private readonly IEmailService _emailService;

        public AuthService(
            IOtpService otpService,
            ITokenService tokenService,
            IFirebaseService firebaseService,
            IFirestoreService firestore,
            IEmailService emailService)
        {
            _otpService = otpService;
            _tokenService = tokenService;
            _firebaseService = firebaseService;
            _firestore = firestore;
            _emailService = emailService;
        }

        public async Task<User> RegisterAsync(string email, string name, string? firstName = null, string? lastName = null, string? department = null, string? designation = null)
        {
            var normalized = email.Trim().ToLowerInvariant();
            var existing = await _firestore.GetUserByEmailAsync(normalized);
            if (existing != null)
                throw new InvalidOperationException("User already exists");

            var fullName = $"{firstName ?? ""} {lastName ?? ""}".Trim();
            if (string.IsNullOrEmpty(fullName)) fullName = name;

            var userData = new Dictionary<string, object>
            {
                ["email"] = normalized,
                ["name"] = fullName,
                ["role"] = "user",
                ["status"] = "Pending",
                ["entity"] = "",
                ["department"] = department ?? "",
                ["designation"] = designation ?? "",
                ["moduleAccess"] = "",
                ["moduleRole"] = "",
                ["moduleAccessRole"] = "",
                ["manager"] = "",
                ["created_at"] = DateTime.UtcNow,
                ["updated_at"] = DateTime.UtcNow
            };
            var userId = await _firestore.AddUserAsync(userData);

            var onboardingData = new Dictionary<string, object>
            {
                ["email"] = normalized,
                ["name"] = firstName ?? "",
                ["surname"] = lastName ?? "",
                ["fullName"] = fullName,
                ["department"] = department ?? "",
                ["designation"] = designation ?? "",
                ["first_valid"] = new DateTime(2025, 9, 25),
                ["last_valid"] = new DateTime(2039, 12, 31),
                ["onboarding_id"] = userId,
                ["status_id"] = "",
                ["inserted_by"] = normalized,
                ["updated_by"] = normalized,
                ["entity"] = "",
                ["moduleAccess"] = "",
                ["moduleRole"] = "",
                ["moduleAccessRole"] = "",
                ["created_at"] = DateTime.UtcNow,
                ["updated_at"] = DateTime.UtcNow
            };
            await _firestore.AddOnboardingAsync(userId, onboardingData);

            return DictToUser(userId, userData);
        }

        public async Task<bool> VerifyOtpAndLoginAsync(string email, string otp)
        {
            var isValid = await _otpService.VerifyOtpAsync(email, otp);
            if (!isValid) return false;

            var user = await _firestore.GetUserByEmailAsync(email.Trim());
            if (user == null) return false;

            await _otpService.MarkOtpAsUsedAsync(email);

            var userId = user.GetValueOrDefault("id")?.ToString() ?? "";
            if (!string.IsNullOrEmpty(userId) && "Pending".Equals(user.GetValueOrDefault("status")?.ToString(), StringComparison.OrdinalIgnoreCase))
            {
                await _firestore.UpdateUserAsync(userId, new Dictionary<string, object> { ["status"] = "Active" });
                try { await _firestore.UpdateOnboardingByUserIdAsync(userId, new Dictionary<string, object> { ["status"] = "Active" }); } catch { }
            }
            return true;
        }

        public async Task<User?> GetUserByEmailAsync(string email)
        {
            var d = await _firestore.GetUserByEmailAsync(email.Trim());
            if (d == null) return null;
            var id = d.GetValueOrDefault("id")?.ToString() ?? "";
            return DictToUser(id, d);
        }

        public async Task<User?> GetUserByIdAsync(string id)
        {
            var d = await _firestore.GetUserByIdAsync(id);
            if (d == null) return null;
            return DictToUser(id, d);
        }

        private static User DictToUser(string id, Dictionary<string, object> d)
        {
            return new User
            {
                Id = id,
                Email = d.GetValueOrDefault("email")?.ToString() ?? "",
                Name = d.GetValueOrDefault("name")?.ToString() ?? "",
                FirstName = d.GetValueOrDefault("firstName")?.ToString() ?? "",
                LastName = d.GetValueOrDefault("lastName")?.ToString() ?? "",
                Role = d.GetValueOrDefault("role")?.ToString() ?? "Staff",
                Status = d.GetValueOrDefault("status")?.ToString() ?? "Active",
                Entity = d.GetValueOrDefault("entity")?.ToString() ?? "",
                Department = d.GetValueOrDefault("department")?.ToString() ?? "",
                Designation = d.GetValueOrDefault("designation")?.ToString() ?? "",
                Manager = d.GetValueOrDefault("manager")?.ToString() ?? "",
                ModuleAccess = d.GetValueOrDefault("moduleAccess")?.ToString() ?? "",
                ModuleRole = d.GetValueOrDefault("moduleRole")?.ToString() ?? "",
                ModuleAccessRole = d.GetValueOrDefault("moduleAccessRole")?.ToString() ?? ""
            };
        }
    }
}
