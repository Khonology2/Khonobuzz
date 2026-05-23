using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using MyApi.Services;
using MyApi.DTOs.Auth;

namespace MyApi.Controllers
{
    [ApiController]
    [Route("")]
    [AllowAnonymous]
    public class ValidateTokenController : ControllerBase
    {
        private readonly ITokenService _tokenService;
        private readonly IFirestoreService _firestore;

        public ValidateTokenController(ITokenService tokenService, IFirestoreService firestore)
        {
            _tokenService = tokenService;
            _firestore = firestore;
        }

        [HttpGet("validate-token")]
        public async Task<IActionResult> ValidateTokenGet([FromQuery] string? token)
        {
            return await ValidateTokenInternalAsync(token);
        }

        [HttpPost("validate-token")]
        public async Task<IActionResult> ValidateTokenPost([FromBody] TokenValidationRequest? body)
        {
            var token = body?.Token;
            return await ValidateTokenInternalAsync(token);
        }

        private async Task<IActionResult> ValidateTokenInternalAsync(string? token)
        {
            if (string.IsNullOrWhiteSpace(token))
                return BadRequest(new { valid = false, error = "Token required" });

            var userId = _tokenService.GetUserIdFromToken(token.Trim());
            if (userId == null)
                return BadRequest(new { valid = false, error = "Invalid token" });

            object? userData = null;
            var user = await _firestore.GetUserByIdAsync(userId);
            if (user != null)
            {
                userData = new
                {
                    id = user.GetValueOrDefault("id"),
                    email = user.GetValueOrDefault("email"),
                    name = user.GetValueOrDefault("name"),
                    firstName = user.GetValueOrDefault("firstName"),
                    lastName = user.GetValueOrDefault("lastName"),
                    role = user.GetValueOrDefault("role"),
                    status = user.GetValueOrDefault("status"),
                    department = user.GetValueOrDefault("department"),
                    designation = user.GetValueOrDefault("designation")
                };
            }

            return Ok(new
            {
                valid = true,
                payload = new { user_id = userId, uid = userId },
                user = userData
            });
        }
    }
}
