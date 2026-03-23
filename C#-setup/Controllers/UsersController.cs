using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using MyApi.Services;
using MyApi.DTOs.User;

namespace MyApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class UsersController : ControllerBase
    {
        private readonly IFirestoreService _firestore;
        private readonly IPdhFirestoreService? _pdhFirestore;
        private readonly ITokenService _tokenService;

        public UsersController(IFirestoreService firestore, ITokenService tokenService, IPdhFirestoreService? pdhFirestore = null)
        {
            _firestore = firestore;
            _tokenService = tokenService;
            _pdhFirestore = pdhFirestore;
        }

        [HttpGet("by-email")]
        [AllowAnonymous]
        public async Task<IActionResult> GetUserByEmail([FromQuery] string email)
        {
            if (string.IsNullOrWhiteSpace(email))
                return BadRequest(new { error = "email is required" });

            var user = await _firestore.GetUserByEmailAsync(email.Trim());
            if (user == null)
                return NotFound(new { error = "User not found" });

            var userId = user.GetValueOrDefault("id")?.ToString() ?? "";
            var ob = await _firestore.GetOnboardingByUserIdAsync(userId);
            var merged = BuildUserResponse(user, ob);
            return Ok(new { user = merged });
        }

        [HttpGet]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> GetUsers()
        {
            var users = await _firestore.GetUsersWithOnboardingAsync();
            return Ok(new { users });
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetUser(string id)
        {
            var currentUserId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ??
                               User.FindFirst("sub")?.Value;
            if (currentUserId != id && !User.IsInRole("admin"))
                return Forbid();

            var user = await _firestore.GetUserByIdAsync(id);
            if (user == null)
                return NotFound(new { Message = "User not found." });

            var ob = await _firestore.GetOnboardingByUserIdAsync(id);
            return Ok(BuildUserResponse(user, ob));
        }

        [HttpGet("profile")]
        public async Task<IActionResult> GetProfile()
        {
            var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ??
                        User.FindFirst("sub")?.Value;
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();

            var user = await _firestore.GetUserByIdAsync(userId);
            if (user == null)
                return NotFound(new { Message = "User not found." });

            var ob = await _firestore.GetOnboardingByUserIdAsync(userId);
            return Ok(BuildUserResponse(user, ob));
        }

        [HttpPut("{id}")]
        [HttpPatch("{id}")]
        public async Task<IActionResult> UpdateUser(string id, [FromBody] UserUpdate updateUser)
        {
            var currentUserId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ??
                               User.FindFirst("sub")?.Value;
            if (currentUserId != id && !User.IsInRole("admin"))
                return Forbid();

            var user = await _firestore.GetUserByIdAsync(id);
            if (user == null)
                return NotFound(new { Message = "User not found." });

            var userUpdates = new Dictionary<string, object>();
            var obUpdates = new Dictionary<string, object>();
            if (updateUser.Name != null) { userUpdates["name"] = updateUser.Name; obUpdates["fullName"] = updateUser.Name; }
            if (updateUser.FirstName != null) { obUpdates["firstName"] = updateUser.FirstName; }
            if (updateUser.LastName != null) { obUpdates["lastName"] = updateUser.LastName; obUpdates["surname"] = updateUser.LastName; }
            if (updateUser.Role != null) { userUpdates["role"] = updateUser.Role; obUpdates["role"] = updateUser.Role; }
            if (updateUser.Status != null) { userUpdates["status"] = updateUser.Status; obUpdates["status"] = updateUser.Status; }
            if (updateUser.Entity != null) { userUpdates["entity"] = updateUser.Entity; obUpdates["entity"] = updateUser.Entity; }
            if (updateUser.Department != null) { userUpdates["department"] = updateUser.Department; obUpdates["department"] = updateUser.Department; }
            if (updateUser.Designation != null) { userUpdates["designation"] = updateUser.Designation; obUpdates["designation"] = updateUser.Designation; }
            if (updateUser.Manager != null) { userUpdates["manager"] = updateUser.Manager; obUpdates["manager"] = updateUser.Manager; }
            if (updateUser.ModuleAccess != null) { userUpdates["moduleAccess"] = updateUser.ModuleAccess; obUpdates["moduleAccess"] = updateUser.ModuleAccess; }
            if (updateUser.ModuleRole != null) { userUpdates["moduleRole"] = updateUser.ModuleRole; obUpdates["moduleRole"] = updateUser.ModuleRole; }
            if (updateUser.ModuleAccessRole != null) { userUpdates["moduleAccessRole"] = updateUser.ModuleAccessRole; obUpdates["moduleAccessRole"] = updateUser.ModuleAccessRole; }
            if (updateUser.AdminApproved != null) { userUpdates["admin"] = new Dictionary<string, object> { ["approved"] = updateUser.AdminApproved }; obUpdates["admin"] = new Dictionary<string, object> { ["approved"] = updateUser.AdminApproved }; }

            if (updateUser.RegenerateToken == true && updateUser.ModuleAccessRole != null)
            {
                var userEmail = user.GetValueOrDefault("email")?.ToString() ?? "";
                var obExisting = await _firestore.GetOnboardingByUserIdAsync(id);
                var fn = obExisting?.GetValueOrDefault("firstName")?.ToString() ?? "";
                var ln = obExisting?.GetValueOrDefault("lastName")?.ToString() ?? "";
                var fullName = $"{fn} {ln}".Trim();
                if (string.IsNullOrEmpty(fullName)) fullName = obExisting?.GetValueOrDefault("fullName")?.ToString() ?? user.GetValueOrDefault("name")?.ToString() ?? "";
                var roles = updateUser.ModuleAccessRole.Split(',', StringSplitOptions.RemoveEmptyEntries).Select(r => r.Trim()).ToList();
                var plainToken = _tokenService.GenerateTokenFromDict(id, userEmail, fullName, roles: roles);
                var encryptedToken = _tokenService.EncryptToken(plainToken);
                obUpdates["token"] = encryptedToken;
                obUpdates["token_updated_at"] = DateTime.UtcNow;
                if (_pdhFirestore?.IsConfigured == true)
                    await _pdhFirestore.SetOnboardingAsync(id, new Dictionary<string, object> { ["token"] = encryptedToken, ["token_updated_at"] = DateTime.UtcNow, ["email"] = userEmail, ["fullName"] = fullName });
            }

            if (userUpdates.Count > 0)
                await _firestore.UpdateUserAsync(id, userUpdates);
            if (obUpdates.Count > 0)
                await _firestore.UpdateOnboardingByUserIdAsync(id, obUpdates);

            var updated = await _firestore.GetUserByIdAsync(id);
            var ob = await _firestore.GetOnboardingByUserIdAsync(id);
            var response = BuildUserResponse(updated ?? user, ob);
            response["Message"] = "User updated successfully.";
            return Ok(response);
        }

        [HttpDelete("{id}")]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> DeleteUser(string id)
        {
            var user = await _firestore.GetUserByIdAsync(id);
            if (user == null)
                return NotFound(new { Message = "User not found." });

            await _firestore.DeleteUserAsync(id);
            if (_pdhFirestore?.IsConfigured == true)
                await _pdhFirestore.DeleteUserAsync(id);
            return Ok(new { Message = "User deleted successfully." });
        }

        private static Dictionary<string, object> BuildUserResponse(Dictionary<string, object> user, Dictionary<string, object>? ob)
        {
            var uid = user.GetValueOrDefault("id")?.ToString() ?? "";
            var firstName = ob?.GetValueOrDefault("firstName")?.ToString() ?? ob?.GetValueOrDefault("name")?.ToString() ?? user.GetValueOrDefault("firstName")?.ToString() ?? "";
            var lastName = ob?.GetValueOrDefault("lastName")?.ToString() ?? ob?.GetValueOrDefault("surname")?.ToString() ?? user.GetValueOrDefault("lastName")?.ToString() ?? "";
            var dept = ob?.GetValueOrDefault("department")?.ToString() ?? user.GetValueOrDefault("department")?.ToString() ?? "";
            var desig = ob?.GetValueOrDefault("designation")?.ToString() ?? user.GetValueOrDefault("designation")?.ToString() ?? "";
            return new Dictionary<string, object>
            {
                ["id"] = uid,
                ["email"] = user.GetValueOrDefault("email") ?? "",
                ["name"] = user.GetValueOrDefault("name") ?? "",
                ["firstName"] = firstName,
                ["lastName"] = lastName,
                ["role"] = user.GetValueOrDefault("role") ?? "Staff",
                ["status"] = user.GetValueOrDefault("status") ?? "Active",
                ["entity"] = user.GetValueOrDefault("entity") ?? ob?.GetValueOrDefault("entity") ?? "",
                ["department"] = dept,
                ["designation"] = desig,
                ["manager"] = user.GetValueOrDefault("manager") ?? ob?.GetValueOrDefault("manager") ?? "",
                ["moduleAccess"] = user.GetValueOrDefault("moduleAccess") ?? ob?.GetValueOrDefault("moduleAccess") ?? "",
                ["moduleRole"] = user.GetValueOrDefault("moduleRole") ?? ob?.GetValueOrDefault("moduleRole") ?? "",
                ["moduleAccessRole"] = user.GetValueOrDefault("moduleAccessRole") ?? ob?.GetValueOrDefault("moduleAccessRole") ?? "",
                ["createdAt"] = user.GetValueOrDefault("created_at") ?? "",
                ["Onboarding"] = ob != null ? new Dictionary<string, object?>
                {
                    ["fullName"] = ob.GetValueOrDefault("fullName"),
                    ["firstValid"] = ob.GetValueOrDefault("first_valid"),
                    ["lastValid"] = ob.GetValueOrDefault("last_valid"),
                    ["onboardingId"] = ob.GetValueOrDefault("onboarding_id"),
                    ["statusId"] = ob.GetValueOrDefault("status_id")
                } : null
            };
        }
    }
}
