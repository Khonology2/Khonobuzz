using Microsoft.AspNetCore.Mvc;
using MyApi.DTOs.Common;
using MyApi.Services;

namespace MyApi.Controllers;

[ApiController]
[Route("api/[controller]")]
public class EntitiesController : ControllerBase
{
    private readonly IKhonoRelationalService _relational;

    public EntitiesController(IKhonoRelationalService relational) => _relational = relational;

    [HttpGet]
    public async Task<IActionResult> ListEntities()
    {
        var names = await _relational.ListEntityNamesAsync();
        names.Sort(StringComparer.OrdinalIgnoreCase);
        return Ok(new { entities = names });
    }

    [HttpPost]
    public async Task<IActionResult> CreateEntity([FromBody] NameBody? body)
    {
        var name = (body?.Name ?? "").Trim();
        if (string.IsNullOrEmpty(name))
            return BadRequest(new { detail = "name is required" });

        var names = await _relational.CreateEntityAsync(name);
        names.Sort(StringComparer.OrdinalIgnoreCase);
        return StatusCode(201, new { entities = names });
    }
}
