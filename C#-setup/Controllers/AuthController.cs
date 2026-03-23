using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using MyApi.Services;
using MyApi.DTOs.Auth;
using MyApi.Models;

namespace MyApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly IAuthService _authService;
        private readonly IOtpService _otpService;
        private readonly IRateLimiterService _rateLimiter;
        private readonly IFirestoreService _firestore;
        private readonly ITokenService _tokenService;
        private readonly IPdhFirestoreService? _pdhFirestore;

        public AuthController(
            IAuthService authService,
            IOtpService otpService,
            IRateLimiterService rateLimiter,
            IFirestoreService firestore,
            ITokenService tokenService,
            IPdhFirestoreService? pdhFirestore = null)
        {
            _authService = authService;
            _otpService = otpService;
            _rateLimiter = rateLimiter;
            _firestore = firestore;
            _tokenService = tokenService;
            _pdhFirestore = pdhFirestore;
        }

        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] UserRegister request)
        {
            var email = request.Email?.Trim() ?? "";
            if (!email.EndsWith("@khonology.com", StringComparison.OrdinalIgnoreCase))
                return BadRequest(new { error = "Only Khonology work emails (@khonology.com) are allowed" });
            if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(request.Name?.Trim()))
                return BadRequest(new { error = "Email, password, and name required" });

            try
            {
                var user = await _authService.RegisterAsync(
                    email,
                    (request.Name ?? "").Trim(),
                    request.FirstName,
                    request.LastName,
                    request.Department,
                    request.Designation);

                var roles = ParseModuleAccessRoleToRoles("");
                var plainToken = _tokenService.GenerateToken(user, roles);
                var encryptedToken = _tokenService.EncryptToken(plainToken);

                var obUpdates = new Dictionary<string, object>
                {
                    ["token"] = encryptedToken,
                    ["token_updated_at"] = DateTime.UtcNow
                };
                await _firestore.UpdateOnboardingByUserIdAsync(user.Id, obUpdates);

                return StatusCode(201, new
                {
                    message = "User created successfully",
                    user = new { id = user.Id, email = user.Email, name = user.Name ?? "", role = user.Role ?? "Staff" },
                    token = encryptedToken
                });
            }
            catch (InvalidOperationException ex) when (ex.Message?.Contains("already exists", StringComparison.OrdinalIgnoreCase) == true)
            {
                return StatusCode(409, new { error = "User already exists" });
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { error = ex.Message });
            }
            catch (Exception)
            {
                return StatusCode(500, new { error = "An error occurred during registration." });
            }
        }

        [HttpPost("otp/request")]
        public async Task<IActionResult> RequestOtp([FromBody] OTPRequest request)
        {
            if (request.Email == null)
            {
                return BadRequest(new { Message = "Email is required." });
            }

            // Rate limiting
            if (await _rateLimiter.IsRateLimitedAsync($"otp_request_{request.Email}"))
            {
                return StatusCode(429, new { Message = "Too many OTP requests. Please try again later." });
            }

            try
            {
                var otp = await _otpService.GenerateOtpAsync(request.Email);
                await _rateLimiter.RecordRequestAsync($"otp_request_{request.Email}");

                var response = new
                {
                    Message = "OTP sent successfully.",
                    Email = request.Email
                };

                return Ok(response);
            }
            catch (Exception)
            {
                return StatusCode(500, new { Message = "Failed to send OTP." });
            }
        }

        [HttpPost("login")]
        [AllowAnonymous]
        public async Task<IActionResult> Login([FromBody] UserLogin request, [FromHeader(Name = "X-Session-Type")] string? sessionType = null)
        {
            var email = request.Email?.Trim() ?? "";
            if (string.IsNullOrEmpty(email))
                return BadRequest(new { error = "Email is required" });
            if (!email.EndsWith("@khonology.com", StringComparison.OrdinalIgnoreCase))
                return BadRequest(new { error = "Only Khonology work emails (@khonology.com) are allowed" });

            if (await _rateLimiter.IsRateLimitedAsync($"login_{email}"))
                return StatusCode(429, new { error = "Too many login attempts. Please try again later." });

            var normalizedEmail = email.ToLowerInvariant();
            var isSpecialSession = "special".Equals(sessionType?.Trim(), StringComparison.OrdinalIgnoreCase);

            var user = await _firestore.GetUserByEmailAsync(normalizedEmail);
            if (user == null)
                return NotFound(new { error = "User not found" });

            var userId = user.GetValueOrDefault("id")?.ToString() ?? "";
            var ob = await _firestore.GetOnboardingByUserIdAsync(userId);
            var userPayload = BuildLoginUserResponse(user, ob, isSpecialSession);

            var status = user.GetValueOrDefault("status")?.ToString() ?? "Active";
            if (!isSpecialSession && !"Active".Equals(status, StringComparison.OrdinalIgnoreCase))
                return StatusCode(403, new { error = $"Your account status is '{status}'. Please wait for admin approval to activate your account.", status });

            var modRole = user.GetValueOrDefault("moduleAccessRole")?.ToString() ?? ob?.GetValueOrDefault("moduleAccessRole")?.ToString() ?? "";
            var roles = ParseModuleAccessRoleToRoles(modRole);
            if (isSpecialSession) roles = new List<string> { "admin" };

            var fullName = (userPayload["name"] ?? "").ToString() ?? "";
            var plainToken = _tokenService.GenerateTokenFromDict(userId, normalizedEmail, fullName, roles: roles);
            var encryptedToken = _tokenService.EncryptToken(plainToken);

            try
            {
                await _firestore.UpdateUserAsync(userId, new Dictionary<string, object> { ["lastSignInAt"] = DateTime.UtcNow });
            }
            catch { }
            try
            {
                var obUpdates = new Dictionary<string, object>
                {
                    ["token"] = encryptedToken,
                    ["token_updated_at"] = DateTime.UtcNow,
                    ["fullName"] = fullName,
                    ["email"] = normalizedEmail
                };
                if (!isSpecialSession) obUpdates["updated_at"] = DateTime.UtcNow;
                await _firestore.UpdateOnboardingByUserIdAsync(userId, obUpdates);
            }
            catch { }
            if (_pdhFirestore?.IsConfigured == true)
            {
                try
                {
                    await _pdhFirestore.SetOnboardingAsync(userId, new Dictionary<string, object>
                    {
                        ["email"] = normalizedEmail,
                        ["token"] = encryptedToken,
                        ["fullName"] = fullName,
                        ["token_updated_at"] = DateTime.UtcNow,
                        ["updated_at"] = DateTime.UtcNow
                    });
                }
                catch { }
            }

            return Ok(new { message = "Login successful", user = userPayload, token = encryptedToken });
        }

        [HttpGet("token")]
        [AllowAnonymous]
        public async Task<IActionResult> GetToken([FromQuery] string email, [FromQuery] string? module = null)
        {
            if (string.IsNullOrWhiteSpace(email))
                return BadRequest(new { error = "email is required" });

            var user = await _firestore.GetUserByEmailAsync(email.Trim().ToLowerInvariant());
            if (user == null)
                return NotFound(new { error = "User not found" });

            var userId = user.GetValueOrDefault("id")?.ToString() ?? "";
            var ob = await _firestore.GetOnboardingByUserIdAsync(userId);
            var modRole = user.GetValueOrDefault("moduleAccessRole")?.ToString() ?? ob?.GetValueOrDefault("moduleAccessRole")?.ToString() ?? "";
            var firstName = ob?.GetValueOrDefault("firstName")?.ToString() ?? ob?.GetValueOrDefault("name")?.ToString() ?? user.GetValueOrDefault("firstName")?.ToString() ?? "";
            var lastName = ob?.GetValueOrDefault("lastName")?.ToString() ?? ob?.GetValueOrDefault("surname")?.ToString() ?? user.GetValueOrDefault("lastName")?.ToString() ?? "";
            var fullName = $"{firstName} {lastName}".Trim();
            if (string.IsNullOrEmpty(fullName)) fullName = user.GetValueOrDefault("name")?.ToString() ?? "";

            var isArw = module != null && new[] { "recruitment", "arw" }.Contains(module.Trim().ToLowerInvariant());
            var roles = isArw ? ParseModuleAccessRoleToArwRoles(modRole) : ParseModuleAccessRoleToRoles(modRole);

            var plainToken = _tokenService.GenerateTokenFromDict(userId, user.GetValueOrDefault("email")?.ToString() ?? "", fullName, roles: roles);
            var encryptedToken = _tokenService.EncryptToken(plainToken);

            if (!isArw)
            {
                try
                {
                    var obUpdates = new Dictionary<string, object> { ["token"] = encryptedToken, ["token_updated_at"] = DateTime.UtcNow, ["fullName"] = fullName, ["email"] = user.GetValueOrDefault("email") ?? "", ["updated_at"] = DateTime.UtcNow };
                    await _firestore.UpdateOnboardingByUserIdAsync(userId, obUpdates);
                }
                catch { }
                if (_pdhFirestore?.IsConfigured == true)
                {
                    try
                    {
                        await _pdhFirestore.SetOnboardingAsync(userId, new Dictionary<string, object> { ["email"] = user.GetValueOrDefault("email") ?? "", ["token"] = encryptedToken, ["fullName"] = fullName, ["token_updated_at"] = DateTime.UtcNow, ["updated_at"] = DateTime.UtcNow });
                    }
                    catch { }
                }
            }

            return Ok(new { token = encryptedToken, email = user.GetValueOrDefault("email") ?? "", moduleAccessRole = modRole });
        }

        private static Dictionary<string, object> BuildLoginUserResponse(Dictionary<string, object> user, Dictionary<string, object>? ob, bool isSpecialSession)
        {
            var uid = user.GetValueOrDefault("id")?.ToString() ?? "";
            var firstName = ob?.GetValueOrDefault("firstName")?.ToString() ?? ob?.GetValueOrDefault("name")?.ToString() ?? user.GetValueOrDefault("firstName")?.ToString() ?? "";
            var lastName = ob?.GetValueOrDefault("lastName")?.ToString() ?? ob?.GetValueOrDefault("surname")?.ToString() ?? user.GetValueOrDefault("lastName")?.ToString() ?? "";
            var fullName = $"{firstName} {lastName}".Trim();
            if (string.IsNullOrEmpty(fullName)) fullName = user.GetValueOrDefault("name")?.ToString() ?? "";
            var modAccess = user.GetValueOrDefault("moduleAccess")?.ToString() ?? ob?.GetValueOrDefault("moduleAccess")?.ToString() ?? "";
            var modRole = user.GetValueOrDefault("moduleAccessRole")?.ToString() ?? ob?.GetValueOrDefault("moduleAccessRole")?.ToString() ?? "";
            if (string.IsNullOrEmpty(modAccess) && !string.IsNullOrEmpty(modRole) && modRole.Contains("PDH", StringComparison.OrdinalIgnoreCase))
                modAccess = "Personal Development Hub";
            return new Dictionary<string, object>
            {
                ["id"] = uid,
                ["email"] = user.GetValueOrDefault("email") ?? "",
                ["name"] = fullName,
                ["role"] = isSpecialSession ? "Admin" : (user.GetValueOrDefault("role")?.ToString() ?? "Staff"),
                ["status"] = user.GetValueOrDefault("status") ?? "Active",
                ["moduleAccess"] = modAccess,
                ["moduleAccessRole"] = modRole,
                ["profileImageUrl"] = ob?.GetValueOrDefault("profileImageUrl")?.ToString() ?? "",
                ["profileImagePublicId"] = ob?.GetValueOrDefault("profileImagePublicId")?.ToString() ?? ""
            };
        }

        private static List<string> ParseModuleAccessRoleToRoles(string moduleAccessRole)
        {
            if (string.IsNullOrWhiteSpace(moduleAccessRole)) return new List<string>();
            return moduleAccessRole.Split(',').Select(r => r.Trim()).Where(r => r.Length > 0).ToList();
        }

        private static List<string> ParseModuleAccessRoleToArwRoles(string moduleAccessRole)
        {
            if (string.IsNullOrWhiteSpace(moduleAccessRole)) return new List<string>();
            const string prefix = "Automated Recruitment Workflow - ";
            return moduleAccessRole.Split(',').Select(p => p.Trim()).Where(p => p.StartsWith(prefix)).Select(p => "ARW - " + p[prefix.Length..].Trim()).Where(r => r.Length > 5).ToList();
        }

        [HttpPost("otp/verify")]
        public async Task<IActionResult> VerifyOtp([FromBody] OTPVerification request)
        {

            try
            {
                var isValid = await _otpService.VerifyOtpAsync(request.Email, request.Code);
                if (!isValid)
                {
                    return BadRequest(new { Message = "Invalid or expired OTP." });
                }

                var response = new
                {
                    Valid = true,
                    Message = "OTP verified successfully."
                };

                return Ok(response);
            }
            catch (Exception)
            {
                return StatusCode(500, new { Message = "OTP verification failed." });
            }
        }
    }
}
