using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace MyApi.Data.Entities;

[Table("kb_admin_notification_state")]
public class KbAdminNotificationState
{
    [Key]
    [Column("user_email")]
    public string UserEmail { get; set; } = "";

    [Column("role")]
    public string Role { get; set; } = "";

    [Column("cleared_at_iso")]
    public string ClearedAtIso { get; set; } = "";

    [Column("updated_at_iso")]
    public string UpdatedAtIso { get; set; } = "";

    [Column("dismissed_ids", TypeName = "jsonb")]
    public string? DismissedIds { get; set; }
}
