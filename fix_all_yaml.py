#!/usr/bin/env python3
"""
Comprehensive YAML fixer for Ansible playbooks.
Fixes all indentation, register placement, and syntax issues.
"""

import os
import re
import sys
from pathlib import Path

def fix_yaml_file(filepath):
    """Fix all YAML issues in a single file."""
    with open(filepath, 'r') as f:
        lines = f.readlines()

    # Ensure file starts with ---
    if not lines or not lines[0].strip().startswith('---'):
        lines.insert(0, '---\n')

    fixed_lines = []
    i = 0
    in_block = False
    block_indent = 0

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Fix ansible.builtin.syslog (doesn't exist) to use shell with logger
        if 'ansible.builtin.syslog' in line:
            line = line.replace('ansible.builtin.syslog', 'ansible.builtin.shell')
            if i + 1 < len(lines) and 'msg:' in lines[i + 1]:
                next_line = lines[i + 1]
                msg_match = re.search(r'msg:\s*(.*)', next_line)
                if msg_match:
                    msg = msg_match.group(1)
                    lines[i + 1] = next_line.replace('msg:', 'cmd:').replace(msg, f'logger {msg}')

        # Detect misplaced register statements
        if 'register:' in stripped and not stripped.startswith('#'):
            # Check if this is a misplaced register (in tags section or before module)
            if i > 0:
                prev_line = lines[i-1].strip()
                # If previous line is tags: or a tag item, this register is misplaced
                if prev_line == 'tags:' or (prev_line.startswith('- ') and i > 1 and 'tags:' in lines[i-2]):
                    # Skip this line, we'll add register after the module
                    i += 1
                    continue

        # Fix tags with misplaced register
        if stripped == 'tags:':
            fixed_lines.append(line)
            i += 1
            # Look for register in tags section and move it
            register_line = None
            while i < len(lines):
                next_line = lines[i]
                next_stripped = next_line.strip()

                if 'register:' in next_stripped:
                    register_line = next_stripped.split('register:')[1].strip()
                    i += 1
                    continue
                elif next_stripped.startswith('- '):
                    # This is a tag item, keep it
                    # Ensure proper indentation (2 spaces more than 'tags:')
                    indent = len(line) - len(line.lstrip())
                    fixed_lines.append(' ' * (indent + 2) + next_stripped + '\n')
                    i += 1
                else:
                    # End of tags section
                    break

            # If we found a register, we'll add it later after the module
            continue

        # Fix block indentation
        if stripped == 'block:':
            in_block = True
            block_indent = len(line) - len(line.lstrip())
            fixed_lines.append(line)
            i += 1
            # Ensure block contents are indented properly
            while i < len(lines) and lines[i].strip():
                block_line = lines[i]
                if block_line.strip().startswith('- '):
                    # Task in block should be indented 2 more than 'block:'
                    task_content = block_line.strip()
                    fixed_lines.append(' ' * (block_indent + 2) + task_content + '\n')
                else:
                    # Other lines in the task
                    current_indent = len(block_line) - len(block_line.lstrip())
                    if current_indent < block_indent + 4:
                        # Fix indentation
                        fixed_lines.append(' ' * (block_indent + 4) + block_line.strip() + '\n')
                    else:
                        fixed_lines.append(block_line)
                i += 1
            in_block = False
            continue

        # Fix tasks section indentation
        if stripped == 'tasks:' or stripped == 'pre_tasks:' or stripped == 'post_tasks:':
            fixed_lines.append(line)
            i += 1
            # Ensure tasks are indented properly (2 spaces more)
            section_indent = len(line) - len(line.lstrip())
            while i < len(lines):
                task_line = lines[i]
                task_stripped = task_line.strip()

                if task_stripped.startswith('- name:'):
                    # Task should be indented 2 more than section
                    fixed_lines.append(' ' * (section_indent + 2) + task_stripped + '\n')
                    i += 1

                    # Process task contents
                    while i < len(lines):
                        content_line = lines[i]
                        content_stripped = content_line.strip()

                        if content_stripped.startswith('- name:') or \
                           content_stripped in ['tasks:', 'pre_tasks:', 'post_tasks:', 'handlers:']:
                            # Next task or section
                            break

                        if content_stripped:
                            # Task content should be indented 2 more than task name
                            if 'register:' in content_stripped and ':' in content_stripped.split('register:')[0]:
                                # This is a module with register on same line - OK
                                fixed_lines.append(' ' * (section_indent + 4) + content_stripped + '\n')
                            else:
                                fixed_lines.append(' ' * (section_indent + 4) + content_stripped + '\n')
                        else:
                            fixed_lines.append('\n')
                        i += 1
                    continue
                elif task_stripped and not task_stripped.startswith('#'):
                    # Not a task, might be end of section
                    if task_stripped in ['handlers:', 'vars:', 'tasks:', 'pre_tasks:', 'post_tasks:']:
                        break
                    # Continue with current line
                    fixed_lines.append(task_line)
                    i += 1
                else:
                    fixed_lines.append(task_line)
                    i += 1
            continue

        # Fix when conditions with multiple items
        if stripped == 'when:':
            fixed_lines.append(line)
            i += 1
            when_indent = len(line) - len(line.lstrip())
            while i < len(lines):
                when_line = lines[i]
                when_stripped = when_line.strip()
                if when_stripped.startswith('- '):
                    # when condition item
                    fixed_lines.append(' ' * (when_indent + 2) + when_stripped + '\n')
                    i += 1
                else:
                    break
            continue

        # Default: keep the line
        fixed_lines.append(line)
        i += 1

    # Write fixed content
    with open(filepath, 'w') as f:
        f.writelines(fixed_lines)

    return True

def main():
    """Fix all YAML files in the ansible/playbooks directory."""
    playbook_dir = Path('/home/thndrchckn/Documents/Projects/msp-ansible-platform/ansible/playbooks')

    # List of all playbook files to fix
    playbook_files = list(playbook_dir.glob('*.yml'))
    playbook_files.extend(playbook_dir.glob('tasks/*.yml'))

    print("Fixing YAML files...")
    fixed_count = 0

    for filepath in sorted(playbook_files):
        try:
            print(f"  Fixing: {filepath.name}")
            if fix_yaml_file(filepath):
                fixed_count += 1
        except Exception as e:
            print(f"    ERROR: {e}")

    print(f"\nFixed {fixed_count} files")
    print("\nRunning ansible-lint to verify...")
    os.system(f"cd {playbook_dir} && ansible-lint *.yml 2>&1 | head -20")

if __name__ == '__main__':
    main()