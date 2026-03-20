using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using MyApi.Services;
using MyApi.DTOs.User;
using MyApi.Models;
using MyApi.Data;
using Microsoft.EntityFrameworkCore;

namespace MyApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [Authorize]
    public class UsersController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IAuthService _authService;

        public UsersController(ApplicationDbContext context, IAuthService authService)
        {
            _context = context;
            _authService = authService;
        }

        [HttpGet]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> GetUsers()
        {
            var users = await _context.Users
                .Select(u => new
                {
                    u.Id,
                    u.Email,
                    u.Name,
                    u.FirstName,
                    u.LastName,
                    u.Department,
                    u.Designation,
                    u.Status,
                    u.CreatedAt
                })
                .ToListAsync();

            return Ok(new { Users = users });
        }

        [HttpGet("{id}")]
        public async Task<IActionResult> GetUser(string id)
        {
            // Allow users to view their own profile or admins to view any
            var currentUserId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ??
                               User.FindFirst("sub")?.Value;

            if (currentUserId != id && !User.IsInRole("admin"))
            {
                return Forbid();
            }

            var user = await _context.Users
                .Include(u => u.Onboarding)
                .FirstOrDefaultAsync(u => u.Id == id);

            if (user == null)
            {
                return NotFound(new { Message = "User not found." });
            }

            var response = new
            {
                user.Id,
                user.Email,
                user.Name,
                user.FirstName,
                user.LastName,
                user.Department,
                user.Designation,
                user.Role,
                user.Status,
                user.Entity,
                user.Manager,
                user.ModuleAccess,
                user.ModuleRole,
                user.ModuleAccessRole,
                user.CreatedAt,
                Onboarding = user.Onboarding != null ? new
                {
                    user.Onboarding.FullName,
                    user.Onboarding.FirstValid,
                    user.Onboarding.LastValid,
                    user.Onboarding.OnboardingId,
                    user.Onboarding.StatusId
                } : null
            };

            return Ok(response);
        }

        [HttpGet("profile")]
        public async Task<IActionResult> GetProfile()
        {
            var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ??
                        User.FindFirst("sub")?.Value;

            if (string.IsNullOrEmpty(userId))
            {
                return Unauthorized();
            }

            var user = await _context.Users
                .Include(u => u.Onboarding)
                .FirstOrDefaultAsync(u => u.Id == userId);

            if (user == null)
            {
                return NotFound(new { Message = "User not found." });
            }

            var response = new
            {
                user.Id,
                user.Email,
                user.Name,
                user.FirstName,
                user.LastName,
                user.Department,
                user.Designation,
                user.Role,
                user.Status,
                user.CreatedAt,
                Onboarding = user.Onboarding != null ? new
                {
                    user.Onboarding.FullName,
                    user.Onboarding.FirstValid,
                    user.Onboarding.LastValid,
                    user.Onboarding.OnboardingId,
                    user.Onboarding.StatusId
                } : null
            };

            return Ok(response);
        }

        [HttpPut("{id}")]
        public async Task<IActionResult> UpdateUser(string id, [FromBody] UserUpdate updateUser)
        {
            // Allow users to update their own profile or admins to update any
            var currentUserId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ??
                               User.FindFirst("sub")?.Value;

            if (currentUserId != id && !User.IsInRole("admin"))
            {
                return Forbid();
            }

            var user = await _context.Users.FirstOrDefaultAsync(u => u.Id == id);
            if (user == null)
            {
                return NotFound(new { Message = "User not found." });
            }

            // Update allowed fields
            if (!string.IsNullOrWhiteSpace(updateUser.Name)) user.Name = updateUser.Name;
            if (!string.IsNullOrWhiteSpace(updateUser.FirstName)) user.FirstName = updateUser.FirstName;
            if (!string.IsNullOrWhiteSpace(updateUser.LastName)) user.LastName = updateUser.LastName;
            if (!string.IsNullOrWhiteSpace(updateUser.Department)) user.Department = updateUser.Department;
            if (!string.IsNullOrWhiteSpace(updateUser.Designation)) user.Designation = updateUser.Designation;

            // Only admins can update role
            if (User.IsInRole("admin") && !string.IsNullOrWhiteSpace(updateUser.Role))
            {
                user.Role = updateUser.Role;
            }

            user.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();

            var response = new
            {
                user.Id,
                user.Email,
                user.Name,
                user.FirstName,
                user.LastName,
                user.Department,
                user.Designation,
                user.Role,
                Message = "User updated successfully."
            };

            return Ok(response);
        }

        [HttpDelete("{id}")]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> DeleteUser(string id)
        {
            var user = await _context.Users
                .Include(u => u.Onboarding)
                .FirstOrDefaultAsync(u => u.Id == id);

            if (user == null)
            {
                return NotFound(new { Message = "User not found." });
            }

            // Remove onboarding first due to foreign key constraint
            if (user.Onboarding != null)
            {
                _context.Onboardings.Remove(user.Onboarding);
            }

            _context.Users.Remove(user);
            await _context.SaveChangesAsync();

            return Ok(new { Message = "User deleted successfully." });
        }
    }
}
