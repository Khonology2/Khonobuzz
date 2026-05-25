using Microsoft.AspNetCore.Mvc;
using MyApi.DTOs.User;
using MyApi.Services;

namespace MyApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class UsersController(IKhonoRelationalService relational, ITokenService tokenService) : ControllerBase
{
    [HttpGet("by-email")]
    public async Task<IActionResult> GetUserByEmail([FromQuery] string email)
    {
        if (string.IsNullOrWhiteSpace(email))
            return BadRequest(new { error = "email is required" });

        var normalizedEmail = email.Trim().ToLowerInvariant();
        var (userId, userInfo) = await relational.FindUserByEmailAsync(normalizedEmail);
        if (userId == null || userInfo.Count == 0)
            return NotFound(new { error = "User not found" });

        var onboardingInfo = await relational.GetOnboardingAsync(userId);
        var safeOnboarding = SafeOnboardingForEmail(onboardingInfo, normalizedEmail);

        var moduleAccessRaw = userInfo.GetValueOrDefault("moduleAccess")?.ToString()
            ?? onboardingInfo.GetValueOrDefault("moduleAccess")?.ToString()
            ?? "";
        var moduleAccessRoleRaw = userInfo.GetValueOrDefault("moduleAccessRole")?.ToString()
            ?? onboardingInfo.GetValueOrDefault("moduleAccessRole")?.ToString()
            ?? "";

        var responseUser = new Dictionary<string, object?>
        {
            ["email"] = userInfo.GetValueOrDefault("email") ?? normalizedEmail,
            ["role"] = userInfo.GetValueOrDefault("role") ?? "",
            ["status"] = NormalizeStatus(userInfo.GetValueOrDefault("status")?.ToString()),
            ["entity"] = userInfo.GetValueOrDefault("entity") ?? onboardingInfo.GetValueOrDefault("entity") ?? "",
            ["moduleAccess"] = moduleAccessRaw,
            ["moduleAccessRole"] = moduleAccessRoleRaw,
            ["firstName"] = safeOnboarding.GetValueOrDefault("firstName") ?? userInfo.GetValueOrDefault("firstName") ?? SplitName(userInfo.GetValueOrDefault("name")?.ToString(), 0),
            ["lastName"] = safeOnboarding.GetValueOrDefault("lastName") ?? safeOnboarding.GetValueOrDefault("surname") ?? userInfo.GetValueOrDefault("lastName") ?? SplitName(userInfo.GetValueOrDefault("name")?.ToString(), 1),
            ["surname"] = safeOnboarding.GetValueOrDefault("surname") ?? safeOnboarding.GetValueOrDefault("lastName") ?? userInfo.GetValueOrDefault("lastName") ?? "",
            ["preferredName"] = safeOnboarding.GetValueOrDefault("preferredName") ?? userInfo.GetValueOrDefault("preferredName") ?? "",
            ["phoneNumber"] = safeOnboarding.GetValueOrDefault("phoneNumber") ?? userInfo.GetValueOrDefault("phoneNumber") ?? "",
            ["department"] = safeOnboarding.GetValueOrDefault("department") ?? userInfo.GetValueOrDefault("department") ?? "",
            ["designation"] = safeOnboarding.GetValueOrDefault("designation") ?? userInfo.GetValueOrDefault("designation") ?? "",
            ["managedBy"] = safeOnboarding.GetValueOrDefault("managedBy") ?? userInfo.GetValueOrDefault("manager") ?? onboardingInfo.GetValueOrDefault("manager") ?? "",
            ["profileImageUrl"] = safeOnboarding.GetValueOrDefault("profileImageUrl") ?? "",
            ["profileImagePublicId"] = safeOnboarding.GetValueOrDefault("profileImagePublicId") ?? "",
            ["themePreference"] = safeOnboarding.GetValueOrDefault("themePreference") ?? userInfo.GetValueOrDefault("themePreference") ?? "dark",
            ["lastSignInAt"] = FormatIso(userInfo.GetValueOrDefault("lastSignInAt") ?? onboardingInfo.GetValueOrDefault("lastSignInAt")) ?? "",
            ["loginCount"] = ParseInt(onboardingInfo.GetValueOrDefault("loginCount") ?? userInfo.GetValueOrDefault("loginCount"), 0)
        };

        return Ok(new { user = responseUser });
    }

    [HttpGet]
    public async Task<IActionResult> ListUsers()
    {
        var users = await relational.ListUsersPayloadsAsync();
        foreach (var user in users)
            user["status"] = NormalizeStatus(user.GetValueOrDefault("status")?.ToString());
        return Ok(new { users });
    }

    [HttpGet("{userId}")]
    public async Task<IActionResult> GetUser(string userId)
    {
        var (id, user) = await relational.FindUserByIdAsync(userId);
        if (id == null)
            return NotFound(new { error = $"User {userId} not found" });

        var onboarding = await relational.GetOnboardingAsync(userId);
        return Ok(BuildUserPayload(userId, user, onboarding));
    }

