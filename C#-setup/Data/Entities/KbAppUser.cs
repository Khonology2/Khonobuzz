using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace MyApi.Data.Entities;

[Table("kb_app_user")]
public class KbAppUser
{
    [Key]
    [Column("id")]
    public string Id { get; set; } = "";

    [Column("email")]
    public string Email { get; set; } = "";

    [Column("password")]
    public string? Password { get; set; }

    [Column("name")]
    public string Name { get; set; } = "";

    [Column("role")]
    public string Role { get; set; } = "Staff";

    [Column("status")]
    public string Status { get; set; } = "Inactive";

    [Column("entity")]
    public string Entity { get; set; } = "";

    [Column("department")]
    public string Department { get; set; } = "";

    [Column("designation")]
    public string Designation { get; set; } = "";

    [Column("manager")]
    public string Manager { get; set; } = "";

    [Column("module_access")]
    public string ModuleAccess { get; set; } = "";

    [Column("module_role")]
    public string ModuleRole { get; set; } = "";

    [Column("module_access_role")]
    public string ModuleAccessRole { get; set; } = "";

    [Column("theme_preference")]
    public string ThemePreference { get; set; } = "dark";

    [Column("created_at")]
    public DateTime? CreatedAt { get; set; }

    [Column("updated_at")]
    public DateTime? UpdatedAt { get; set; }

    [Column("last_sign_in_at")]
    public DateTime? LastSignInAt { get; set; }

    [Column("login_count")]
    public int LoginCount { get; set; }

    [Column("admin_json", TypeName = "jsonb")]
    public string? AdminJson { get; set; }

    public KbUserProfile? Profile { get; set; }
}
