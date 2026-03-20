using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using MyApi.Services;
using MyApi.Models;
using MyApi.Data;
using Microsoft.EntityFrameworkCore;

namespace MyApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class RolesController : ControllerBase
    {
        private readonly ApplicationDbContext _context;

        public RolesController(ApplicationDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<IActionResult> GetRoles()
        {
            var roles = await _context.Roles
                .Select(r => new
                {
                    r.Id,
                    r.Name,
                    r.Description,
                    r.CreatedAt
                })
                .ToListAsync();

            return Ok(new { Roles = roles });
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetRole(string id)
        {
            var role = await _context.Roles
                .FirstOrDefaultAsync(r => r.Id == id);

            if (role == null)
            {
                return NotFound(new { Message = "Role not found." });
            }

            var response = new
            {
                role.Id,
                role.Name,
                role.Description,
                role.CreatedAt
            };

            return Ok(response);
        }

        [HttpPost]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> CreateRole([FromBody] Role role)
        {
            role.Id = Guid.NewGuid().ToString();
            role.CreatedAt = DateTime.UtcNow;
            role.UpdatedAt = DateTime.UtcNow;

            _context.Roles.Add(role);
            await _context.SaveChangesAsync();

            var response = new
            {
                role.Id,
                role.Name,
                role.Description,
                Message = "Role created successfully."
            };

            return CreatedAtAction(nameof(GetRole), new { id = role.Id }, response);
        }

        [HttpPut("{id}")]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> UpdateRole(string id, [FromBody] Role updateRole)
        {
            var role = await _context.Roles.FirstOrDefaultAsync(r => r.Id == id);
            if (role == null)
            {
                return NotFound(new { Message = "Role not found." });
            }

            role.Name = updateRole.Name ?? role.Name;
            role.Description = updateRole.Description ?? role.Description;
            role.UpdatedAt = DateTime.UtcNow;

            await _context.SaveChangesAsync();

            var response = new
            {
                role.Id,
                role.Name,
                role.Description,
                Message = "Role updated successfully."
            };

            return Ok(response);
        }

        [HttpDelete("{id}")]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> DeleteRole(string id)
        {
            var role = await _context.Roles.FirstOrDefaultAsync(r => r.Id == id);
            if (role == null)
            {
                return NotFound(new { Message = "Role not found." });
            }

            _context.Roles.Remove(role);
            await _context.SaveChangesAsync();

            return Ok(new { Message = "Role deleted successfully." });
        }
    }
}
