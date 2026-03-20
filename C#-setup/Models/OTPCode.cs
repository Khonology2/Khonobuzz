using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace MyApi.Models
{
    [Table("otp_codes")]
    public class OTPCode
    {
        [Key]
        [StringLength(255)]
        public required string Id { get; set; }

        [Required]
        [StringLength(255)]
        public required string Email { get; set; }

        [Required]
        [StringLength(10)]
        public required string Code { get; set; }

        public bool IsUsed { get; set; } = false;

        public int Attempts { get; set; } = 0;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

        public DateTime ExpiresAt { get; set; }
    }
}
