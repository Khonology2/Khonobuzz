using System.ComponentModel.DataAnnotations;

namespace MyApi.DTOs.User
{
    /// <summary>
    /// Matches Python backend UserUpdate - all fields optional for PATCH.
    /// </summary>
    public class UserUpdate
    {
        [StringLength(255)]
        public string? Name { get; set; }

        [StringLength(255)]
        public string? FirstName { get; set; }

        [StringLength(255)]
        public string? LastName { get; set; }

        [StringLength(255)]
        public string? Role { get; set; }

        [StringLength(50)]
        public string? Status { get; set; }

        [StringLength(255)]
        public string? Entity { get; set; }

        [StringLength(255)]
        public string? Department { get; set; }

        [StringLength(255)]
        public string? Designation { get; set; }

        [StringLength(255)]
        public string? Manager { get; set; }

        [StringLength(500)]
        public string? ModuleAccess { get; set; }

        [StringLength(255)]
        public string? ModuleRole { get; set; }

        [StringLength(255)]
        public string? ModuleAccessRole { get; set; }

        [StringLength(255)]
        public string? AdminApproved { get; set; }

        public bool? RegenerateToken { get; set; }
    }
}
