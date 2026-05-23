using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using MyApi.Services;

namespace MyApi.Controllers
{
    [ApiController]
    [Route("api/admin/users")]
    [Authorize(Roles = "admin")]
    public class AdminUsersController : ControllerBase
    {
        private readonly IFirestoreService _firestore;

        public AdminUsersController(IFirestoreService firestore)
        {
            _firestore = firestore;
        }

        [HttpPut("{email}/profile")]
        public async Task<IActionResult> UpdateProfile(string email, [FromBody] AdminProfileUpdateRequest data)
        {
            var normalizedEmail = email.Trim().ToLowerInvariant();
            var user = await _firestore.GetUserByEmailAsync(normalizedEmail);
            if (user == null)
                return NotFound(new { error = "User not found" });

            var userId = user.GetValueOrDefault("id")?.ToString() ?? "";
            var firstName = data?.FirstName ?? data?.Name ?? "";
            var lastName = data?.LastName ?? data?.Surname ?? "";
            var fullName = $"{firstName} {lastName}".Trim();
            if (string.IsNullOrEmpty(fullName)) fullName = data?.PreferredName ?? "";

            var userUpdates = new Dictionary<string, object>
            {
                ["department"] = data?.Department ?? "",
                ["designation"] = data?.Designation ?? "",
                ["manager"] = data?.ManagedBy ?? data?.Manager ?? ""
            };
            if (!string.IsNullOrEmpty(fullName)) userUpdates["name"] = fullName;
            await _firestore.UpdateUserAsync(userId, userUpdates);

            var obUpdates = new Dictionary<string, object>
            {
                ["firstName"] = firstName,
                ["lastName"] = lastName,
                ["surname"] = lastName,
                ["preferredName"] = data?.PreferredName ?? "",
                ["fullName"] = fullName,
                ["department"] = data?.Department ?? "",
                ["designation"] = data?.Designation ?? "",
                ["phoneNumber"] = data?.PhoneNumber ?? "",
                ["managedBy"] = data?.ManagedBy ?? data?.Manager ?? "",
                ["profileImageUrl"] = data?.ProfileImageUrl ?? "",
                ["profileImagePublicId"] = data?.ProfileImagePublicId ?? "",
                ["email"] = normalizedEmail
            };

            var ob = await _firestore.GetOnboardingByUserIdAsync(userId);
            if (ob != null)
                await _firestore.UpdateOnboardingByUserIdAsync(userId, obUpdates);
            else
                await _firestore.AddOnboardingAsync(userId, obUpdates);

            return Ok(new { message = "Profile updated successfully" });
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
    }
}
