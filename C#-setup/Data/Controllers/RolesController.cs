using Microsoft.AspNetCore.Mvc;
using MyApi.Services;

namespace MyApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class RolesController : ControllerBase
{
    private readonly IKhonoRelationalService _relational;

    public RolesController(IKhonoRelationalService relational) => _relational = relational;

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

        var created = await _relational.CreateRoleAsync(roleData);
        return StatusCode(201, new { message = "Role created successfully", role = created });
    }

    [HttpPost]
    [Route("/api/create_initial_roles")]
    public async Task<IActionResult> CreateInitialRoles()
    {
        await _relational.SeedInitialRolesAsync();
        return StatusCode(201, new { message = "Initial roles created successfully" });
    }
}

public class RoleCreateRequest
{
    public string? RoleName { get; set; }
    public string? Description { get; set; }
    public Dictionary<string, object>? PageAccess { get; set; }
}
