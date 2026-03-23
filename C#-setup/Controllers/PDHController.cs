using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using MyApi.Services;
using System.Text.Json;

namespace MyApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class PDHController : ControllerBase
    {
        private readonly IFirestoreService _firestore;
        private readonly IPdhFirestoreService _pdhFirestore;
        private readonly ITokenService _tokenService;

        public PDHController(IFirestoreService firestore, IPdhFirestoreService pdhFirestore, ITokenService tokenService)
        {
            _firestore = firestore;
            _pdhFirestore = pdhFirestore;
            _tokenService = tokenService;
        }

        [HttpPost("sync-user")]
        [AllowAnonymous]
        public async Task<IActionResult> SyncUser([FromBody] JsonElement body)
        {
            if (!_pdhFirestore.IsConfigured)
                return StatusCode(500, new { error = "PDH Firestore not configured" });
            try
            {
                var uid = body.GetProperty("uid").GetString() ?? "";
                var userData = body.GetProperty("userData");
                var onboardingData = body.GetProperty("onboardingData");
                var userDict = JsonElementToDict(userData);
                var onboardingDict = JsonElementToDict(onboardingData);

                var modRole = GetStr(onboardingDict, "moduleAccessRole") ?? GetStr(userDict, "moduleAccessRole") ?? "";
                var userEmail = GetStr(userDict, "email") ?? GetStr(onboardingDict, "email") ?? "";
                if (!string.IsNullOrEmpty(userEmail) && !onboardingDict.ContainsKey("email"))
                    onboardingDict["email"] = userEmail;

                var roles = ParseModuleAccessRoleToRoles(modRole);
                var firstName = GetStr(onboardingDict, "firstName") ?? GetStr(onboardingDict, "name") ?? GetStr(userDict, "firstName") ?? "";
                var lastName = GetStr(onboardingDict, "lastName") ?? GetStr(onboardingDict, "surname") ?? GetStr(userDict, "lastName") ?? "";
                var fullName = $"{firstName} {lastName}".Trim();
                if (string.IsNullOrEmpty(fullName)) fullName = GetStr(userDict, "name") ?? "";
                onboardingDict["fullName"] = fullName;

                if (!onboardingDict.ContainsKey("token") || string.IsNullOrEmpty(GetStr(onboardingDict, "token")))
                {
                    if (!string.IsNullOrEmpty(modRole) && !string.IsNullOrEmpty(userEmail))
                    {
                        var plainToken = _tokenService.GenerateTokenFromDict(uid, userEmail, fullName, roles: roles);
                        onboardingDict["token"] = _tokenService.EncryptToken(plainToken);
                        onboardingDict["token_updated_at"] = DateTime.UtcNow;
                    }
                }

                await _pdhFirestore.SetUserAsync(uid, userDict);
                await _pdhFirestore.SetOnboardingAsync(uid, onboardingDict);
                return Ok(new { message = "PDH sync successful" });
            }
            catch (Exception e)
            {
                return StatusCode(500, new { error = e.Message });
            }
        }

        [HttpPatch("update-user/{uid}")]
        [AllowAnonymous]
        public async Task<IActionResult> UpdateUser(string uid, [FromBody] JsonElement body)
        {
            if (!_pdhFirestore.IsConfigured)
                return StatusCode(500, new { error = "PDH Firestore not configured" });
            try
            {
                Dictionary<string, object>? userFields = null;
                Dictionary<string, object>? onboardingFields = null;
                if (body.TryGetProperty("userFields", out var uf)) userFields = JsonElementToDict(uf);
                if (body.TryGetProperty("onboardingFields", out var of)) onboardingFields = JsonElementToDict(of);
                var userFieldsDict = userFields ?? new Dictionary<string, object>();

                var shouldRegenerate = false;
                var newModRole = "";
                if (onboardingFields != null && onboardingFields.ContainsKey("moduleAccessRole")) { shouldRegenerate = true; newModRole = GetStr(onboardingFields, "moduleAccessRole") ?? ""; }
                else if (userFields != null && userFields.ContainsKey("moduleAccessRole")) { shouldRegenerate = true; newModRole = GetStr(userFields, "moduleAccessRole") ?? ""; }

                if (userFields != null)
                    await _pdhFirestore.SetUserAsync(uid, userFields);

                if (onboardingFields != null)
                {
                    var userEmail = GetStr(onboardingFields, "email") ?? GetStr(userFieldsDict, "email") ?? "";
                    if (!string.IsNullOrEmpty(userEmail) && !onboardingFields.ContainsKey("email"))
                        onboardingFields["email"] = userEmail;
                    var roles = ParseModuleAccessRoleToRoles(newModRole);
                    var firstName = GetStr(onboardingFields, "firstName") ?? GetStr(onboardingFields, "name") ?? GetStr(userFieldsDict, "firstName") ?? "";
                    var lastName = GetStr(onboardingFields, "lastName") ?? GetStr(onboardingFields, "surname") ?? GetStr(userFieldsDict, "lastName") ?? "";
                    var fullName = $"{firstName} {lastName}".Trim();
                    if (string.IsNullOrEmpty(fullName)) fullName = GetStr(userFieldsDict, "name") ?? "";
                    onboardingFields["fullName"] = fullName;
                    if (shouldRegenerate && !string.IsNullOrEmpty(userEmail))
                    {
                        var plainToken = _tokenService.GenerateTokenFromDict(uid, userEmail, fullName, roles: roles);
                        onboardingFields["token"] = _tokenService.EncryptToken(plainToken);
                        onboardingFields["token_updated_at"] = DateTime.UtcNow;
                    }
                    await _pdhFirestore.SetOnboardingAsync(uid, onboardingFields);
                }
                return Ok(new { message = "PDH update successful" });
            }
            catch (Exception e)
            {
                return StatusCode(500, new { error = e.Message });
            }
        }

        private static Dictionary<string, object> JsonElementToDict(JsonElement el)
        {
            var d = new Dictionary<string, object>();
            foreach (var p in el.EnumerateObject())
            {
                d[p.Name] = JsonElementToObject(p.Value) ?? "";
            }
            return d;
        }

        private static object? JsonElementToObject(JsonElement el)
        {
            switch (el.ValueKind)
            {
                case JsonValueKind.String:
                    var s = el.GetString();
                    if (s != null && DateTime.TryParse(s, out var dt))
                        return dt;
                    return s;
                case JsonValueKind.Number:
                    if (el.TryGetInt64(out var l)) return l;
                    return el.GetDouble();
                case JsonValueKind.True: return true;
                case JsonValueKind.False: return false;
                case JsonValueKind.Object:
                    return JsonElementToDict(el);
                case JsonValueKind.Array:
                    return el.EnumerateArray().Select(JsonElementToObject).ToList();
                default: return null;
            }
        }

        private static string? GetStr(Dictionary<string, object> d, string key) => d.TryGetValue(key, out var v) && v != null ? v.ToString() : null;
        private static List<string> ParseModuleAccessRoleToRoles(string s)
        {
            if (string.IsNullOrWhiteSpace(s)) return new List<string>();
            return s.Split(',').Select(r => r.Trim()).Where(r => r.Length > 0).ToList();
        }

        [HttpGet("onboarding/{userId}")]
        [Authorize]
        public async Task<IActionResult> GetOnboardingData(string userId)
        {
            var currentUserId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ??
                               User.FindFirst("sub")?.Value;
            if (currentUserId != userId && !User.IsInRole("admin"))
                return Forbid();

            var ob = await _firestore.GetOnboardingByUserIdAsync(userId);
            if (ob == null)
                return NotFound(new { Message = "Onboarding data not found." });

            return Ok(new
            {
                userId = ob.GetValueOrDefault("user_id"),
                email = ob.GetValueOrDefault("email"),
                name = ob.GetValueOrDefault("name"),
                surname = ob.GetValueOrDefault("surname"),
                fullName = ob.GetValueOrDefault("fullName"),
                department = ob.GetValueOrDefault("department"),
                designation = ob.GetValueOrDefault("designation"),
                firstValid = ob.GetValueOrDefault("first_valid"),
                lastValid = ob.GetValueOrDefault("last_valid"),
                onboardingId = ob.GetValueOrDefault("onboarding_id"),
                statusId = ob.GetValueOrDefault("status_id"),
                updatedBy = ob.GetValueOrDefault("updated_by"),
                insertedBy = ob.GetValueOrDefault("inserted_by"),
                entity = ob.GetValueOrDefault("entity"),
                moduleAccess = ob.GetValueOrDefault("moduleAccess"),
                moduleRole = ob.GetValueOrDefault("moduleRole"),
                moduleAccessRole = ob.GetValueOrDefault("moduleAccessRole"),
                createdAt = ob.GetValueOrDefault("created_at")
            });
        }
    }
}
