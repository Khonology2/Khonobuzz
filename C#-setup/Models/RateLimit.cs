using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace MyApi.Models
{
    [Table("rate_limits")]
    public class RateLimit
    {
        [Key]
        [StringLength(255)]
        public required string Id { get; set; }

        [Required]
        [StringLength(255)]
        public required string Identifier { get; set; }

        public int RequestCount { get; set; } = 0;

        public DateTime WindowStart { get; set; } = DateTime.UtcNow;

        public DateTime WindowEnd { get; set; }
    }
}
