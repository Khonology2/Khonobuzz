using Microsoft.AspNetCore.Mvc;
using MyApi.DTOs.Common;
using MyApi.Services;

namespace MyApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DepartmentsController : ControllerBase
{
    private readonly IKhonoRelationalService _relational;

    public DepartmentsController(IKhonoRelationalService relational) => _relational = relational;

    [HttpGet]
    public async Task<IActionResult> GetDepartments()
    {
        var names = await _relational.ListDepartmentNamesAsync();
        return Ok(new { departments = names });
    }

    [HttpPost]
    public async Task<IActionResult> CreateDepartment([FromBody] NameBody? body)
    {
        var name = (body?.Name ?? "").Trim();
        if (string.IsNullOrEmpty(name))
            return BadRequest(new { detail = "name is required" });

        var names = await _relational.CreateDepartmentAsync(name);
        return StatusCode(201, new { departments = names });
    }
}
