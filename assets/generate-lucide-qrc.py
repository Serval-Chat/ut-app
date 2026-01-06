#!/usr/bin/env python3
"""
Generate Qt resource file for Lucide icons
"""
import os
from pathlib import Path

# Get the directory containing this script
script_dir = Path(__file__).parent
icons_dir = script_dir / "lucide" / "icons"
output_file = script_dir / "lucide-icons.qrc"

# Start building the QRC content
qrc_lines = ['<RCC>', '    <qresource prefix="/assets/lucide">']

# Find all SVG files
svg_files = sorted(icons_dir.glob("*.svg"))
print(f"Found {len(svg_files)} SVG icons")

# Add each SVG file to the resource
for svg_file in svg_files:
    relative_path = f"lucide/icons/{svg_file.name}"
    qrc_lines.append(f'        <file>{relative_path}</file>')

qrc_lines.extend(['    </qresource>', '</RCC>'])

# Write the QRC file
with open(output_file, 'w') as f:
    f.write('\n'.join(qrc_lines))
    f.write('\n')

print(f"Generated {output_file} with {len(svg_files)} icons")
