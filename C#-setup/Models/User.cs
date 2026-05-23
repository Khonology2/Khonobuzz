using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace MyApi.Models
{
    [Table("users")]
    public class User
    {
        [Key]
        [StringLength(255)]
        public required string Id { get; set; }

        [Required]
        [EmailAddress]
        [StringLength(255)]
        public required string Email { get; set; }

        [StringLength(255)]
        public required string Name { get; set; }

        [StringLength(255)]
        public required string FirstName { get; set; }

        [StringLength(255)]
        public required string LastName { get; set; }

        [StringLength(255)]
        public required string Role { get; set; }

        [StringLength(50)]
        public required string Status { get; set; }

        [StringLength(255)]
        public required string Entity { get; set; }

        [StringLength(255)]
        public required string Department { get; set; }

        [StringLength(255)]
        public required string Designation { get; set; }

        [StringLength(255)]
        public required string Manager { get; set; }

        [StringLength(500)]
        public required string ModuleAccess { get; set; }

        [StringLength(255)]
        public required string ModuleRole { get; set; }

        [StringLength(255)]
        public required string ModuleAccessRole { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        // Navigation property
        public virtual Onboarding? Onboarding { get; set; }
    }
}
