using System.ComponentModel.DataAnnotations;

namespace MyApi.DTOs.Auth
{
    public class UserLogin
    {
        [Required]
        [EmailAddress]
        public required string Email { get; set; }

        [Required]
        [StringLength(10)]
        public required string Otp { get; set; }
    }
}
