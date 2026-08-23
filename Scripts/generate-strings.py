#!/usr/bin/env python3
"""Turns the string catalogue into the .strings files that actually ship.

The catalogue cannot simply be a resource. Xcode compiles an .xcstrings into
per-language .strings; SwiftPM's command-line build copies it through
uncompiled, so `swift test` finds no translations and every string quietly falls
back to its German key. Shipping both forms makes the two builds fight over the
same output path.

So the catalogue lives outside the target as the editable source of truth, and
this generates the classic files that both build systems handle the same way.
Run it after every change to the catalogue:

    python3 Scripts/generate-strings.py
"""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
CATALOG = ROOT / "Packages/SudokuUI/Localizations/Localizable.xcstrings"
RESOURCES = ROOT / "Packages/SudokuUI/Sources/SudokuUI/Resources"


def escape(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")


def main() -> None:
    catalog = json.loads(CATALOG.read_text())
    for language in catalog["strings"][next(iter(catalog["strings"]))]["localizations"]:
        lines = [
            "/* Generated from Localizable.xcstrings — edit that file, then run",
            "   Scripts/generate-strings.py. SwiftPM does not compile string",
            "   catalogues, so the classic form is what actually ships. */",
            "",
        ]
        for key in sorted(catalog["strings"]):
            value = catalog["strings"][key]["localizations"][language]["stringUnit"]["value"]
            lines.append(f'"{escape(key)}" = "{escape(value)}";')
        directory = RESOURCES / f"{language}.lproj"
        directory.mkdir(exist_ok=True)
        (directory / "Localizable.strings").write_text("\n".join(lines) + "\n", encoding="utf-8")
        print(f"{language}: {len(catalog['strings'])} entries")


if __name__ == "__main__":
    main()
