using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace MyApi.Data.Entities;

[Table("kb_role_definition")]
public class KbRoleDefinition
{
    [Key]
    [Column("id")]
    public string Id { get; set; } = "";

    [Column("role_name")]
    public string RoleName { get; set; } = "";

    [Column("description")]
    public string Description { get; set; } = "";

    [Column("page_access", TypeName = "jsonb")]
    public string? PageAccess { get; set; }

    [Column("created_at")]
    public DateTime? CreatedAt { get; set; }

    [Column("updated_at")]
    public DateTime? UpdatedAt { get; set; }
}
