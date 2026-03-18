using System.ComponentModel.DataAnnotations;

namespace MyApi.DTOs.Auth
{
    public class UserLogin
    {
        [Required]
        [EmailAddress]
        public string Email { get; set; }

        [Required]
        [StringLength(10)]
        public string Otp { get; set; }
    }
}
