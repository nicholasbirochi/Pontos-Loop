#!/usr/bin/env python3
"""Atualiza o app de desenvolvimento a partir de commits da main, sem alterar o projeto."""
import argparse
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import sys

ROOT = Path.home() / 'Library/Application Support/Pontos Loop/Atualizador'
LABEL = 'com.nicholasbirochi.pontosloop.updater'
BUNDLE = 'com.nicholasbirochi.compraclara.ios'
REMOTE = 'https://github.com/nicholasbirochi/Pontos-Loop.git'


def run(args, cwd=None, timeout=60):
    return subprocess.run(args, cwd=cwd, check=True, capture_output=True, text=True, timeout=timeout).stdout


def save(path, value):
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(value, ensure_ascii=False, indent=2))
    temporary.chmod(0o600)
    temporary.replace(path)


def select_commit(repo, local, remote):
    if local == remote:
        return local
    for older, newer in [(local, remote), (remote, local)]:
        result = subprocess.run(['/usr/bin/git', 'merge-base', '--is-ancestor', older, newer], cwd=repo, capture_output=True)
        if result.returncode == 0:
            return newer
        if result.returncode != 1:
            raise RuntimeError('Não foi possível comparar os históricos Git.')
    raise RuntimeError('As main local e remota divergiram. Resolva o Git antes de atualizar.')


def code_changed(repo, older, newer):
    result = subprocess.run(['/usr/bin/git', 'diff', '--quiet', older, newer, '--', 'App',
                             'Packages/DecisionCore/Sources', 'Packages/DecisionCore/Package.swift',
                             'Config', 'project.yml', 'PontosLoop.xcodeproj'], cwd=repo, capture_output=True)
    if result.returncode not in (0, 1):
        raise RuntimeError('Não foi possível conferir as mudanças do aplicativo.')
    return result.returncode == 1


def phone_json(config, command):
    return json.loads(run(['/usr/bin/xcrun', 'devicectl', 'device', *command,
                           '--device', config['device'], '--json-output', '-'], timeout=45))['result']


def app_running(config):
    result = phone_json(config, ['info', 'processes', '--search', 'PontosLoop'])
    return any(Path(p.get('executable', '')).name == 'PontosLoop' for p in result.get('runningProcesses', []))


def install(config, repo, sha, state, force=False):
    now = dt.datetime.now(dt.timezone.utc).timestamp()
    if not force and state.get('installedCommit') and state.get('expiresAt', 0) > now:
        if not code_changed(repo, state['installedCommit'], sha):
            state['installedCommit'] = sha
            save(ROOT / 'state.json', state)
            return 'Em dia: código já instalado e assinatura válida.'
    if not force and state.get('failedCommit') == sha and state.get('failures', 0) >= 3:
        return 'Pausado após 3 falhas deste commit. Use o atalho para tentar de novo.'
    try:
        details = phone_json(config, ['info', 'details'])
        if not details.get('deviceProperties', {}).get('ddiServicesAvailable'):
            return 'Pendente: conecte/desbloqueie o iPhone e confira o Modo de Desenvolvedor.'
        if app_running(config):
            return 'Pendente: feche o Pontos Loop no seletor de apps do iPhone para atualizar.'
    except (subprocess.SubprocessError, KeyError, ValueError):
        return 'Pendente: iPhone indisponível. A atualização aguardará a próxima verificação.'
    try:
        # Somente a cópia descartável do atualizador é restaurada, nunca o projeto do usuário.
        run(['/usr/bin/git', 'checkout', '--force', '--detach', sha], cwd=repo)
        if config.get('generator'):
            run([config['generator'], 'generate', '--spec', 'project.yml'], cwd=repo)
        derived = ROOT / 'Build'
        with (ROOT / 'build.log').open('w') as log:
            subprocess.run(['/usr/bin/xcodebuild', '-project', 'PontosLoop.xcodeproj', '-scheme', 'PontosLoop-iOS',
                            '-configuration', 'Debug', '-destination', 'id=' + config['device'],
                            '-derivedDataPath', str(derived), '-allowProvisioningUpdates', '-allowProvisioningDeviceRegistration',
                            'DEVELOPMENT_TEAM=' + config['team'], 'build'], cwd=repo, stdout=log, stderr=subprocess.STDOUT,
                           check=True, timeout=600)
        app = derived / 'Build/Products/Debug-iphoneos/PontosLoop.app'
        run(['/usr/bin/codesign', '--verify', '--deep', '--strict', str(app)])
        info = plistlib.loads((app / 'Info.plist').read_bytes())
        if info.get('CFBundleIdentifier') != BUNDLE:
            raise RuntimeError('O identificador do app mudou. Confira o projeto no Xcode.')
        profile = plistlib.loads(subprocess.run(['/usr/bin/security', 'cms', '-D', '-i', str(app / 'embedded.mobileprovision')],
                                                check=True, capture_output=True).stdout)
        if config['device'] not in profile.get('ProvisionedDevices', []):
            raise RuntimeError('O perfil não inclui o iPhone configurado.')
        expires = profile['ExpirationDate'].replace(tzinfo=dt.timezone.utc).timestamp()
        if expires <= dt.datetime.now(dt.timezone.utc).timestamp():
            raise RuntimeError('O perfil continua vencido; confira a conta no Xcode.')
        # O usuário pode ter reaberto o app durante a compilação.
        if app_running(config):
            return 'Compilado: feche o Pontos Loop para permitir a instalação.'
        run(['/usr/bin/xcrun', 'devicectl', 'device', 'install', 'app', '--device', config['device'], str(app)], timeout=120)
        state.update(installedCommit=sha, expiresAt=expires, failures=0, failedCommit='')
        save(ROOT / 'state.json', state)
        return 'Atualizado: commit ' + sha[:7] + '. Abra o Pontos Loop no iPhone.'
    except (subprocess.SubprocessError, OSError, ValueError, RuntimeError, KeyError):
        state['failures'] = state.get('failures', 0) + 1 if state.get('failedCommit') == sha else 1
        state['failedCommit'] = sha
        save(ROOT / 'state.json', state)
        raise


