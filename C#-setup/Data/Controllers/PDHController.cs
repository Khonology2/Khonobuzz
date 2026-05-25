using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using MyApi.Services;

namespace MyApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class PDHController : ControllerBase
{
    private readonly IKhonoRelationalService _relational;
    private readonly ITokenService _tokenService;
    private readonly ISsoPgSyncService _ssoSync;

    public PDHController(
        IKhonoRelationalService relational,
        ITokenService tokenService,
        ISsoPgSyncService ssoSync)
    {
        _relational = relational;
        _tokenService = tokenService;
        _ssoSync = ssoSync;
    }

    [HttpPost("sync-user")]
    public async Task<IActionResult> SyncUser([FromBody] JsonElement body)
    {
        try
        {
            var uid = body.GetProperty("uid").GetString() ?? "";
            var userData = JsonElementToDict(body.GetProperty("userData"));
            var onboardingData = JsonElementToDict(body.GetProperty("onboardingData"));

            var moduleAccessRole = GetStr(onboardingData, "moduleAccessRole") ?? GetStr(userData, "moduleAccessRole") ?? "";
            var userEmail = GetStr(userData, "email") ?? GetStr(onboardingData, "email") ?? "";
            if (!string.IsNullOrEmpty(userEmail) && !onboardingData.ContainsKey("email"))
                onboardingData["email"] = userEmail;

            var roles = ModuleRoleParser.ParseModuleAccessRoleToRoles(moduleAccessRole);
            var fullName = ResolveFullName(userData, onboardingData);
            onboardingData["fullName"] = fullName;

            if (!onboardingData.ContainsKey("token") || string.IsNullOrEmpty(GetStr(onboardingData, "token")))
            {
                if (!string.IsNullOrEmpty(moduleAccessRole) && !string.IsNullOrEmpty(userEmail))
                {
                    var theme = ModuleRoleParser.ResolveThemePreference(userData, onboardingData);
                    var plainToken = _tokenService.GeneratePythonStyleToken(uid, userEmail, fullName, roles, theme);
                    onboardingData["token"] = _tokenService.EncryptToken(plainToken);
                    onboardingData["token_updated_at"] = DateTime.UtcNow;
                }
            }

            await _relational.ApplyUserPatchAsync(uid, userData);
            await _relational.ApplyOnboardingPatchAsync(uid, onboardingData);
            await _ssoSync.SyncUserLoginAsync(uid, userData, onboardingData);

            return Ok(new { message = "PDH sync successful" });
        }
        catch (Exception e)
        {
            return StatusCode(500, new { error = e.Message });
        }
    }

    [HttpPatch("update-user/{uid}")]
    public async Task<IActionResult> UpdateUser(string uid, [FromBody] JsonElement body)
    {
        try
        {
            Dictionary<string, object>? userFields = null;
            Dictionary<string, object>? onboardingFields = null;
            if (body.TryGetProperty("userFields", out var uf)) userFields = JsonElementToDict(uf);
            if (body.TryGetProperty("onboardingFields", out var of)) onboardingFields = JsonElementToDict(of);
            var userFieldsDict = userFields ?? new Dictionary<string, object>();

            var shouldRegenerate = false;
            var newModuleAccessRole = "";
            if (onboardingFields != null && onboardingFields.ContainsKey("moduleAccessRole"))
            {
                shouldRegenerate = true;
                newModuleAccessRole = GetStr(onboardingFields, "moduleAccessRole") ?? "";
            }
            else if (userFields != null && userFields.ContainsKey("moduleAccessRole"))
            {
                shouldRegenerate = true;
                newModuleAccessRole = GetStr(userFields, "moduleAccessRole") ?? "";
            }

            if (userFields != null)
                await _relational.ApplyUserPatchAsync(uid, userFields);

            if (onboardingFields != null)
            {
                var userEmail = GetStr(onboardingFields, "email") ?? GetStr(userFieldsDict, "email") ?? "";
                if (!string.IsNullOrEmpty(userEmail) && !onboardingFields.ContainsKey("email"))
                    onboardingFields["email"] = userEmail;

                var fullName = ResolveFullName(userFieldsDict, onboardingFields);
                onboardingFields["fullName"] = fullName;

                if (shouldRegenerate && !string.IsNullOrEmpty(userEmail))
                {
                    var roles = ModuleRoleParser.ParseModuleAccessRoleToRoles(newModuleAccessRole);
                    var theme = ModuleRoleParser.ResolveThemePreference(userFieldsDict, onboardingFields);
                    var plainToken = _tokenService.GeneratePythonStyleToken(uid, userEmail, fullName, roles, theme);
                    onboardingFields["token"] = _tokenService.EncryptToken(plainToken);
                    onboardingFields["token_updated_at"] = DateTime.UtcNow;
                }

                await _relational.ApplyOnboardingPatchAsync(uid, onboardingFields);
            }

            var mergedUser = userFieldsDict.Count > 0
                ? userFieldsDict
                : (await _relational.FindUserByIdAsync(uid)).UserData;
            var mergedOnboarding = onboardingFields ?? await _relational.GetOnboardingAsync(uid);
            await _ssoSync.SyncUserLoginAsync(uid, mergedUser, mergedOnboarding);

            return Ok(new { message = "PDH update successful" });
        }
        catch (Exception e)
        {
            return StatusCode(500, new { error = e.Message });
        }
    }

    private static string ResolveFullName(Dictionary<string, object> user, Dictionary<string, object> onboarding)
    {
        var firstName = GetStr(onboarding, "firstName") ?? GetStr(onboarding, "name") ?? GetStr(user, "firstName") ?? "";
        var lastName = GetStr(onboarding, "lastName") ?? GetStr(onboarding, "surname") ?? GetStr(user, "lastName") ?? "";
        var fullName = $"{firstName} {lastName}".Trim();
        return string.IsNullOrEmpty(fullName) ? GetStr(user, "name") ?? "" : fullName;
    }

    private static Dictionary<string, object> JsonElementToDict(JsonElement el)
    {
        var d = new Dictionary<string, object>();
        foreach (var p in el.EnumerateObject())
            d[p.Name] = JsonElementToObject(p.Value) ?? "";
        return d;
    }

    private static object? JsonElementToObject(JsonElement el) => el.ValueKind switch
    {
        JsonValueKind.String => el.GetString(),
        JsonValueKind.Number => el.TryGetInt64(out var l) ? l : el.GetDouble(),
        JsonValueKind.True => true,
        JsonValueKind.False => false,
        JsonValueKind.Object => JsonElementToDict(el),
        JsonValueKind.Array => el.EnumerateArray().Select(JsonElementToObject).ToList(),
        _ => null
    };

    private static string? GetStr(Dictionary<string, object> d, string key) =>
        d.TryGetValue(key, out var v) && v != null ? v.ToString() : null;
}
