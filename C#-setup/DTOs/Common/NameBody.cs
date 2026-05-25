using System.ComponentModel.DataAnnotations;

namespace MyApi.DTOs.Common
{
    /// <summary>
    /// DTO for endpoints that accept a single name (departments, designations).
    /// Matches Python backend NameBody: { "name": "..." }.
    /// </summary>
    public class NameBody
    {
        [StringLength(255)]
        public string? Name { get; set; }
    }
}
