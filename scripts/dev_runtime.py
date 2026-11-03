#!/usr/bin/env python3
"""Small Unix process/terminal primitives for dev.sh; no service policy lives here."""
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import termios
import time


def signal_group(pid, signum):
    try:
        os.killpg(pid, signum)
    except ProcessLookupError:
        pass


def stop_command(process):
    signal_group(process.pid, signal.SIGTERM)
    try:
        process.wait(timeout=.25)
    except subprocess.TimeoutExpired:
        pass
    # A completed parent can still have descendants in its private group.
    signal_group(process.pid, signal.SIGKILL)
    process.wait(timeout=1)


def run_command(deadline_path, cwd, argv):
    deadline = None if deadline_path == '-' else float(Path(deadline_path).read_text())
    if deadline is not None and time.monotonic() >= deadline:
        print('Local development command timed out.', file=sys.stderr)
        return 124
    cancelled = None

    def cancel(signum, _frame):
        nonlocal cancelled
        if cancelled is None:
            cancelled = 128 + signum

    signal.signal(signal.SIGINT, cancel)
    signal.signal(signal.SIGTERM, cancel)
    # Background jobs already have a group under Bash job control. After terminal
    # handoff job control is off, so establish the helper's own group if needed.
    if os.getpgrp() != os.getpid():
        os.setsid()
    if cancelled is not None:
        return cancelled
    process = subprocess.Popen(argv, cwd=cwd, stdin=subprocess.DEVNULL, start_new_session=True)
    try:
        while True:
            if cancelled is not None:
                return cancelled
            if deadline is not None and time.monotonic() >= deadline:
                print('Local development command timed out.', file=sys.stderr)
                return 124
            try:
                status = process.wait(timeout=.1)
                return status if status >= 0 else 128 - status
            except subprocess.TimeoutExpired:
                pass
    finally:
        stop_command(process)


def terminal(action, path, pid=None):
    if action == 'restore' and not Path(path).exists():
        return
    fd = os.open('/dev/tty', os.O_RDWR)
    previous = signal.signal(signal.SIGTTOU, signal.SIG_IGN)
    try:
        if action == 'save':
            attrs = termios.tcgetattr(fd)
            attrs[6] = [list(value) if isinstance(value, bytes) else value for value in attrs[6]]
            # The foreground Python invocation is transient; restore the driver's
            # group, not the short-lived helper's current foreground group.
            data = {'group': os.getpgid(int(pid)), 'attrs': attrs}
            Path(path).write_text(json.dumps(data))
            Path(path).chmod(0o600)
        elif action == 'give':
            try:
                group = os.getpgid(int(pid))
            except ProcessLookupError:
                return
            if group != int(pid):
                raise ValueError('mobile process does not own its group')
            os.tcsetpgrp(fd, group)
        elif action == 'restore':
            data = json.loads(Path(path).read_text())
            os.tcsetpgrp(fd, data['group'])
            data['attrs'][6] = [bytes(value) if isinstance(value, list) else value for value in data['attrs'][6]]
            termios.tcsetattr(fd, termios.TCSANOW, data['attrs'])
        else:
            raise ValueError('unknown terminal operation')
    finally:
        signal.signal(signal.SIGTTOU, previous)
        os.close(fd)


def main():
    action = sys.argv[1]
    if action == 'deadline':
        Path(sys.argv[2]).write_text(str(time.monotonic() + float(sys.argv[3])))
    elif action == 'run':
        return run_command(sys.argv[2], sys.argv[3], sys.argv[4:])
    elif action.startswith('tty-'):
        terminal(action[4:], sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
    else:
        raise ValueError('unknown local runtime operation')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, subprocess.SubprocessError):
        print('Local process control failed; inspect the failed development stage.', file=sys.stderr)
        sys.exit(1)
