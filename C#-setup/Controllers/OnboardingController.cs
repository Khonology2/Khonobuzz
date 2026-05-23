using System.Text.Json;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using MyApi.Services;

namespace MyApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class OnboardingController : ControllerBase
    {
        private readonly IFirestoreService _firestore;

        public OnboardingController(IFirestoreService firestore)
        {
            _firestore = firestore;
        }

        [HttpPatch("update-user/{userId}")]
        public async Task<IActionResult> UpdateUser(string userId, [FromBody] JsonElement body)
        {
            var currentUserId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ??
                               User.FindFirst("sub")?.Value;
            if (currentUserId != userId && !User.IsInRole("admin"))
                return Forbid();

            if (!body.TryGetProperty("onboardingFields", out var obEl))
                return BadRequest(new { error = "onboardingFields required" });

            var onboardingFields = JsonElementToDict(obEl);
            if (onboardingFields.Count == 0)
                return BadRequest(new { error = "onboardingFields required" });

            await _firestore.UpdateOnboardingByUserIdAsync(userId, onboardingFields);
            return Ok(new { message = "Onboarding updated successfully" });
        }

        private static Dictionary<string, object> JsonElementToDict(JsonElement el)
        {
            var d = new Dictionary<string, object>();
            foreach (var p in el.EnumerateObject())
                d[p.Name] = JsonElementToObject(p.Value) ?? "";
            return d;
        }

        private static object? JsonElementToObject(JsonElement el)
        {
            switch (el.ValueKind)
            {
                case JsonValueKind.String: return el.GetString();
                case JsonValueKind.Number: return el.TryGetInt64(out var l) ? l : el.GetDouble();
                case JsonValueKind.True: return true;
                case JsonValueKind.False: return false;
                case JsonValueKind.Object: return JsonElementToDict(el);
                case JsonValueKind.Array: return el.EnumerateArray().Select(JsonElementToObject).ToList();
                default: return null;
            }
        }
    }
}
