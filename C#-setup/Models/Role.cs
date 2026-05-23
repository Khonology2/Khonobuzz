using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace MyApi.Models
{
    [Table("roles")]
    public class Role
    {
        [Key]
        [StringLength(255)]
        public required string Id { get; set; }

        [Required]
        [StringLength(255)]
        public required string Name { get; set; }

        [StringLength(500)]
        public required string Description { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
