using Microsoft.AspNetCore.Mvc;
using MyApi.Services;

namespace MyApi.Controllers;

[ApiController]
[Route("users")]
public class ProfileImageController : ControllerBase
{
    private readonly ICloudinaryService _cloudinaryService;
    private readonly IKhonoRelationalService _relational;

    public ProfileImageController(ICloudinaryService cloudinaryService, IKhonoRelationalService relational)
    {
        _cloudinaryService = cloudinaryService;
        _relational = relational;
    }

    [HttpPost("profile-image")]
    public async Task<IActionResult> UploadProfileImage(IFormFile file, [FromQuery] string user_id)
    {
        if (file == null || file.Length == 0)
            return BadRequest(new { success = false, error = "No file uploaded.", message = "No file uploaded." });

        if (string.IsNullOrEmpty(user_id))
            return BadRequest(new { success = false, error = "user_id required.", message = "user_id is required." });

        var (_, user) = await _relational.FindUserByIdAsync(user_id);
        if (user.Count == 0)
            return NotFound(new { success = false, error = "User not found.", message = "User not found." });

        try
        {
            var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif" };
            var fileExtension = Path.GetExtension(file.FileName).ToLowerInvariant();
            if (!allowedExtensions.Contains(fileExtension))
                return BadRequest(new { success = false, error = "Invalid file type.", message = "Only JPG, PNG, and GIF are allowed." });

            if (file.Length > 5 * 1024 * 1024)
                return BadRequest(new { success = false, error = "File too large.", message = "Maximum size is 5MB." });

            var publicId = $"profile_{user_id}_{DateTime.UtcNow.Ticks}";
            using var stream = file.OpenReadStream();
            var imageUrl = await _cloudinaryService.UploadImageAsync(stream, publicId);

            await _relational.ApplyOnboardingPatchAsync(user_id, new Dictionary<string, object>
            {
                ["profileImageUrl"] = imageUrl,
                ["profileImagePublicId"] = publicId,
                ["updated_at"] = DateTime.UtcNow
            });

            return Ok(new
            {
                success = true,
                url = imageUrl,
                public_id = publicId,
                message = "Profile image uploaded successfully"
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, error = ex.Message, message = "Internal server error during profile image upload" });
        }
    }
}

[ApiController]
[Route("api/delete")]
public class DeleteProfilePictureController : ControllerBase
{
    private readonly ICloudinaryService _cloudinaryService;
    private readonly IKhonoRelationalService _relational;

    public DeleteProfilePictureController(ICloudinaryService cloudinaryService, IKhonoRelationalService relational)
    {
        _cloudinaryService = cloudinaryService;
        _relational = relational;
    }

    [HttpDelete("profile-picture")]
    public Task<IActionResult> DeleteByQuery([FromQuery] string public_id) =>
        DeleteInternal(public_id);

    [HttpPost("profile-picture")]
    public Task<IActionResult> DeleteByForm([FromForm] string? public_id) =>
        DeleteInternal(public_id);

    private async Task<IActionResult> DeleteInternal(string? publicId)
    {
        if (string.IsNullOrEmpty(publicId))
            return BadRequest(new { success = false, error = "public_id required", message = "Public ID is required." });

        if (!publicId.StartsWith("profile_", StringComparison.Ordinal))
            return BadRequest(new { success = false, error = "Invalid public ID.", message = "Invalid public ID." });

        try
        {
            var success = await _cloudinaryService.DeleteImageAsync(publicId);
            if (!success)
                return StatusCode(500, new { success = false, error = "Failed to delete.", message = "Deletion failed" });

            var userId = ExtractUserIdFromPublicId(publicId);
            if (!string.IsNullOrEmpty(userId))
            {
                var onboarding = await _relational.GetOnboardingAsync(userId);
                if ((onboarding.GetValueOrDefault("profileImagePublicId")?.ToString() ?? "") == publicId)
                {
                    await _relational.ApplyOnboardingPatchAsync(userId, new Dictionary<string, object>
                    {
                        ["profileImageUrl"] = "",
                        ["profileImagePublicId"] = "",
                        ["updated_at"] = DateTime.UtcNow
                    });
                }
            }

            return Ok(new { success = true, message = "Profile picture deleted successfully" });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { success = false, error = ex.Message, message = "Internal server error" });
        }
    }

    private static string? ExtractUserIdFromPublicId(string publicId)
    {
        if (!publicId.StartsWith("profile_", StringComparison.Ordinal)) return null;
        var parts = publicId.Split('_');
        return parts.Length >= 2 ? parts[1] : null;
    }
}
