using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace MyApi.Models
{
    [Table("onboarding")]
    public class Onboarding
    {
        [Key]
        [StringLength(255)]
        public string UserId { get; set; }

        [StringLength(255)]
        public string Email { get; set; }

        [StringLength(255)]
        public string Name { get; set; }

        [StringLength(255)]
        public string Surname { get; set; }

        [StringLength(255)]
        public string FullName { get; set; }

        [StringLength(255)]
        public string Department { get; set; }

        [StringLength(255)]
        public string Designation { get; set; }

        public DateTime? FirstValid { get; set; }

        public DateTime? LastValid { get; set; }

        [StringLength(255)]
        public string OnboardingId { get; set; }

        [StringLength(255)]
        public string StatusId { get; set; }

        [StringLength(255)]
        public string UpdatedBy { get; set; }

        [StringLength(255)]
        public string InsertedBy { get; set; }

        [StringLength(255)]
        public string Entity { get; set; }

        [StringLength(500)]
        public string ModuleAccess { get; set; }

        [StringLength(255)]
        public string ModuleRole { get; set; }

        [StringLength(255)]
        public string ModuleAccessRole { get; set; }

        public string Token { get; set; }

        public DateTime? TokenUpdatedAt { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        // Navigation property
        [ForeignKey("UserId")]
        public virtual User User { get; set; }
    }
}
