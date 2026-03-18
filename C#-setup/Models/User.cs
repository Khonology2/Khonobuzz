using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace MyApi.Models
{
    [Table("users")]
    public class User
    {
        [Key]
        [StringLength(255)]
        public string Id { get; set; }

        [Required]
        [EmailAddress]
        [StringLength(255)]
        public string Email { get; set; }

        [StringLength(255)]
        public string Name { get; set; }

        [StringLength(255)]
        public string FirstName { get; set; }

        [StringLength(255)]
        public string LastName { get; set; }

        [StringLength(255)]
        public string Role { get; set; }

        [StringLength(50)]
        public string Status { get; set; }

        [StringLength(255)]
        public string Entity { get; set; }

        [StringLength(255)]
        public string Department { get; set; }

        [StringLength(255)]
        public string Designation { get; set; }

        [StringLength(255)]
        public string Manager { get; set; }

        [StringLength(500)]
        public string ModuleAccess { get; set; }

        [StringLength(255)]
        public string ModuleRole { get; set; }

        [StringLength(255)]
        public string ModuleAccessRole { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        // Navigation property
        public virtual Onboarding Onboarding { get; set; }
    }
}
