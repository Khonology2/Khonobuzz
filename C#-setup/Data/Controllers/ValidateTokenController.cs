using Microsoft.AspNetCore.Mvc;
using MyApi.DTOs.Auth;
using MyApi.Services;

namespace MyApi.Controllers;

[ApiController]
[Route("")]
public class ValidateTokenController : ControllerBase
{
    private readonly ITokenService _tokenService;
    private readonly IKhonoRelationalService _relational;

    public ValidateTokenController(ITokenService tokenService, IKhonoRelationalService relational)
    {
        _tokenService = tokenService;
        _relational = relational;
    }

    [HttpGet("validate-token")]
    public Task<IActionResult> ValidateTokenGet([FromQuery] string? token) =>
        ValidateTokenInternalAsync(token);

    [HttpPost("validate-token")]
    public Task<IActionResult> ValidateTokenPost([FromBody] TokenValidationRequest? body) =>
        ValidateTokenInternalAsync(body?.Token);

    private async Task<IActionResult> ValidateTokenInternalAsync(string? token)
    {
        if (string.IsNullOrWhiteSpace(token))
            return BadRequest(new { valid = false, error = "Token required" });

        try
        {
            var payload = _tokenService.VerifyAndExpandToken(token.Trim());
            if (payload == null)
                return BadRequest(new { valid = false, error = "Invalid token" });

            var userId = payload.GetValueOrDefault("user_id")?.ToString()
                ?? payload.GetValueOrDefault("uid")?.ToString()
                ?? "";

            Dictionary<string, object>? userData = null;
            if (!string.IsNullOrEmpty(userId))
            {
                var (_, user) = await _relational.FindUserByIdAsync(userId);
                if (user.Count > 0)
                    userData = user;
            }

            return Ok(new
            {
                valid = true,
                payload,
                user = userData
            });
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { valid = false, error = $"Token validation failed: {ex.Message}" });
        }
    }
}
