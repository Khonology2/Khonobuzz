using System.ComponentModel.DataAnnotations;

namespace MyApi.DTOs.User
{
    public class UserUpdate
    {
        [StringLength(255)]
        public string? Name { get; set; }

        [StringLength(255)]
        public string? FirstName { get; set; }

        [StringLength(255)]
        public string? LastName { get; set; }

        [StringLength(255)]
        public string? Department { get; set; }

        [StringLength(255)]
        public string? Designation { get; set; }

        [StringLength(255)]
        public string? Role { get; set; }
    }
}
