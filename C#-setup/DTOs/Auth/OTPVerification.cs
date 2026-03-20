using System.ComponentModel.DataAnnotations;

namespace MyApi.DTOs.Auth
{
    public class OTPVerification
    {
        [Required]
        [EmailAddress]
        public required string Email { get; set; }

        [Required]
        [StringLength(10)]
        public required string Code { get; set; }
    }
}
