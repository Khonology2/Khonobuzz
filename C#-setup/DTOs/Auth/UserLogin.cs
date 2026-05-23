using System.ComponentModel.DataAnnotations;

namespace MyApi.DTOs.Auth
{
    public class UserLogin
    {
        [Required]
        [EmailAddress]
        public required string Email { get; set; }

        public string? Otp { get; set; }
    }
}
