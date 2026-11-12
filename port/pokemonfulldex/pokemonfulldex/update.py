#!/usr/bin/env python3
"""Checks for a newer release of this port and downloads it into PortMaster's autoinstall folder,
where PortMaster installs it the next time it is opened.

    python3 update.py <autoinstall folder>

update.cfg (written by the build when it is given an update URL) holds url= (an API address that
answers with the latest release as JSON: tag_name and assets, as GitHub does) and, for a
private repository, token=. version.txt holds this build's release tag. Builds that are not
releases (no fulldex-* tag) and any network or server trouble are left alone, quietly.

Exits 0 when there is nothing to do, 10 when an update was downloaded (its tag on stdout).
Stays compatible with Python 3.7, as PortMaster does.
"""
import hashlib
import json
import os
import ssl
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ZIP = 'pokemonfulldex.zip'


def read_config():
    cfg = {}
    with open(os.path.join(HERE, 'update.cfg')) as f:
        for line in f:
            key, sep, value = line.strip().partition('=')
            if sep:
                cfg[key] = value
    return cfg


def ssl_context():
    # (PortMaster carries certifi, for firmwares without a CA bundle of their own.)
    sys.path.insert(0, os.path.join(os.environ.get('controlfolder', ''), 'exlibs'))
    try:
        import certifi
        return ssl.create_default_context(cafile=certifi.where())
    except ImportError:
        return ssl.create_default_context()


def fetch(url, token, timeout):
    request = urllib.request.Request(url, headers={'User-Agent': 'pokemonfulldex-updater'})
    if token:
        request.add_header('Authorization', 'token ' + token)
    return urllib.request.urlopen(request, timeout=timeout, context=ssl_context())


def main():
    autoinstall = sys.argv[1]
    try:
        cfg = read_config()
        with open(os.path.join(HERE, 'version.txt')) as f:
            installed = f.read().strip()
    except OSError:
        return 0
    if not cfg.get('url') or not installed.startswith('fulldex-'):
        return 0

    token = cfg.get('token', '')
    try:
        with fetch(cfg['url'], token, 5) as response:
            release = json.load(response)
        latest = release['tag_name']
        assets = {a['name']: a['browser_download_url'] for a in release['assets']}
    except Exception as err:
        print('update check failed: %s' % err)
        return 0
    if latest == installed or ZIP not in assets:
        return 0
    target = os.path.join(autoinstall, ZIP)
    if os.path.exists(target):
        return 0  # (downloaded already, waiting for PortMaster to install it)

    print('update: %s -> %s' % (installed, latest))
    part = target + '.part'
    try:
        os.makedirs(autoinstall, exist_ok=True)
        digest = hashlib.sha256()
        with fetch(assets[ZIP], token, 30) as response, open(part, 'wb') as f:
            for block in iter(lambda: response.read(1 << 16), b''):
                digest.update(block)
                f.write(block)
        if ZIP + '.sha256' in assets:
            with fetch(assets[ZIP + '.sha256'], token, 10) as response:
                expected = response.read().decode().split()[0]
            if digest.hexdigest() != expected:
                raise ValueError('the download does not match its checksum')
        os.replace(part, target)
    except Exception as err:
        print('update download failed: %s' % err)
        if os.path.exists(part):
            os.remove(part)
        return 0
    print(latest)
    return 10


if __name__ == '__main__':
    sys.exit(main())