def update(config, force=False):
    repo = ROOT / 'Sources'
    repo.mkdir(exist_ok=True)
    if not (repo / '.git').is_dir():
        run(['/usr/bin/git', 'init', str(repo)])
    run(['/usr/bin/git', 'fetch', '--quiet', REMOTE, '+main:refs/remotes/updates/main'], cwd=repo)
    remote = run(['/usr/bin/git', 'rev-parse', 'refs/remotes/updates/main'], cwd=repo).strip()
    state_path = ROOT / 'state.json'
    state = json.loads(state_path.read_text()) if state_path.exists() else {}
    local = state.get('installedCommit', remote)
    # O agente não precisa de acesso ao OneDrive; o atalho manual também aceita commits locais.
    if force:
        run(['/usr/bin/git', 'fetch', '--quiet', config['project'], '+main:refs/remotes/local/main'], cwd=repo)
        local = run(['/usr/bin/git', 'rev-parse', 'refs/remotes/local/main'], cwd=repo).strip()
    sha = select_commit(repo, local, remote)
    return install(config, repo, sha, state, force)


def setup(project, device):
    project = Path(project).resolve()
    source = (project / 'PontosLoop.xcodeproj/project.pbxproj').read_text()
    teams = set(re.findall(r'DEVELOPMENT_TEAM\s*=\s*"?([A-Z0-9]{10})"?;', source))
    if len(teams) != 1:
        raise RuntimeError('Selecione sua equipe pessoal no target iOS do Xcode antes de configurar.')
    if not re.fullmatch(r'[A-Fa-f0-9-]{20,40}', device):
        raise RuntimeError('Informe o UDID do iPhone listado por xcrun devicectl list devices.')
    ROOT.mkdir(parents=True, exist_ok=True)
    ROOT.chmod(0o700)
    generator = shutil.which('xcodegen')
    save(ROOT / 'config.json', dict(project=str(project), device=device, team=teams.pop(), generator=generator))
    shutil.copyfile(__file__, ROOT / 'updater.py')
    agent = Path.home() / 'Library/LaunchAgents' / (LABEL + '.plist')
    agent.parent.mkdir(parents=True, exist_ok=True)
    agent.write_bytes(plistlib.dumps(dict(Label=LABEL,
        ProgramArguments=['/usr/bin/python3', str(ROOT / 'updater.py')], StartInterval=300,
        StandardOutPath=str(ROOT / 'launch.log'), StandardErrorPath=str(ROOT / 'launch-error.log'))))
    subprocess.run(['/bin/launchctl', 'bootout', 'gui/' + str(os.getuid()) + '/' + LABEL], capture_output=True)
    run(['/bin/launchctl', 'enable', 'gui/' + str(os.getuid()) + '/' + LABEL])
    run(['/bin/launchctl', 'bootstrap', 'gui/' + str(os.getuid()), str(agent)])
    return 'Atualização configurada: verificação a cada 5 minutos enquanto o Mac estiver ligado.'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--setup', action='store_true')
    parser.add_argument('--project', default=str(Path(__file__).resolve().parent.parent))
    parser.add_argument('--device')
    parser.add_argument('--force', action='store_true')
    parser.add_argument('--status', action='store_true')
    parser.add_argument('--stop', action='store_true')
    args = parser.parse_args()
    try:
        if args.stop:
            run(['/bin/launchctl', 'disable', 'gui/' + str(os.getuid()) + '/' + LABEL])
            subprocess.run(['/bin/launchctl', 'bootout', 'gui/' + str(os.getuid()) + '/' + LABEL], capture_output=True)
            print('Atualização automática desativada. A configuração local foi preservada.'); return
        if args.setup:
            if not args.device:
                parser.error('--setup exige --device UDID')
            print(setup(args.project, args.device)); return
        config = json.loads((ROOT / 'config.json').read_text())
        if args.status:
            print((ROOT / 'status.txt').read_text() if (ROOT / 'status.txt').exists() else 'Aguardando primeira verificação.'); return
        with (ROOT / 'lock').open('w') as lock:
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                print('Outra atualização já está em andamento.'); return
            message = update(config, args.force)
        (ROOT / 'status.txt').write_text(message)
        print(message)
    except (subprocess.SubprocessError, OSError, ValueError, RuntimeError, KeyError) as error:
        # Logs completos da compilação permanecem privados; não imprimir certificados/conta.
        message = 'Atualização não concluída: ' + (str(error) if isinstance(error, RuntimeError) else type(error).__name__) + '. Confira os logs locais do atualizador.'
        if ROOT.exists():
            (ROOT / 'status.txt').write_text(message)
            details = getattr(error, 'stderr', '') or type(error).__name__
            if isinstance(details, bytes): details = details.decode(errors='replace')
            diagnostic = ROOT / 'error.log'
            diagnostic.write_text(details)
            diagnostic.chmod(0o600)
        print(message, file=sys.stderr)
        raise SystemExit(1)


if __name__ == '__main__':
    main()
