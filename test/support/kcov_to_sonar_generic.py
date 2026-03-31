#!/usr/bin/env python3

from __future__ import annotations

import os
import sys
import xml.etree.ElementTree as ET
from collections import defaultdict


def normalize_path(path: str, repo_root: str) -> str:
    if os.path.isabs(path):
        rel_path = os.path.relpath(path, repo_root)
    else:
        rel_path = os.path.normpath(path)
    return rel_path.replace(os.sep, "/")


def main() -> int:
    if len(sys.argv) != 3:
        print(
            "usage: kcov_to_sonar_generic.py <kcov-cobertura-xml> <sonar-generic-xml>",
            file=sys.stderr,
        )
        return 1

    cobertura_path = sys.argv[1]
    sonar_path = sys.argv[2]
    repo_root = os.getcwd()

    tree = ET.parse(cobertura_path)
    root = tree.getroot()

    coverage_by_file: dict[str, dict[int, bool]] = defaultdict(dict)

    for class_node in root.findall(".//class"):
        filename = class_node.get("filename")
        if not filename:
            continue

        normalized_path = normalize_path(filename, repo_root)
        # Must match sonar.sources in sonar-project.properties
        if not (normalized_path.startswith("bin/") or normalized_path.startswith("lib/")):
            continue

        for line_node in class_node.findall("./lines/line"):
            line_number = line_node.get("number")
            hits = line_node.get("hits")
            if not line_number or hits is None:
                continue

            try:
                line_index = int(line_number)
                is_covered = int(hits) > 0
            except ValueError:
                continue

            previous_value = coverage_by_file[normalized_path].get(line_index, False)
            coverage_by_file[normalized_path][line_index] = previous_value or is_covered

    sonar_root = ET.Element("coverage", version="1")

    for filename in sorted(coverage_by_file):
        file_node = ET.SubElement(sonar_root, "file", path=filename)
        for line_number in sorted(coverage_by_file[filename]):
            ET.SubElement(
                file_node,
                "lineToCover",
                lineNumber=str(line_number),
                covered=str(coverage_by_file[filename][line_number]).lower(),
            )

    os.makedirs(os.path.dirname(sonar_path), exist_ok=True)
    ET.ElementTree(sonar_root).write(sonar_path, encoding="utf-8", xml_declaration=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
