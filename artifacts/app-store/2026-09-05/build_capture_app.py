"""Build unchanged UI with isolated local preview API; restore source exactly afterward."""
from pathlib import Path
import subprocess, hashlib
root=Path(__file__).resolve().parents[3]
p=root/'mobile/lib/services/api_config.dart'
original=p.read_bytes()
try:
 p.write_bytes(original.replace(b'http://localhost:8080',b'http://localhost:18080'))
 subprocess.run(['flutter','build','ios','--simulator','--debug','--no-pub'],cwd=root/'mobile',check=True)
finally:
 p.write_bytes(original)
 print('API source restored; sha256:',hashlib.sha256(p.read_bytes()).hexdigest())
