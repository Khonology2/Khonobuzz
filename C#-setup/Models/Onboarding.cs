using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace MyApi.Models
{
    [Table("onboarding")]
    public class Onboarding
    {
        [Key]
        [StringLength(255)]
        public required string UserId { get; set; }

        [StringLength(255)]
        public required string Email { get; set; }

        [StringLength(255)]
        public required string Name { get; set; }

        [StringLength(255)]
        public required string Surname { get; set; }

        [StringLength(255)]
        public required string FullName { get; set; }

        [StringLength(255)]
        public required string Department { get; set; }

        [StringLength(255)]
        public required string Designation { get; set; }

        public DateTime? FirstValid { get; set; }

        public DateTime? LastValid { get; set; }

        [StringLength(255)]
        public required string OnboardingId { get; set; }

        [StringLength(255)]
        public required string StatusId { get; set; }

        [StringLength(255)]
        public required string UpdatedBy { get; set; }

        [StringLength(255)]
        public required string InsertedBy { get; set; }

        [StringLength(255)]
        public required string Entity { get; set; }

        [StringLength(500)]
        public required string ModuleAccess { get; set; }

        [StringLength(255)]
        public required string ModuleRole { get; set; }

        [StringLength(255)]
        public required string ModuleAccessRole { get; set; }

        [StringLength(255)]
        public required string Token { get; set; }

        public DateTime? TokenUpdatedAt { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        // Navigation property
        [ForeignKey("UserId")]
        public virtual User? User { get; set; }
    }
}
