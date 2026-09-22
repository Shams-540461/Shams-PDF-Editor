# Optional original fonts

Place licensed static .ttf files here if the original font isn't installed on the
service computer. Supply the real regular/bold/italic/bold-italic faces you need.
Restart using start_text_service.cmd so fonts copy to the build output and the
catalog reloads. No fonts or font license grants are included in this project.

Auto scans this folder (first), Windows Fonts, and per-user Windows Fonts.
It matches PDF font names (with subset prefix removed) against font family/full/
PostScript metadata, then uses a real face in the same four-style family.
It does not extract PDF embedded subset programs. OTF/CFF, TTC collections,
variable fonts and restricted embedding faces are not supported by this resolver.
Font version identity cannot be guaranteed by name matching alone. A missing
font/style yields an error; it never silently substitutes another family.