    [HttpPatch("{userId}")]
    public async Task<IActionResult> UpdateUser(
        string userId,
        [FromBody] UserUpdate userUpdate,
        [FromHeader(Name = "X-Session-Type")] string? sessionType = null)
    {
        var isSpecialSession = "special".Equals(sessionType?.Trim(), StringComparison.OrdinalIgnoreCase);
        var updatePayload = new Dictionary<string, object>();
        var onboardingPayload = new Dictionary<string, object>();

        if (userUpdate.Role != null) { updatePayload["role"] = userUpdate.Role; onboardingPayload["role"] = userUpdate.Role; }
        if (userUpdate.Status != null)
        {
            var status = NormalizeStatus(userUpdate.Status);
            updatePayload["status"] = status;
            onboardingPayload["status"] = status;
        }
        if (userUpdate.Entity != null) { updatePayload["entity"] = userUpdate.Entity; onboardingPayload["entity"] = userUpdate.Entity; }
        if (userUpdate.Department != null) { updatePayload["department"] = userUpdate.Department; onboardingPayload["department"] = userUpdate.Department; }
        if (userUpdate.Designation != null) { updatePayload["designation"] = userUpdate.Designation; onboardingPayload["designation"] = userUpdate.Designation; }
        if (userUpdate.Manager != null) { updatePayload["manager"] = userUpdate.Manager; onboardingPayload["manager"] = userUpdate.Manager; }
        if (userUpdate.ModuleAccess != null) { updatePayload["moduleAccess"] = userUpdate.ModuleAccess; onboardingPayload["moduleAccess"] = userUpdate.ModuleAccess; }
        if (userUpdate.ModuleRole != null) { updatePayload["moduleRole"] = userUpdate.ModuleRole; onboardingPayload["moduleRole"] = userUpdate.ModuleRole; }
        if (userUpdate.ModuleAccessRole != null) { updatePayload["moduleAccessRole"] = userUpdate.ModuleAccessRole; onboardingPayload["moduleAccessRole"] = userUpdate.ModuleAccessRole; }
        if (userUpdate.AdminApproved != null && !isSpecialSession)
        {
            updatePayload["admin"] = new Dictionary<string, object> { ["approved"] = userUpdate.AdminApproved };
            onboardingPayload["admin"] = new Dictionary<string, object> { ["approved"] = userUpdate.AdminApproved };
        }

        if (updatePayload.Count == 0)
            return BadRequest(new { error = "No valid fields provided for update" });

        if (!isSpecialSession)
            updatePayload["updated_at"] = DateTime.UtcNow;

        var (_, currentUser) = await relational.FindUserByIdAsync(userId);
        if (currentUser.Count == 0)
            return NotFound(new { error = $"User {userId} not found" });

        await relational.ApplyUserPatchAsync(userId, updatePayload);
        if (onboardingPayload.Count > 0)
        {
            if (!isSpecialSession)
                onboardingPayload["updated_at"] = DateTime.UtcNow;
            await relational.ApplyOnboardingPatchAsync(userId, onboardingPayload);
        }

        if (userUpdate.ModuleAccessRole != null && userUpdate.RegenerateToken is true)
        {
            try
            {
                var onboarding = await relational.GetOnboardingAsync(userId);
                var userEmail = currentUser.GetValueOrDefault("email")?.ToString() ?? onboarding.GetValueOrDefault("email")?.ToString() ?? "";
                var roles = ModuleRoleParser.ParseModuleAccessRoleToRoles(userUpdate.ModuleAccessRole);
                var fullName = ResolveFullName(currentUser, onboarding);
                var theme = ModuleRoleParser.ResolveThemePreference(currentUser, onboarding);
                var plainToken = tokenService.GeneratePythonStyleToken(userId, userEmail, fullName, roles, theme);
                var encryptedToken = tokenService.EncryptToken(plainToken);
                await relational.ApplyOnboardingPatchAsync(userId, new Dictionary<string, object>
                {
                    ["token"] = encryptedToken,
                    ["token_updated_at"] = DateTime.UtcNow,
                    ["fullName"] = fullName,
                    ["email"] = userEmail,
                    ["updated_at"] = DateTime.UtcNow
                });
            }
            catch { }
        }

        var updatedUser = (await relational.FindUserByIdAsync(userId)).UserData;
        var updatedOnboarding = await relational.GetOnboardingAsync(userId);
        return Ok(new
        {
            message = "User updated successfully",
            user = BuildUserPayload(userId, updatedUser, updatedOnboarding)
        });
    }

