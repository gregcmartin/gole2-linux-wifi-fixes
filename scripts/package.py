#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2026 gregcmartin
"""Create a source-only release archive with deterministic ownership/timestamps."""
import hashlib
import gzip
from pathlib import Path
import tarfile

root = Path(__file__).resolve().parent.parent
version = '0.1.0-experimental'
prefix = f'gole2-linux-wifi-fixes-{version}'
dist = root / 'dist'
dist.mkdir(exist_ok=True)
archive = dist / f'{prefix}.tar.gz'
allowed = ['README.md', 'LICENSE', 'UPSTREAM.md', 'install.sh', 'uninstall.sh',
           'driver', 'docs', 'licenses', 'patches', 'scripts']
paths = []
for name in allowed:
    path = root / name
    paths.extend(sorted(path.rglob('*')) if path.is_dir() else [path])
with archive.open('wb') as stream:
    with gzip.GzipFile(filename='', mode='wb', fileobj=stream, mtime=0) as zipped:
        with tarfile.open(fileobj=zipped, mode='w') as tar:
            for path in paths:
                if not path.is_file() or path.is_symlink():
                    raise SystemExit(f'Unexpected source entry: {path}')
                if (path.suffix not in {'.c', '.h', '.md', '.sh', '.py', '.conf', '.patch', ''}
                        and path.parent.name != 'licenses'):
                    raise SystemExit(f'Unexpected source type: {path}')
                info = tar.gettarinfo(str(path), arcname=f'{prefix}/{path.relative_to(root)}')
                info.uid = info.gid = 0
                info.uname = info.gname = ''
                info.mtime = 1792530000
                info.mode = 0o755 if path.suffix in {'.sh', '.py'} else 0o644
                with path.open('rb') as content:
                    tar.addfile(info, content)
checksum = hashlib.sha256(archive.read_bytes()).hexdigest()
(dist / 'SHA256SUMS').write_text(f'{checksum}  {archive.name}\n')
print(f'{archive}\nSHA256: {checksum}')
