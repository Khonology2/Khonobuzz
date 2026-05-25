using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace MyApi.Data.Entities;

[Table("kb_user_email")]
public class KbUserEmail
{
    [Key]
    [Column("id")]
    public int Id { get; set; }

    [Column("user_id")]
    public string UserId { get; set; } = "";

    [Column("email")]
    public string Email { get; set; } = "";

    [Column("is_primary")]
    public bool IsPrimary { get; set; } = true;
}