    [HttpDelete("{userId}")]
    public async Task<IActionResult> DeleteUser(string userId)
    {
        var deleted = await relational.DeleteUserAsync(userId);
        if (!deleted)
            return NotFound(new { error = $"User {userId} not found" });
        return Ok(new { message = "User deleted successfully" });
    }

    private static Dictionary<string, object> BuildUserPayload(string userId, Dictionary<string, object> user, Dictionary<string, object> onboarding)
    {
        var firstName = onboarding.GetValueOrDefault("firstName")?.ToString() ?? onboarding.GetValueOrDefault("name")?.ToString() ?? "";
        var lastName = onboarding.GetValueOrDefault("lastName")?.ToString() ?? onboarding.GetValueOrDefault("surname")?.ToString() ?? "";
        return new Dictionary<string, object>
        {
            ["id"] = userId,
            ["email"] = user.GetValueOrDefault("email") ?? "",
            ["role"] = user.GetValueOrDefault("role") ?? "Staff",
            ["status"] = NormalizeStatus(user.GetValueOrDefault("status")?.ToString()),
            ["firstName"] = firstName,
            ["lastName"] = lastName,
            ["department"] = onboarding.GetValueOrDefault("department") ?? "",
            ["designation"] = onboarding.GetValueOrDefault("designation") ?? "",
            ["entity"] = user.GetValueOrDefault("entity") ?? onboarding.GetValueOrDefault("entity") ?? "",
            ["manager"] = user.GetValueOrDefault("manager") ?? onboarding.GetValueOrDefault("manager") ?? "",
            ["moduleAccess"] = user.GetValueOrDefault("moduleAccess") ?? onboarding.GetValueOrDefault("moduleAccess") ?? "",
            ["moduleRole"] = user.GetValueOrDefault("moduleRole") ?? onboarding.GetValueOrDefault("moduleRole") ?? "",
            ["moduleAccessRole"] = user.GetValueOrDefault("moduleAccessRole") ?? onboarding.GetValueOrDefault("moduleAccessRole") ?? "",
            ["createdAt"] = FormatIso(user.GetValueOrDefault("created_at")) ?? "",
            ["updatedAt"] = FormatIso(user.GetValueOrDefault("updated_at")) ?? "",
            ["lastSignInAt"] = FormatIso(user.GetValueOrDefault("lastSignInAt") ?? onboarding.GetValueOrDefault("lastSignInAt")) ?? "",
            ["loginCount"] = ParseInt(onboarding.GetValueOrDefault("loginCount") ?? user.GetValueOrDefault("loginCount"), 0)
        };
    }

    private static Dictionary<string, object> SafeOnboardingForEmail(Dictionary<string, object> onboarding, string normalizedEmail)
    {
        var onboardingEmail = (onboarding.GetValueOrDefault("email")?.ToString() ?? "").Trim().ToLowerInvariant();
        if (!string.IsNullOrEmpty(onboardingEmail) && onboardingEmail != normalizedEmail)
            return [];

        var profileUrl = (onboarding.GetValueOrDefault("profileImageUrl")?.ToString() ?? "").Trim();
        var profileId = (onboarding.GetValueOrDefault("profileImagePublicId")?.ToString() ?? "").Trim();
        var encodedEmail = normalizedEmail.Replace("@", "%40", StringComparison.Ordinal);
        var urlBelongs = string.IsNullOrEmpty(profileUrl)
            || profileUrl.Contains(normalizedEmail, StringComparison.OrdinalIgnoreCase)
            || profileUrl.Contains(encodedEmail, StringComparison.OrdinalIgnoreCase);
        var idBelongs = string.IsNullOrEmpty(profileId)
            || profileId.Contains(normalizedEmail, StringComparison.OrdinalIgnoreCase)
            || profileId.Contains(encodedEmail, StringComparison.OrdinalIgnoreCase);
        return urlBelongs && idBelongs ? onboarding : [];
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

    private static string NormalizeStatus(string? status)
    {
        var raw = (status ?? "Active").Trim();
        return raw.Equals("inactive", StringComparison.OrdinalIgnoreCase) ? "Inactive"
            : raw.Equals("active", StringComparison.OrdinalIgnoreCase) ? "Active"
            : raw;
    }

    private static string? SplitName(string? name, int index)
    {
        if (string.IsNullOrWhiteSpace(name)) return index == 0 ? "" : "";
        var parts = name.Split(' ', StringSplitOptions.RemoveEmptyEntries);
        return index < parts.Length ? parts[index] : "";
    }

    private static int ParseInt(object? value, int fallback)
    {
        if (value == null) return fallback;
        return int.TryParse(value.ToString(), out var n) ? n : fallback;
    }

    private static string? FormatIso(object? value)
    {
        if (value == null) return null;
        if (value is DateTime dt) return dt.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ");
        if (DateTime.TryParse(value.ToString(), out var parsed)) return parsed.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ");
        return null;
    }
}
