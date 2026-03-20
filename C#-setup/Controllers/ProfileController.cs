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
    public class ProfileController : ControllerBase
    {
        private readonly ICloudinaryService _cloudinaryService;
        private readonly ApplicationDbContext _context;

        public ProfileController(ICloudinaryService cloudinaryService, ApplicationDbContext context)
        {
            _cloudinaryService = cloudinaryService;
            _context = context;
        }

        [HttpPost("upload-image")]
        public async Task<IActionResult> UploadProfileImage(IFormFile file)
        {
            if (file == null || file.Length == 0)
            {
                return BadRequest(new { Message = "No file uploaded." });
            }

            var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ??
                        User.FindFirst("sub")?.Value;

            if (string.IsNullOrEmpty(userId))
            {
                return Unauthorized();
            }


            try
            {
                // Validate file type
                var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".gif" };
                var fileExtension = Path.GetExtension(file.FileName).ToLower();

                if (!allowedExtensions.Contains(fileExtension))
                {
                    return BadRequest(new { Message = "Invalid file type. Only JPG, PNG, and GIF are allowed." });
                }

                // Validate file size (max 5MB)
                if (file.Length > 5 * 1024 * 1024)
                {
                    return BadRequest(new { Message = "File size too large. Maximum size is 5MB." });
                }

                var publicId = $"profile_{userId}_{DateTime.UtcNow.Ticks}";

                using var stream = file.OpenReadStream();
                var imageUrl = await _cloudinaryService.UploadImageAsync(stream, publicId);

                // Update user's profile image URL (assuming we add this field to User model later)
                // For now, just return the URL

                var response = new
                {
                    ImageUrl = imageUrl,
                    PublicId = publicId,
                    Message = "Profile image uploaded successfully."
                };

                return Ok(response);
            }
            catch (Exception)
            {
                return StatusCode(500, new { Message = "Failed to upload image." });
            }
        }

        [HttpDelete("delete-image")]
        public async Task<IActionResult> DeleteProfileImage([FromQuery] string publicId)
        {
            if (string.IsNullOrEmpty(publicId))
            {
                return BadRequest(new { Message = "Public ID is required." });
            }

            var userId = User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value ??
                        User.FindFirst("sub")?.Value;

            if (string.IsNullOrEmpty(userId))
            {
                return Unauthorized();
            }

            // Validate that the publicId belongs to this user
            if (!publicId.StartsWith($"profile_{userId}_"))
            {
                return BadRequest(new { Message = "Invalid public ID." });
            }


            try
            {
                var success = await _cloudinaryService.DeleteImageAsync(publicId);

                if (!success)
                {
                    return BadRequest(new { Message = "Failed to delete image." });
                }

                return Ok(new { Message = "Profile image deleted successfully." });
            }
            catch (Exception)
            {
                return StatusCode(500, new { Message = "Failed to delete image." });
            }
        }
    }
}
