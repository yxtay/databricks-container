# /// script
# requires-python = "~=3.11"
# dependencies = [
#     "jsonargparse",
#     "pip-requirements-parser",
# ]
# ///
def merge_requirements(
    requirements_in: str, requirements_txt: str, requirements_out: str | None = None
) -> None:
    import pathlib

    from pip_requirements_parser import RequirementsFile, sorted_specifiers

    requirements_parsed = RequirementsFile.from_file(requirements_in)
    compiled_parsed = RequirementsFile.from_file(requirements_txt)

    # for each requirement in requirement_in, take specifier from requirements_txt
    # if applicable, merge with specifiers in requirements_in
    compiled_versions = {req.name: req for req in compiled_parsed.requirements}
    for req in requirements_parsed.requirements:
        # skip local packages
        if req.is_local_path or req.is_editable:
            continue

        specifier = compiled_versions[req.name].specifier
        for spec in sorted_specifiers(req.specifier):
            if not spec.startswith(">=") and not spec.startswith("~="):
                specifier &= spec
        req.req.specifier = specifier

    requirements_out = requirements_out or requirements_in
    pathlib.Path(requirements_out).write_text(requirements_parsed.dumps())


if __name__ == "__main__":
    from jsonargparse import CLI

    CLI(merge_requirements, as_positional=False)
