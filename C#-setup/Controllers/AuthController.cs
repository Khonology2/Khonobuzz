using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authorization;
using MyApi.Services;
using MyApi.DTOs.Auth;
using MyApi.Models;

namespace MyApi.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class AuthController : ControllerBase
    {
        private readonly IAuthService _authService;
        private readonly IOtpService _otpService;
        private readonly IRateLimiterService _rateLimiter;

        public AuthController(
            IAuthService authService,
            IOtpService otpService,
            IRateLimiterService rateLimiter)
        {
            _authService = authService;
            _otpService = otpService;
            _rateLimiter = rateLimiter;
        }

        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] UserRegister request)
        {

            try
            {
                var user = await _authService.RegisterAsync(
                    request.Email,
                    request.Name,
                    request.FirstName,
                    request.LastName,
                    request.Department,
                    request.Designation);

                var response = new
                {
                    user.Id,
                    user.Email,
                    user.Name,
                    user.Status,
                    Message = "Registration successful. Please check your email for OTP."
                };

                return Ok(response);
            }
            catch (InvalidOperationException ex)
            {
                return BadRequest(new { Message = ex.Message });
            }
            catch (Exception)
            {
                return StatusCode(500, new { Message = "An error occurred during registration." });
            }
        }

        [HttpPost("otp/request")]
        public async Task<IActionResult> RequestOtp([FromBody] OTPRequest request)
        {
            if (request.Email == null)
            {
                return BadRequest(new { Message = "Email is required." });
            }

            // Rate limiting
            if (await _rateLimiter.IsRateLimitedAsync($"otp_request_{request.Email}"))
            {
                return StatusCode(429, new { Message = "Too many OTP requests. Please try again later." });
            }

            try
            {
                var otp = await _otpService.GenerateOtpAsync(request.Email);
                await _rateLimiter.RecordRequestAsync($"otp_request_{request.Email}");

                var response = new
                {
                    Message = "OTP sent successfully.",
                    Email = request.Email
                };

                return Ok(response);
            }
            catch (Exception)
            {
                return StatusCode(500, new { Message = "Failed to send OTP." });
            }
        }

        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] UserLogin request)
        {
            // Rate limiting
            if (await _rateLimiter.IsRateLimitedAsync($"login_{request.Email}"))
            {
                return StatusCode(429, new { Message = "Too many login attempts. Please try again later." });
            }


            try
            {
                var isValid = await _authService.VerifyOtpAndLoginAsync(request.Email, request.Otp);
                if (!isValid)
                {
                    await _rateLimiter.RecordRequestAsync($"login_{request.Email}");
                    return BadRequest(new { Message = "Invalid OTP or user not found." });
                }

                var user = await _authService.GetUserByEmailAsync(request.Email);
                if (user == null)
                {
                    return BadRequest(new { Message = "User not found." });
                }

                // Generate JWT token
                var tokenService = HttpContext.RequestServices.GetService<ITokenService>();
                if (tokenService == null)
                {
                    return StatusCode(500, new { Message = "Token service unavailable." });
                }
                var token = tokenService.GenerateToken(user);

                var response = new
                {
                    Token = token,
                    User = new
                    {
                        user.Id,
                        user.Email,
                        user.Name,
                        user.FirstName,
                        user.LastName,
                        user.Department,
                        user.Designation,
                        user.Status
                    },
                    Message = "Login successful."
                };

                return Ok(response);
            }
            catch (Exception)
            {
                return StatusCode(500, new { Message = "Login failed." });
            }
        }

        [HttpPost("otp/verify")]
        public async Task<IActionResult> VerifyOtp([FromBody] OTPVerification request)
        {

            try
            {
                var isValid = await _otpService.VerifyOtpAsync(request.Email, request.Code);
                if (!isValid)
                {
                    return BadRequest(new { Message = "Invalid or expired OTP." });
                }

                var response = new
                {
                    Valid = true,
                    Message = "OTP verified successfully."
                };

                return Ok(response);
            }
            catch (Exception)
            {
                return StatusCode(500, new { Message = "OTP verification failed." });
            }
        }
    }
}
