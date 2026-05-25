using System.ComponentModel.DataAnnotations;

namespace MyApi.DTOs.Auth
{
    public class UserRegister
    {
        [Required]
        [EmailAddress]
        public required string Email { get; set; }

        [Required]
        public required string Password { get; set; }

        [Required]
        [StringLength(255)]
        public required string Name { get; set; }

        [StringLength(255)]
        public string? FirstName { get; set; }

        [StringLength(255)]
        public string? LastName { get; set; }

        [StringLength(255)]
        public string Role { get; set; } = "user";

        [StringLength(255)]
        public string? Department { get; set; }

        [StringLength(255)]
        public string? Designation { get; set; }

        [StringLength(255)]
        public string? Entity { get; set; }
    }
}
