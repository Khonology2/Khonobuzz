#!/usr/bin/env python3
"""
Script to remove comments from Python files.
Removes single-line comments (#) while preserving:
- Docstrings (triple-quoted strings)
- String literals
- Inline comments that are part of code documentation
"""

import re
import sys
from pathlib import Path


def remove_python_comments(content: str) -> str:
    """Remove comments from Python code while preserving docstrings and strings."""
    lines = content.split('\n')
    result = []
    in_triple_string = False
    triple_string_char = None
    in_string = False
    string_char = None
    
    for line in lines:
        new_line = []
        i = 0
        
        while i < len(line):
            if not in_string and not in_triple_string:
                # Check for triple-quoted string (docstring)
                if i < len(line) - 2:
                    triple_quote = line[i:i+3]
                    if triple_quote in ['"""', "'''"]:
                        in_triple_string = True
                        triple_string_char = triple_quote
                        new_line.append(triple_quote)
                        i += 3
                        continue
                
                # Check for regular string start
                if line[i] in ['"', "'"]:
                    in_string = True
                    string_char = line[i]
                    new_line.append(line[i])
                    i += 1
                # Check for comment (but not in string)
                elif line[i] == '#':
                    # Check if it's part of a shebang or encoding declaration
                    if i == 0 and (line.startswith('#!') or 'coding' in line.lower() or 'encoding' in line.lower()):
                        # Keep shebang and encoding declarations
                        new_line.append(line[i:])
                        break
                    else:
                        # Regular comment, skip rest of line
                        break
                else:
                    new_line.append(line[i])
                    i += 1
            elif in_triple_string:
                new_line.append(line[i])
                # Check for triple-quoted string end
                if i < len(line) - 2 and line[i:i+3] == triple_string_char:
                    in_triple_string = False
                    triple_string_char = None
                    i += 3
                    continue
                i += 1
            elif in_string:
                new_line.append(line[i])
                # Check for string end
                if line[i] == string_char and (i == 0 or line[i-1] != '\\'):
                    in_string = False
                    string_char = None
                i += 1
        
        # Only add line if it has content
        cleaned_line = ''.join(new_line).rstrip()
        
        # Skip lines that are entirely comments (except shebang/encoding)
        if cleaned_line or (line.strip().startswith('#!') or 'coding' in line.lower() or 'encoding' in line.lower()):
            result.append(cleaned_line)
    
    return '\n'.join(result)


def clean_file(file_path: Path) -> bool:
    """Clean a single Python file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            original_content = f.read()
        
        cleaned_content = remove_python_comments(original_content)
        
        # Remove excessive blank lines (more than 2 consecutive)
        lines = cleaned_content.split('\n')
        normalized_lines = []
        blank_count = 0
        for line in lines:
            if not line.strip():
                blank_count += 1
                if blank_count <= 2:  # Allow max 2 consecutive blank lines
                    normalized_lines.append(line)
            else:
                blank_count = 0
                normalized_lines.append(line)
        
        cleaned_content = '\n'.join(normalized_lines)
        # Remove trailing empty lines
        cleaned_content = cleaned_content.rstrip() + '\n'
        
        # Only write if content changed
        if cleaned_content != original_content:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(cleaned_content)
            return True
        return False
    except Exception as e:
        print(f"Error processing {file_path}: {e}", file=sys.stderr)
        return False


def main():
    """Main function to clean Python files."""
    if len(sys.argv) < 2:
        print("Usage: python cleanup_python_comments.py <file1.py> [file2.py ...]")
        sys.exit(1)
    
    files_cleaned = 0
    for file_path_str in sys.argv[1:]:
        file_path = Path(file_path_str)
        if not file_path.exists():
            print(f"Warning: {file_path} does not exist, skipping...")
            continue
        
        if file_path.suffix != '.py':
            print(f"Warning: {file_path} is not a .py file, skipping...")
            continue
        
        if clean_file(file_path):
            print(f"Cleaned: {file_path}")
            files_cleaned += 1
        else:
            print(f"No changes: {file_path}")
    
    print(f"\nTotal files cleaned: {files_cleaned}")


if __name__ == '__main__':
    main()

