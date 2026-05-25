using Microsoft.AspNetCore.Mvc;
using MyApi.Services;

namespace MyApi.Controllers;

[ApiController]
[Route("api/admin/users")]
public class AdminUsersController : ControllerBase
{
    private readonly IKhonoRelationalService _relational;
    private readonly ITokenService _tokenService;
    private readonly ISsoPgSyncService _ssoSync;

    public AdminUsersController(
        IKhonoRelationalService relational,
        ITokenService tokenService,
        ISsoPgSyncService ssoSync)
    {
        _relational = relational;
        _tokenService = tokenService;
        _ssoSync = ssoSync;
    }

    [HttpPut("{email}/profile")]
    public async Task<IActionResult> UpdateProfile(string email, [FromBody] AdminProfileUpdateRequest data)
    {
        var normalizedEmail = email.Trim().ToLowerInvariant();
        var (userId, user) = await _relational.FindUserByEmailAsync(normalizedEmail);
        if (userId == null)
            return NotFound(new { error = "User not found" });

        var firstName = data.FirstName ?? data.Name;
        var lastName = data.LastName ?? data.Surname;
        var preferredName = data.PreferredName;
        var fullName = "";
        if (firstName != null || lastName != null)
            fullName = $"{firstName ?? ""} {lastName ?? ""}".Trim();
        else if (!string.IsNullOrWhiteSpace(preferredName))
            fullName = preferredName.Trim();

        var themePreference = (data.ThemePreference ?? "").Trim().ToLowerInvariant();
        if (themePreference is not ("light" or "dark"))
            themePreference = "";

        var userPatch = new Dictionary<string, object> { ["updated_at"] = DateTime.UtcNow };
        if (data.Department != null) userPatch["department"] = data.Department;
        if (data.Designation != null) userPatch["designation"] = data.Designation;
        if (data.ManagedBy != null || data.Manager != null) userPatch["manager"] = data.ManagedBy ?? data.Manager ?? "";
        if (!string.IsNullOrEmpty(themePreference)) userPatch["themePreference"] = themePreference;
        if (!string.IsNullOrEmpty(fullName)) userPatch["name"] = fullName;

        var onboardingPatch = new Dictionary<string, object>
        {
            ["updated_at"] = DateTime.UtcNow,
            ["email"] = normalizedEmail
        };
        if (firstName != null) onboardingPatch["firstName"] = firstName;
        if (lastName != null)
        {
            onboardingPatch["lastName"] = lastName;
            onboardingPatch["surname"] = lastName;
        }
        if (preferredName != null) onboardingPatch["preferredName"] = preferredName;
        if (!string.IsNullOrEmpty(fullName)) onboardingPatch["fullName"] = fullName;
        if (data.Department != null) onboardingPatch["department"] = data.Department;
        if (data.Designation != null) onboardingPatch["designation"] = data.Designation;
        if (data.PhoneNumber != null) onboardingPatch["phoneNumber"] = data.PhoneNumber;
        if (data.ManagedBy != null || data.Manager != null) onboardingPatch["managedBy"] = data.ManagedBy ?? data.Manager ?? "";
        if (data.ProfileImageUrl != null) onboardingPatch["profileImageUrl"] = data.ProfileImageUrl;
        if (data.ProfileImagePublicId != null) onboardingPatch["profileImagePublicId"] = data.ProfileImagePublicId;
        if (!string.IsNullOrEmpty(themePreference)) onboardingPatch["themePreference"] = themePreference;

        await _relational.ApplyUserPatchAsync(userId, userPatch);
        await _relational.ApplyOnboardingPatchAsync(userId, onboardingPatch);

        string? regeneratedToken = null;
        if (!string.IsNullOrEmpty(themePreference))
        {
            try
            {
                var refreshedUser = (await _relational.FindUserByIdAsync(userId)).UserData;
                var refreshedOnboarding = await _relational.GetOnboardingAsync(userId);
                var moduleAccessRole = refreshedUser.GetValueOrDefault("moduleAccessRole")?.ToString()
                    ?? refreshedOnboarding.GetValueOrDefault("moduleAccessRole")?.ToString()
                    ?? "";
                var roles = ModuleRoleParser.ParseModuleAccessRoleToRoles(moduleAccessRole);
                var resolvedFullName = ResolveFullName(refreshedUser, refreshedOnboarding);
                var plainToken = _tokenService.GeneratePythonStyleToken(
                    userId, normalizedEmail, resolvedFullName, roles, themePreference);
                regeneratedToken = _tokenService.EncryptToken(plainToken);

                await _relational.ApplyOnboardingPatchAsync(userId, new Dictionary<string, object>
                {
                    ["token"] = regeneratedToken,
                    ["token_updated_at"] = DateTime.UtcNow,
                    ["fullName"] = resolvedFullName,
                    ["email"] = normalizedEmail,
                    ["themePreference"] = themePreference,
                    ["updated_at"] = DateTime.UtcNow
                });
            }
            catch { }
        }

        var mergedUser = (await _relational.FindUserByIdAsync(userId)).UserData;
        var mergedOnboarding = await _relational.GetOnboardingAsync(userId);
        await _ssoSync.SyncUserLoginAsync(userId, mergedUser, mergedOnboarding);

        var response = new Dictionary<string, object> { ["message"] = "Profile updated successfully" };
        if (!string.IsNullOrEmpty(regeneratedToken))
            response["token"] = regeneratedToken;
        return Ok(response);
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
}

public class AdminProfileUpdateRequest
{
    public string? FirstName { get; set; }
    public string? LastName { get; set; }
    public string? Name { get; set; }
    public string? Surname { get; set; }
    public string? PreferredName { get; set; }
    public string? Department { get; set; }
    public string? Designation { get; set; }
    public string? PhoneNumber { get; set; }
    public string? ManagedBy { get; set; }
    public string? Manager { get; set; }
    public string? ProfileImageUrl { get; set; }
    public string? ProfileImagePublicId { get; set; }
    public string? ThemePreference { get; set; }
}
