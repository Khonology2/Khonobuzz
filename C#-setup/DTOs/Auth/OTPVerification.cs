using System.ComponentModel.DataAnnotations;

namespace MyApi.DTOs.Auth
{
    public class OTPVerification
    {
        [Required]
        [EmailAddress]
        public string Email { get; set; }

        [Required]
        [StringLength(10)]
        public string Code { get; set; }
    }
}
