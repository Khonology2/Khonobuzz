using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace MyApi.Data.Entities;

[Table("kb_entity")]
public class KbEntity
{
    [Key]
    [Column("id")]
    public string Id { get; set; } = "";

    [Column("name")]
    public string Name { get; set; } = "";

    [Column("assigned_user_ids", TypeName = "jsonb")]
    public string? AssignedUserIds { get; set; }

    [Column("raw", TypeName = "jsonb")]
    public string? Raw { get; set; }

    [Column("created_at")]
    public DateTime? CreatedAt { get; set; }
}
