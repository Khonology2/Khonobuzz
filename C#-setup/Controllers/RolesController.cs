using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using MyApi.Services;

namespace MyApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class RolesController : ControllerBase
    {
        private readonly IFirestoreService _firestore;

        public RolesController(IFirestoreService firestore)
        {
            _firestore = firestore;
        }

        [HttpGet]
        public async Task<IActionResult> GetRoles()
        {
            var roles = await _firestore.GetRolesAsync();
            return Ok(new { roles = roles.Select(r => new
            {
                id = r.GetValueOrDefault("id"),
                name = r.GetValueOrDefault("name") ?? r.GetValueOrDefault("roleName"),
                description = r.GetValueOrDefault("description"),
                createdAt = r.GetValueOrDefault("created_at")
            }).ToList() });
        }

        [HttpPost]
        public async Task<IActionResult> CreateRole([FromBody] RoleCreateRequest role)
        {
            var roleData = new Dictionary<string, object>
            {
                ["roleName"] = role.RoleName ?? "",
                ["description"] = role.Description ?? ""
            };
            if (role.PageAccess != null)
                roleData["pageAccess"] = role.PageAccess;
            await _firestore.AddRoleAsync(roleData);
            return StatusCode(201, new { message = "Role created successfully", role = roleData });
        }

        [HttpPost]
        [Route("/api/create_initial_roles")]
        [AllowAnonymous]
        public async Task<IActionResult> CreateInitialRoles()
        {
            var rolesData = new[]
            {
                new Dictionary<string, object> { ["roleName"] = "staff", ["pageAccess"] = new Dictionary<string, object>() },
                new Dictionary<string, object> { ["roleName"] = "admin", ["description"] = "Strategic administrator with full system access except for deletion.", ["pageAccess"] = new Dictionary<string, object>() },
                new Dictionary<string, object> { ["roleName"] = "manager", ["pageAccess"] = new Dictionary<string, object>() }
            };
            foreach (var roleData in rolesData)
            {
                roleData["first_valid"] = new DateTime(2025, 9, 25);
                roleData["last_valid"] = new DateTime(2039, 12, 31);
                await _firestore.AddRoleAsync(roleData);
            }
            return StatusCode(201, new { message = "Initial roles created successfully" });
        }
    }

    public class RoleCreateRequest
    {
        public string? RoleName { get; set; }
        public string? Description { get; set; }
        public Dictionary<string, object>? PageAccess { get; set; }
    }
}
