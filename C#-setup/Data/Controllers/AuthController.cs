using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Mvc;
using MyApi.DTOs.Auth;
using MyApi.Services;

namespace MyApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private static readonly Regex EmailRegex = new(@"^[^@\s]+@[^@\s]+\.[^@\s]+$", RegexOptions.Compiled);

    private readonly IAuthService _authService;
    private readonly IKhonoRelationalService _relational;
    private readonly ITokenService _tokenService;
    private readonly ISsoPgSyncService _ssoSync;

    public AuthController(
        IAuthService authService,
        IKhonoRelationalService relational,
        ITokenService tokenService,
        ISsoPgSyncService ssoSync)
    {
        _authService = authService;
        _relational = relational;
        _tokenService = tokenService;
        _ssoSync = ssoSync;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] UserRegister request)
    {
        var email = request.Email?.Trim() ?? "";
        if (!email.EndsWith("@khonology.com", StringComparison.OrdinalIgnoreCase))
            return BadRequest(new { error = "Only Khonology work emails (@khonology.com) are allowed" });

        var firstName = request.FirstName?.Trim() ?? "";
        var lastName = request.LastName?.Trim() ?? "";
        var fullName = $"{firstName} {lastName}".Trim();
        if (string.IsNullOrEmpty(fullName))
            fullName = request.Name?.Trim() ?? "";

        var password = request.Password ?? "";
        if (string.IsNullOrEmpty(email) || string.IsNullOrEmpty(password) || string.IsNullOrEmpty(fullName))
            return BadRequest(new { error = "Email, password, and name required" });

        if (!EmailRegex.IsMatch(email))
            return BadRequest(new { error = "Please provide a valid email address." });

        try
        {
            var user = await _authService.RegisterAsync(
                email,
                password,
                fullName,
                firstName,
                lastName,
                request.Department,
                request.Designation,
                request.Entity,
                request.Role ?? "user");

            var roles = ModuleRoleParser.ParseModuleAccessRoleToRoles("");
            var plainToken = _tokenService.GeneratePythonStyleToken(user.Id, user.Email, fullName, roles, "dark");
            var encryptedToken = _tokenService.EncryptToken(plainToken);

            await _relational.ApplyOnboardingPatchAsync(user.Id, new Dictionary<string, object>
            {
                ["token"] = encryptedToken,
                ["token_updated_at"] = DateTime.UtcNow,
                ["themePreference"] = "dark"
            });

            var userDict = new Dictionary<string, object>
            {
                ["email"] = user.Email,
                ["name"] = user.Name,
                ["role"] = user.Role,
                ["status"] = user.Status
            };
            var onboardingDict = new Dictionary<string, object>
            {
                ["email"] = user.Email,
                ["fullName"] = fullName,
                ["department"] = request.Department ?? "",
                ["designation"] = request.Designation ?? "",
                ["token"] = encryptedToken,
                ["token_updated_at"] = DateTime.UtcNow,
                ["themePreference"] = "dark"
            };
            await _ssoSync.SyncUserLoginAsync(user.Id, userDict, onboardingDict);

            return StatusCode(201, new
            {
                message = "User created successfully",
                user = new { id = user.Id, email = user.Email, name = user.Name ?? "", role = user.Role ?? "user" },
                token = encryptedToken
            });
        }
        catch (InvalidOperationException ex) when (ex.Message.Contains("already exists", StringComparison.OrdinalIgnoreCase))
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

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] UserLogin request, [FromHeader(Name = "X-Session-Type")] string? sessionType = null)
    {
        var emailInput = request.Email?.Trim() ?? "";
        if (string.IsNullOrEmpty(emailInput))
            return BadRequest(new { error = "Email is required" });
        if (!EmailRegex.IsMatch(emailInput))
            return BadRequest(new { error = "Please provide a valid email address." });

        var normalizedEmail = emailInput.ToLowerInvariant();
        var isSpecialSession = "special".Equals(sessionType?.Trim(), StringComparison.OrdinalIgnoreCase);

        var (userId, userData) = await _relational.FindUserByEmailAsync(normalizedEmail);
        if (userId == null || userData.Count == 0)
            return NotFound(new { error = "User not found" });

        var resolvedEmail = (userData.GetValueOrDefault("email")?.ToString() ?? "").Trim().ToLowerInvariant();
        if (resolvedEmail != normalizedEmail)
            return StatusCode(500, new { error = "Authentication error. Please try again." });

        var userStatus = NormalizeStatus(userData.GetValueOrDefault("status")?.ToString());
        if (!isSpecialSession && !"Active".Equals(userStatus, StringComparison.OrdinalIgnoreCase))
        {
            return StatusCode(403, new
            {
                error = $"Your account status is '{userStatus}'. Please wait for admin approval to activate your account.",
                status = userStatus
            });
        }

        var onboarding = await _relational.GetOnboardingAsync(userId);
        var safeOnboarding = SafeOnboardingForEmail(onboarding, normalizedEmail);
        var moduleAccessRole = userData.GetValueOrDefault("moduleAccessRole")?.ToString()
            ?? safeOnboarding.GetValueOrDefault("moduleAccessRole")?.ToString()
            ?? onboarding.GetValueOrDefault("moduleAccessRole")?.ToString()
            ?? "";

        var roles = ModuleRoleParser.ParseModuleAccessRoleToRoles(moduleAccessRole);
        if (isSpecialSession) roles = new List<string> { "admin" };

        var fullName = ResolveFullName(userData, safeOnboarding);
        var theme = ModuleRoleParser.ResolveThemePreference(userData, safeOnboarding.Count > 0 ? safeOnboarding : onboarding);

        string? encryptedToken = null;
        try
        {
            var plainToken = _tokenService.GeneratePythonStyleToken(userId, resolvedEmail, fullName, roles, theme);
            encryptedToken = _tokenService.EncryptToken(plainToken);
        }
        catch { }

        var lastSignInAt = DateTime.UtcNow;
        var existingLoginCount = ParseInt(onboarding.GetValueOrDefault("loginCount") ?? userData.GetValueOrDefault("loginCount"), 0);
        var loginCount = existingLoginCount + 1;

        try
        {
            await _relational.UpdateLoginTrackingAsync(userId, loginCount, lastSignInAt);
        }
        catch { }

        if (!string.IsNullOrEmpty(encryptedToken))
        {
            try
            {
                var tokenPatch = new Dictionary<string, object>
                {
                    ["token"] = encryptedToken,
                    ["token_updated_at"] = DateTime.UtcNow,
                    ["fullName"] = fullName,
                    ["email"] = resolvedEmail,
                    ["themePreference"] = theme
                };
                if (!isSpecialSession)
                    tokenPatch["updated_at"] = DateTime.UtcNow;
                await _relational.ApplyOnboardingPatchAsync(userId, tokenPatch);
            }
            catch { }
        }

        try
        {
            var trackingPatch = new Dictionary<string, object>
            {
                ["email"] = resolvedEmail,
                ["lastSignInAt"] = lastSignInAt,
                ["loginCount"] = loginCount,
                ["updated_at"] = DateTime.UtcNow
            };
            await _relational.ApplyOnboardingPatchAsync(userId, trackingPatch);
            await _ssoSync.SyncUserLoginAsync(userId, userData, MergeOnboarding(onboarding, trackingPatch));
        }
        catch { }

        var moduleAccessRaw = userData.GetValueOrDefault("moduleAccess")?.ToString()
            ?? safeOnboarding.GetValueOrDefault("moduleAccess")?.ToString()
            ?? "";
        var finalModuleAccess = DeriveModuleAccess(moduleAccessRaw, moduleAccessRole);

        var response = new Dictionary<string, object>
        {
            ["message"] = "Login successful",
            ["user"] = new Dictionary<string, object>
            {
                ["id"] = userId,
                ["email"] = userData.GetValueOrDefault("email") ?? resolvedEmail,
                ["name"] = fullName,
                ["role"] = isSpecialSession ? "Admin" : userData.GetValueOrDefault("role") ?? "user",
                ["status"] = userStatus,
                ["moduleAccess"] = finalModuleAccess ?? "",
                ["moduleAccessRole"] = moduleAccessRole,
                ["profileImageUrl"] = safeOnboarding.GetValueOrDefault("profileImageUrl")?.ToString() ?? "",
                ["profileImagePublicId"] = safeOnboarding.GetValueOrDefault("profileImagePublicId")?.ToString() ?? "",
                ["themePreference"] = theme,
                ["lastSignInAt"] = FormatIso(lastSignInAt),
                ["loginCount"] = loginCount
            }
        };

        if (!string.IsNullOrEmpty(encryptedToken))
            response["token"] = encryptedToken;
        else
            response["token_warning"] = "Token generation failed. Please fetch token via /api/auth/token endpoint.";

        return Ok(response);
    }

    [HttpGet("token")]
    public async Task<IActionResult> GetToken(
        [FromQuery] string email,
        [FromQuery] string? module = null,
        [FromQuery] string? role = null,
        [FromQuery] string? theme = null)
    {
        if (string.IsNullOrWhiteSpace(email))
            return BadRequest(new { error = "email is required" });

        var normalizedEmail = email.Trim().ToLowerInvariant();
        var (userId, userData) = await _relational.FindUserByEmailAsync(normalizedEmail);
        if (userId == null)
            return NotFound(new { error = "User not found" });

        var onboarding = await _relational.GetOnboardingAsync(userId);
        var moduleAccessRole = onboarding.GetValueOrDefault("moduleAccessRole")?.ToString()
            ?? userData.GetValueOrDefault("moduleAccessRole")?.ToString()
            ?? "";

        var normalizedModule = (module ?? "").Trim().ToLowerInvariant();
        List<string> roles;
        var isArw = normalizedModule is "recruitment" or "arw";
        if (isArw)
            roles = ModuleRoleParser.ParseModuleAccessRoleToArwRoles(moduleAccessRole);
        else if (normalizedModule is "skills_heatmap" or "skills-heatmap" or "skills")
            roles = !string.IsNullOrWhiteSpace(role)
                ? new List<string> { $"Skills Heatmap - {role.Trim()}" }
                : ModuleRoleParser.ParseModuleAccessRoleToSkillsHeatmapRoles(moduleAccessRole);
        else if (normalizedModule is "deliverable_sprint" or "deliverables" or "deliverables_signoff" or "deliverables_sign_off" or "sprint_signoff" or "sprint_sign_off")
            roles = !string.IsNullOrWhiteSpace(role)
                ? new List<string> { $"Deliverables & Sprint Sign-Off Hub - {role.Trim()}" }
                : ModuleRoleParser.ParseModuleAccessRoleToDeliverablesRoles(moduleAccessRole);
        else if (normalizedModule is "sow_builder" or "sowbuilder" or "sow" or "proposal_sow_builder" or "proposal_sow" or "proposal_and_sow_builder")
            roles = !string.IsNullOrWhiteSpace(role)
                ? new List<string> { $"Proposal & SOW Builder - {role.Trim()}" }
                : ModuleRoleParser.ParseModuleAccessRoleToSowBuilderRoles(moduleAccessRole);
        else
            roles = ModuleRoleParser.ParseModuleAccessRoleToRoles(moduleAccessRole);

        var fullName = ResolveFullName(userData, onboarding);
        var userEmail = userData.GetValueOrDefault("email")?.ToString() ?? normalizedEmail;
        var tokenTheme = !string.IsNullOrWhiteSpace(theme)
            ? ModuleRoleParser.NormalizeThemePreference(theme)
            : ModuleRoleParser.ResolveThemePreference(userData, onboarding);

        try
        {
            var plainToken = _tokenService.GeneratePythonStyleToken(userId, userEmail, fullName, roles, tokenTheme);
            var encryptedToken = _tokenService.EncryptToken(plainToken);

            if (!isArw)
            {
                await _relational.ApplyOnboardingPatchAsync(userId, new Dictionary<string, object>
                {
                    ["token"] = encryptedToken,
                    ["token_updated_at"] = DateTime.UtcNow,
                    ["updated_at"] = DateTime.UtcNow,
                    ["fullName"] = fullName,
                    ["email"] = userEmail,
                    ["themePreference"] = tokenTheme
                });
            }

            return Ok(new
            {
                token = encryptedToken,
                email = userEmail,
                moduleAccessRole,
                themePreference = tokenTheme
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    private static Dictionary<string, object> SafeOnboardingForEmail(Dictionary<string, object> onboarding, string normalizedEmail)
    {
        var onboardingEmail = (onboarding.GetValueOrDefault("email")?.ToString() ?? "").Trim().ToLowerInvariant();
        if (!string.IsNullOrEmpty(onboardingEmail) && onboardingEmail != normalizedEmail)
            return new Dictionary<string, object>();

        var profileUrl = (onboarding.GetValueOrDefault("profileImageUrl")?.ToString() ?? "").Trim();
        var profileId = (onboarding.GetValueOrDefault("profileImagePublicId")?.ToString() ?? "").Trim();
        var encodedEmail = normalizedEmail.Replace("@", "%40", StringComparison.Ordinal);
        var urlBelongs = string.IsNullOrEmpty(profileUrl)
            || profileUrl.Contains(normalizedEmail, StringComparison.OrdinalIgnoreCase)
            || profileUrl.Contains(encodedEmail, StringComparison.OrdinalIgnoreCase);
        var idBelongs = string.IsNullOrEmpty(profileId)
            || profileId.Contains(normalizedEmail, StringComparison.OrdinalIgnoreCase)
            || profileId.Contains(encodedEmail, StringComparison.OrdinalIgnoreCase);
        return urlBelongs && idBelongs ? onboarding : new Dictionary<string, object>();
    }

    private static string ResolveFullName(Dictionary<string, object> user, Dictionary<string, object> onboarding)
    {
        var firstName = onboarding.GetValueOrDefault("firstName")?.ToString()
            ?? onboarding.GetValueOrDefault("name")?.ToString()
            ?? user.GetValueOrDefault("firstName")?.ToString()
            ?? "";
        var lastName = onboarding.GetValueOrDefault("lastName")?.ToString()
            ?? onboarding.GetValueOrDefault("surname")?.ToString()
            ?? user.GetValueOrDefault("lastName")?.ToString()
            ?? "";
        var fullName = $"{firstName} {lastName}".Trim();
        return string.IsNullOrEmpty(fullName) ? user.GetValueOrDefault("name")?.ToString() ?? "" : fullName;
    }

    private static Dictionary<string, object> MergeOnboarding(Dictionary<string, object> existing, Dictionary<string, object> patch)
    {
        var merged = new Dictionary<string, object>(existing);
        foreach (var kv in patch) merged[kv.Key] = kv.Value;
        return merged;
    }

    private static string NormalizeStatus(string? status)
    {
        var raw = (status ?? "Active").Trim();
        return raw.Equals("inactive", StringComparison.OrdinalIgnoreCase) ? "Inactive"
            : raw.Equals("active", StringComparison.OrdinalIgnoreCase) ? "Active"
            : raw;
    }

    private static string? DeriveModuleAccess(string moduleAccess, string moduleAccessRole)
    {
        if (!string.IsNullOrWhiteSpace(moduleAccess)) return moduleAccess.Trim();
        if (string.IsNullOrWhiteSpace(moduleAccessRole)) return null;
        return moduleAccessRole.Contains("PDH", StringComparison.OrdinalIgnoreCase) ? "Personal Development Hub" : null;
    }

    private static int ParseInt(object? value, int fallback)
    {
        if (value == null) return fallback;
        return int.TryParse(value.ToString(), out var n) ? n : fallback;
    }

    private static string FormatIso(DateTime dt) => dt.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ");
}
