#!/usr/bin/env python3
"""
Script to remove comments from Dart files.
Removes single-line comments (//) and multi-line comments (/* */)
while preserving string literals and code structure.
"""

import re
import sys
from pathlib import Path


def remove_dart_comments(content: str) -> str:
    """Remove comments from Dart code while preserving strings."""
    lines = content.split('\n')
    result = []
    in_multiline_comment = False
    in_string = False
    string_char = None
    
    for line in lines:
        new_line = []
        i = 0
        line_in_multiline = in_multiline_comment
        
        while i < len(line):
            if not in_string and not in_multiline_comment:
                # Check for string start
                if line[i] in ['"', "'"]:
                    in_string = True
                    string_char = line[i]
                    new_line.append(line[i])
                    i += 1
                    # Handle escaped quotes
                    if i < len(line) and line[i-1] == '\\':
                        continue
                # Check for single-line comment
                elif i < len(line) - 1 and line[i:i+2] == '//':
                    # Single-line comment found, skip rest of line
                    break
                # Check for multi-line comment start
                elif i < len(line) - 1 and line[i:i+2] == '/*':
                    in_multiline_comment = True
                    line_in_multiline = True
                    i += 2
                    continue
                else:
                    new_line.append(line[i])
                    i += 1
            elif in_string:
                new_line.append(line[i])
                # Check for string end
                if line[i] == string_char and (i == 0 or line[i-1] != '\\'):
                    in_string = False
                    string_char = None
                i += 1
            elif in_multiline_comment:
                # Check for multi-line comment end
                if i < len(line) - 1 and line[i:i+2] == '*/':
                    in_multiline_comment = False
                    line_in_multiline = False
                    i += 2
                    continue
                i += 1
        
        # Only add line if it has content or wasn't entirely a comment
        cleaned_line = ''.join(new_line).rstrip()
        
        # Skip empty lines that were entirely comments
        if cleaned_line or not line_in_multiline:
            # Only add if line has meaningful content or preserves structure
            if cleaned_line.strip() or (not line_in_multiline and not in_multiline_comment):
                result.append(cleaned_line)
    
    return '\n'.join(result)


def clean_file(file_path: Path) -> bool:
    """Clean a single Dart file."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            original_content = f.read()
        
        cleaned_content = remove_dart_comments(original_content)
        
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
    """Main function to clean Dart files."""
    if len(sys.argv) < 2:
        print("Usage: python cleanup_dart_comments.py <file1.dart> [file2.dart ...]")
        sys.exit(1)
    
    files_cleaned = 0
    for file_path_str in sys.argv[1:]:
        file_path = Path(file_path_str)
        if not file_path.exists():
            print(f"Warning: {file_path} does not exist, skipping...")
            continue
        
        if file_path.suffix != '.dart':
            print(f"Warning: {file_path} is not a .dart file, skipping...")
            continue
        
        if clean_file(file_path):
            print(f"Cleaned: {file_path}")
            files_cleaned += 1
        else:
            print(f"No changes: {file_path}")
    
    print(f"\nTotal files cleaned: {files_cleaned}")


if __name__ == '__main__':
    main()

