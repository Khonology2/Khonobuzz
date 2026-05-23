using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using MyApi.Services;

namespace MyApi.Controllers
{
    [ApiController]
    [Route("users")]
    [Authorize]
    public class ProfileImageController : ControllerBase
    {
        private readonly ICloudinaryService _cloudinaryService;
        private readonly IFirestoreService _firestore;

        public ProfileImageController(ICloudinaryService cloudinaryService, IFirestoreService firestore)
        {
            _cloudinaryService = cloudinaryService;
            _firestore = firestore;
        }

        [HttpPost("profile-image")]
        public async Task<IActionResult> UploadProfileImage(IFormFile file, [FromQuery] string user_id)
        {
            if (file == null || file.Length == 0)
                return BadRequest(new { success = false, error = "No file uploaded.", message = "No file uploaded." });

            if (string.IsNullOrEmpty(user_id))
                return BadRequest(new { success = false, error = "user_id required.", message = "user_id is required." });

            var currentUserId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
            if (currentUserId != user_id && !User.IsInRole("admin"))
                return Forbid();

            try
            {
                var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif" };
                var fileExtension = Path.GetExtension(file.FileName).ToLower();
                if (!allowedExtensions.Contains(fileExtension))
                    return BadRequest(new { success = false, error = "Invalid file type.", message = "Only JPG, PNG, and GIF are allowed." });

                if (file.Length > 5 * 1024 * 1024)
                    return BadRequest(new { success = false, error = "File too large.", message = "Maximum size is 5MB." });

                var publicId = $"profile_{user_id}_{DateTime.UtcNow.Ticks}";
                using var stream = file.OpenReadStream();
                var imageUrl = await _cloudinaryService.UploadImageAsync(stream, publicId);

                await _firestore.UpdateOnboardingByUserIdAsync(user_id, new Dictionary<string, object>
                {
                    ["profileImageUrl"] = imageUrl,
                    ["profileImagePublicId"] = publicId
                });

                return Ok(new { success = true, url = imageUrl, public_id = publicId, message = "Profile image uploaded successfully" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, error = ex.Message, message = "Internal server error during profile image upload" });
            }
        }
    }

    [ApiController]
    [Route("api/delete")]
    [Authorize]
    public class DeleteProfilePictureController : ControllerBase
    {
        private readonly ICloudinaryService _cloudinaryService;
        private readonly IFirestoreService _firestore;

        public DeleteProfilePictureController(ICloudinaryService cloudinaryService, IFirestoreService firestore)
        {
            _cloudinaryService = cloudinaryService;
            _firestore = firestore;
        }

        [HttpDelete("profile-picture")]
        public async Task<IActionResult> DeleteByQuery([FromQuery] string public_id)
        {
            return await DeleteInternal(public_id);
        }

        [HttpPost("profile-picture")]
        public async Task<IActionResult> DeleteByForm([FromForm] string? public_id)
        {
            return await DeleteInternal(public_id);
        }

        private async Task<IActionResult> DeleteInternal(string? publicId)
        {
            if (string.IsNullOrEmpty(publicId))
                return BadRequest(new { success = false, error = "public_id required", message = "Public ID is required." });

            var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
            if (string.IsNullOrEmpty(userId))
                return Unauthorized();

            if (!publicId.StartsWith("profile_"))
                return BadRequest(new { success = false, error = "Invalid public ID.", message = "Invalid public ID." });

            try
            {
                var success = await _cloudinaryService.DeleteImageAsync(publicId);
                if (!success)
                    return StatusCode(500, new { success = false, error = "Failed to delete.", message = "Deletion failed" });

                var ob = await _firestore.GetOnboardingByUserIdAsync(userId);
                if (ob != null && (ob.GetValueOrDefault("profileImagePublicId")?.ToString() ?? "") == publicId)
                    await _firestore.UpdateOnboardingByUserIdAsync(userId, new Dictionary<string, object> { ["profileImageUrl"] = "", ["profileImagePublicId"] = "" });

                return Ok(new { success = true, message = "Profile picture deleted successfully" });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new { success = false, error = ex.Message, message = "Internal server error" });
            }
        }
    }
}
