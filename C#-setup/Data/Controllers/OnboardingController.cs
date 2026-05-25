using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using MyApi.Services;

namespace MyApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class OnboardingController : ControllerBase
{
    private readonly IKhonoRelationalService _relational;
    private readonly ISsoPgSyncService _ssoSync;

    public OnboardingController(IKhonoRelationalService relational, ISsoPgSyncService ssoSync)
    {
        _relational = relational;
        _ssoSync = ssoSync;
    }

    [HttpPatch("update-user/{userId}")]
    public async Task<IActionResult> UpdateUser(string userId, [FromBody] JsonElement body)
    {
        if (!body.TryGetProperty("onboardingFields", out var obEl))
            return BadRequest(new { error = "onboardingFields is required" });

        var onboardingFields = JsonElementToDict(obEl);
        if (onboardingFields.Count == 0)
            return BadRequest(new { error = "onboardingFields is required" });

        var (_, user) = await _relational.FindUserByIdAsync(userId);
        if (user.Count == 0)
            return NotFound(new { error = "User not found" });

        onboardingFields["updated_at"] = DateTime.UtcNow;
        await _relational.ApplyOnboardingPatchAsync(userId, onboardingFields);

        var userData = (await _relational.FindUserByIdAsync(userId)).UserData;
        var onboardingData = await _relational.GetOnboardingAsync(userId);
        await _ssoSync.SyncUserLoginAsync(userId, userData, onboardingData);

        return Ok(new { message = "Onboarding update successful" });
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
}
