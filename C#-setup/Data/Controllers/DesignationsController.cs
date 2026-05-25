using Microsoft.AspNetCore.Mvc;
using MyApi.DTOs.Common;
using MyApi.Services;

namespace MyApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class DesignationsController : ControllerBase
{
    private readonly IKhonoRelationalService _relational;

    public DesignationsController(IKhonoRelationalService relational) => _relational = relational;

    [HttpGet]
    public async Task<IActionResult> GetDesignations()
    {
        var names = await _relational.ListDesignationNamesAsync();
        return Ok(new { designations = names });
    }

    [HttpPost]
    public async Task<IActionResult> CreateDesignation([FromBody] NameBody? body)
    {
        var name = (body?.Name ?? "").Trim();
        if (string.IsNullOrEmpty(name))
            return BadRequest(new { detail = "name is required" });

        var names = await _relational.CreateDesignationAsync(name);
        return StatusCode(201, new { designations = names });
    }
}
