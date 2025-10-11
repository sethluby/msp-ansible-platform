#!/usr/bin/env python3
"""
Minimal YAML indentation fixer for common Ansible patterns.

Fixes two frequent yamllint errors observed in this repo:
  1) Sequence items under mapping keys must be indented (tags:, that:, when:)
  2) Task lists (- name:) must be indented under pre_tasks:/tasks:/post_tasks:

Usage (pre-commit):
  python3 scripts/yaml_indent_fix.py file1.yml file2.yaml ...

This is conservative and line-oriented to avoid rewriting unrelated content.
"""
import sys
from pathlib import Path
from typing import List, Tuple

MAPPING_LIST_KEYS = {"tags", "that", "when", "loop", "with_items", "with_list", "with_dict", "required_controls", "msg"}
SECTION_TASK_KEYS = {"pre_tasks", "tasks", "post_tasks"}


def is_comment_or_blank(s: str) -> bool:
    t = s.strip()
    return not t or t.startswith("#")


def fix_mapping_list_indentation(lines: List[str]) -> List[str]:
    i = 0
    out: List[str] = []
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()

        # Match `<indent><key>:` where key is in MAPPING_LIST_KEYS
        if stripped.endswith(":"):
            key = stripped[:-1].strip()
            if key in MAPPING_LIST_KEYS:
                out.append(line)
                base_indent = len(line) - len(line.lstrip())
                i += 1
                # For subsequent list items directly under this key,
                # ensure they are indented base_indent + 2
                while i < len(lines):
                    nxt = lines[i]
                    nstrip = nxt.strip()
                    nindent = len(nxt) - len(nxt.lstrip())

                    # stop when we hit a less-indented or sibling key/section
                    if (nstrip.endswith(":") and (len(nxt) - len(nxt.lstrip())) <= base_indent) or (
                        not nstrip or (nindent <= base_indent and not nstrip.startswith("- "))
                    ):
                        break

                    if nstrip.startswith("- ") and nindent == base_indent:
                        # reindent the list item 2 spaces deeper than the key
                        out.append(" " * (base_indent + 2) + nstrip + "\n")
                    else:
                        out.append(nxt)
                    i += 1
                continue

        out.append(line)
        i += 1
    return out


def fix_section_task_indentation(lines: List[str]) -> List[str]:
    i = 0
    out: List[str] = []
    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        if stripped.endswith(":"):
            key = stripped[:-1].strip()
            if key in SECTION_TASK_KEYS:
                out.append(line)
                base_indent = len(line) - len(line.lstrip())
                i += 1
                while i < len(lines):
                    nxt = lines[i]
                    nstrip = nxt.strip()
                    nindent = len(nxt) - len(nxt.lstrip())

                    # stop when next section or less-indented mapping
                    if nstrip.endswith(":") and nindent <= base_indent:
                        break

                    # Reindent task list items (`- name:` or `-` at this level)
                    if nstrip.startswith("- name:") and nindent <= base_indent:
                        out.append(" " * (base_indent + 2) + nstrip + "\n")
                    else:
                        out.append(nxt)
                    i += 1
                continue

        out.append(line)
        i += 1
    return out


def ensure_doc_start(lines: List[str]) -> List[str]:
    if not lines:
        return ["---\n"]
    if not lines[0].strip().startswith("---"):
        return ["---\n"] + lines
    return lines


def _indent(s: str, n: int) -> str:
    return (" " * n) + s.strip() + "\n"


def fix_module_arg_indentation(lines: List[str]) -> List[str]:
    """Ensure module argument mappings are indented two spaces deeper than the module line.

    Example:
      ansible.builtin.copy:
      dest: /path   # becomes indented under module
    """
    i = 0
    out: List[str] = []
    TASK_LEVEL_KEYS = {
        "register",
        "changed_when",
        "failed_when",
        "when",
        "notify",
        "loop",
        "with_items",
        "with_dict",
        "with_list",
        "loop_control",
        "delegate_to",
        "retries",
        "delay",
        "until",
        "tags",
        "vars",
        "environment",
    }

    while i < len(lines):
        line = lines[i]
        stripped = line.strip()
        out.append(line)
        i += 1
        # Detect a module or mapping line: 'module:' or 'module: |' or 'module: >-'
        if (stripped.endswith(":") or stripped.endswith(":|") or stripped.endswith(": |") or stripped.endswith(":>") or stripped.endswith(": >") or stripped.endswith(":>-")) and not stripped.startswith("-"):
            # Potential mapping key or module line.
            key = stripped[:-1].strip()
            if "." in key or key in {"ansible", "command", "shell"}:
                module_indent = len(line) - len(line.lstrip())
                # Re-indent following argument lines that are at the same indent level.
                start = i
                while i < len(lines):
                    nxt = lines[i]
                    nstrip = nxt.strip()
                    nindent = len(nxt) - len(nxt.lstrip())
                    if not nstrip:
                        out.append(nxt)
                        i += 1
                        continue
                    # Stop only if we dedent below module (next section/task)
                    if nindent < module_indent:
                        break
                    # If task-level key encountered at module indent, stop module args
                    if nindent == module_indent and nstrip.endswith(":") and nstrip.split(":", 1)[0] in TASK_LEVEL_KEYS:
                        break
                    # If this looks like a module arg or scalar content and is not deeper, bump indent
                    if nindent == module_indent:
                        out.append(_indent(nstrip, module_indent + 2))
                    else:
                        out.append(nxt)
                    i += 1
                continue
    return out


def fix_block_children_indentation(lines: List[str]) -> List[str]:
    """Indent tasks under a block: by two spaces and their args by four.

    Detect a line with 'block:' and push subsequent '- name:' one level deeper
    until we hit the next de-dented section/task at or above the parent indent.
    """
    i = 0
    out: List[str] = []
    while i < len(lines):
        line = lines[i]
        out.append(line)
        i += 1
        if line.strip() == "block:":
            block_indent = len(line) - len(line.lstrip())
            # Process subsequent lines
            while i < len(lines):
                nxt = lines[i]
                nstrip = nxt.strip()
                nindent = len(nxt) - len(nxt.lstrip())
                # Stop if we dedent to block level or above and hit a new section/task
                if nindent < block_indent:
                    break
                if nstrip.startswith("- name:") and nindent == block_indent:
                    out.append(_indent(nstrip, block_indent + 2))
                elif nindent == block_indent and nstrip and not nstrip.endswith(":"):
                    # Any content line directly under block should be deeper
                    out.append(_indent(nstrip, block_indent + 2))
                elif nindent == block_indent + 2 and (nstrip and not nstrip.endswith(":")):
                    # module args one level deeper under task name
                    out.append(_indent(nstrip, block_indent + 4))
                else:
                    out.append(nxt)
                i += 1
    return out


def process_file(path: Path) -> None:
    try:
        content = path.read_text(encoding="utf-8").splitlines(keepends=True)
    except Exception:
        return

    original = content[:]
    content = ensure_doc_start(content)
    content = fix_mapping_list_indentation(content)
    content = fix_section_task_indentation(content)
    content = fix_block_children_indentation(content)
    content = fix_module_arg_indentation(content)

    if content != original:
        path.write_text("".join(content), encoding="utf-8")


def main() -> int:
    if len(sys.argv) <= 1:
        return 0
    for arg in sys.argv[1:]:
        p = Path(arg)
        if p.suffix in {".yml", ".yaml"} and p.is_file():
            process_file(p)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
