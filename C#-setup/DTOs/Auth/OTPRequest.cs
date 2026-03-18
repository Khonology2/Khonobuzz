using System.ComponentModel.DataAnnotations;

namespace MyApi.DTOs.Auth
{
    public class OTPRequest
    {
        [Required]
        [EmailAddress]
        public string Email { get; set; }
    }
}
