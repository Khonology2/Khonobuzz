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
    public class PDHController : ControllerBase
    {
        private readonly ApplicationDbContext _context;
        private readonly IFirebaseService _firebaseService;

        public PDHController(ApplicationDbContext context, IFirebaseService firebaseService)
        {
            _context = context;
            _firebaseService = firebaseService;
        }

        [HttpPost("sync/{userId}")]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> SyncUserToPDH(string userId)
        {
            var user = await _context.Users
                .Include(u => u.Onboarding)
                .FirstOrDefaultAsync(u => u.Id == userId);

            if (user == null)
            {
                return NotFound(new { Message = "User not found." });
            }

            try
            {
                // Sync user to main Firebase
                await _firebaseService.SyncUserToFirebaseAsync(user);

                // Sync onboarding to PDH Firebase if exists
                if (user.Onboarding != null)
                {
                    await _firebaseService.SyncOnboardingToFirebaseAsync(user.Onboarding);
                }

                return Ok(new { Message = "User synced to Firebase successfully." });
            }
            catch (Exception)
            {
                return StatusCode(500, new { Message = "Failed to sync user to Firebase." });
            }
        }

        [HttpPost("sync-all")]
        [Authorize(Roles = "admin")]
        public async Task<IActionResult> SyncAllUsersToPDH()
        {
            var users = await _context.Users
                .Include(u => u.Onboarding)
                .ToListAsync();

            var syncedCount = 0;
            var errors = new List<string>();

            foreach (var user in users)
            {
                try
                {
                    await _firebaseService.SyncUserToFirebaseAsync(user);
                    if (user.Onboarding != null)
                    {
                        await _firebaseService.SyncOnboardingToFirebaseAsync(user.Onboarding);
                    }
                    syncedCount++;
                }
                catch (Exception ex)
                {
                    errors.Add($"Failed to sync user {user.Email}: {ex.Message}");
                }
            }

            var response = new
            {
                SyncedCount = syncedCount,
                TotalCount = users.Count,
                Errors = errors,
                Message = $"Synced {syncedCount} out of {users.Count} users to Firebase."
            };

            return Ok(response);
        }

        [HttpGet("onboarding/{userId}")]
        public async Task<IActionResult> GetOnboardingData(string userId)
        {
            // Allow users to view their own onboarding or admins to view any
            var currentUserId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ??
                               User.FindFirst("sub")?.Value;

            if (currentUserId != userId && !User.IsInRole("admin"))
            {
                return Forbid();
            }

            var onboarding = await _context.Onboardings
                .FirstOrDefaultAsync(o => o.UserId == userId);

            if (onboarding == null)
            {
                return NotFound(new { Message = "Onboarding data not found." });
            }

            var response = new
            {
                onboarding.UserId,
                onboarding.Email,
                onboarding.Name,
                onboarding.Surname,
                onboarding.FullName,
                onboarding.Department,
                onboarding.Designation,
                onboarding.FirstValid,
                onboarding.LastValid,
                onboarding.OnboardingId,
                onboarding.StatusId,
                onboarding.UpdatedBy,
                onboarding.InsertedBy,
                onboarding.Entity,
                onboarding.ModuleAccess,
                onboarding.ModuleRole,
                onboarding.ModuleAccessRole,
                onboarding.Token,
                onboarding.TokenUpdatedAt,
                onboarding.CreatedAt
            };

            return Ok(response);
        }
    }
}
