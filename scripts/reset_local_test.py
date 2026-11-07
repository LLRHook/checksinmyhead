#!/usr/bin/env python3
"""Explicit destruction of a labelled synthetic local test project, never ordinary down.

No Compose config/env is evaluated. Inventory and validate every resource/mount before
any deletion; operate on exact container/network IDs and verified volume names.
"""
import argparse
import json
import re
import subprocess
import sys

OWNER_LABEL = "io.billington.test-owner"
DATA_LABEL = "io.billington.test-data"
PROJECT_LABEL = "com.docker.compose.project"


def docker(*args):
    return subprocess.check_output(["docker", *args], text=True, timeout=30).strip()


def reset(project, owner):
    if not re.fullmatch(r"billington-(?:test|vv)-[a-z0-9][a-z0-9-]{7,60}", project):
        raise ValueError("Refuse reset: select an isolated billington-test-* or billington-vv-* project.")
    if not re.fullmatch(r"[a-zA-Z0-9-]{16,80}", owner):
        raise ValueError("Refuse reset: supply its explicit test owner token (16–80 letters/digits/hyphens).")

    def inventory():
        resources = {}
        for kind, args in (
            ("container", ("ps", "--all", "--quiet", "--no-trunc")),
            ("volume", ("volume", "ls", "--quiet")),
            ("network", ("network", "ls", "--quiet", "--no-trunc")),
        ):
            names = docker(*args, "--filter", f"label={PROJECT_LABEL}={project}").split()
            if kind == "container" and names:
                # Inspect only ownership and mounts; never read container env values.
                projection = '{"Id":{{json .Id}},"Labels":{{json .Config.Labels}},"Mounts":{{json .Mounts}}}'
                rows = [json.loads(line) for line in docker(kind, "inspect", "--format", projection, *names).splitlines()]
            else:
                rows = json.loads(docker(kind, "inspect", *names)) if names else []
            for row in rows:
                labels = row.get("Labels") or {}
                if (labels.get(PROJECT_LABEL) != project or labels.get(OWNER_LABEL) != owner
                        or labels.get(DATA_LABEL) != "synthetic"):
                    raise ValueError(f"Refuse reset: wrong/missing ownership or synthetic-data label on {kind}.")
            resources[kind] = rows
        volumes = {row["Name"] for row in resources["volume"]}
        if not volumes:
            raise ValueError("Refuse reset: no owned synthetic data volume found.")
        for row in resources["container"]:
            for mount in row.get("Mounts", []):
                if mount["Type"] != "tmpfs" and (mount["Type"] != "volume" or mount.get("Name") not in volumes):
                    raise ValueError("Refuse reset: a container mounts data outside the owned test volumes.")
        return resources

    resources = inventory()
    # Detect inventory changes before the first mutation; no broad compose down -v.
    if resources != inventory():
        raise ValueError("Refuse reset: test resource inventory changed; inspect before retrying.")
    for row in resources["container"]:
        docker("container", "rm", "--force", row["Id"])
    # A volume still used by any other container is rejected by Docker (no force).
    for row in resources["volume"]:
        current = json.loads(docker("volume", "inspect", row["Name"]))[0]
        if current != row:
            raise ValueError("Refuse reset: data volume changed after inventory.")
        docker("volume", "rm", row["Name"])
    for row in resources["network"]:
        docker("network", "rm", row["Id"])
    print(f"Reset owned synthetic project {project}; normal project data was not selected.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", required=True)
    parser.add_argument("--owner", required=True)
    args = parser.parse_args()
    try:
        reset(args.project, args.owner)
    except (ValueError, subprocess.SubprocessError) as error:
        print(str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
