#!/usr/bin/env python3
"""Exercise actual Omarchy install/config/remove commands in an isolated profile.

Requires bubblewrap, Omarchy and Quickshell. The host home is read-only outside
the private namespace; desktop sockets and network are unavailable inside it.
An optional --remote URL tests a public clone after publication.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

PLUGIN = 'sarr.windowpeek'


def run(*args, env=None):
    return subprocess.check_output(args, env=env, text=True, stderr=subprocess.STDOUT, timeout=25).strip()


def inside(base):
    os.chmod(os.environ['XDG_RUNTIME_DIR'], 0o700)
    profile = Path.home()
    config = profile / '.config/omarchy/shell.json'
    baseline = {'version': 1, 'bar': {'layout': {
        'left': [{'id': 'omarchy.workspaces'}], 'center': [],
        'right': [{'id': 'omarchy.clock', 'format': 'HH:mm'}]}}, 'plugins': [],
        'idle': {'lock': 900}, 'testSentinel': 'keep-me'}
    config.parent.mkdir(parents=True, exist_ok=True)
    config.write_text(json.dumps(baseline))
    shell_dir = base / 'omarchy/shell'
    log_path = base / 'lifecycle.log'
    shell = None
    def boot():
        nonlocal shell
        shell = subprocess.Popen(['quickshell', '--no-color', '-p', str(shell_dir)],
                                 stdout=log, stderr=subprocess.STDOUT)
        deadline = time.monotonic() + 12
        while time.monotonic() < deadline:
            try:
                if run('omarchy-shell', 'shell', 'ping') == 'ok':
                    return
            except subprocess.SubprocessError:
                pass
            time.sleep(.15)
        raise AssertionError('Isolated shell did not start; ' + log_path.read_text()[-3000:])
    def stop():
        if shell:
            shell.terminate()
            shell.wait(timeout=5)
    def entries():
        return json.loads(run('omarchy', 'plugin', 'list', '--json'))
    def enabled():
        return next(p for p in entries() if p['id'] == PLUGIN)['enabled']
    def read():
        return json.loads(config.read_text())
    def saved_entry():
        return next((e for items in read()['bar']['layout'].values() for e in items if e['id'] == PLUGIN), {})
    def wait_saved(predicate):
        deadline = time.monotonic() + 5
        while time.monotonic() < deadline:
            if predicate(): return
            time.sleep(.1)
        raise AssertionError('Configuration was not persisted')
    with log_path.open('w') as log:
        try:
            boot()
            assert all(p['id'] != PLUGIN for p in entries())
            run('omarchy', 'plugin', 'add', str(base / 'source'), '--enable', '--yes')
            assert enabled()
            installed = profile / '.config/omarchy/plugins' / PLUGIN
            assert (installed / 'manifest.json').is_file()
            assert not (installed / 'install.py').exists()
            run('omarchy', 'plugin', 'validate', str(installed))
            print('PASS clean installation through actual Omarchy CLI and PluginRegistry', flush=True)
            wait_saved(lambda: json.loads(run('omarchy-shell','shell','testState'))['ready'])
            initial = json.loads(run('omarchy-shell','shell','testState'))['defaults']
            assert initial['panelStyle'] == 'wallpaper' and initial['backgroundTexture'] is True
            assert initial['backgroundBlur'] is False and initial['wallpaperTransparency'] == 70
            assert initial['wallpaperInitialized'] is False, 'New install copied theme assessment history'
            assert initial['hintsMode'] == 'auto' and initial['hintsUsed'] == 0
            assert initial['hintsRemaining'] == 100 and initial['hintsEnabled'] is True
            print('PASS fresh install uses Wallpaper/grain and a new automatic hint budget', flush=True)
            preferences = {'language':'pl','accentColor':'#EF98F5','hintsUsed':37,'hintsMode':'auto','autoUpdates':False,
                           'panelHoverDelay':0,'previewHoverDelay':1250,'popupAnimations':False, 'openOnHover':False,
                           'uiScale':1.25,'barScale':1.1,'customLabels':{'barText':'My windows'},
                           'panelStyle':'wallpaper','wallpaperTransparency':70,
                           'wallpaperThemeTransparencies':{'kanagawa':{'value':12,'defaultValue':10},
                                                          'catppuccin-latte':{'value':64,'defaultValue':70}},
                           'glassTransparency':9,'backgroundBlur':True,'backgroundTexture':True,
                           'previewBackdrop':False,'previewFit':False,
                           'shortcuts':{'open':'Alt+Super+K','numbers':'Alt','privacy':'Ctrl'},
                           'surfaceColors':{'windows':{'scope':'theme','themes':{
                               'kanagawa':{'color':'#112233','brightness':12,'opacity':63}}}},
                           'colorPresets':[{'id':'preset-1','name':'My colors','color':'#EF98F5',
                                            'style':{'accent':{'mode':'custom','color':'#EF98F5'},
                                                     'surfaces':{'panel':{'color':'#234567','brightness':3}}}}]}
            assert run('omarchy-shell','shell','testSave',json.dumps(preferences)) == 'true'
            wait_saved(lambda: saved_entry().get('hintsUsed') == 37)
            preferences_file = profile / '.local/state/windowpeek/preferences.json'
            def stored():
                return json.loads(preferences_file.read_text())['settings']
            run('omarchy','bar','set',PLUGIN,'autoUpdates','true','--json')
            wait_saved(lambda: stored().get('autoUpdates') is True)
            run('omarchy','bar','set',PLUGIN,'language','de')
            wait_saved(lambda: stored().get('language') == 'de')
            run('omarchy','bar','set',PLUGIN,'autoUpdates','false','--json')
            wait_saved(lambda: stored().get('autoUpdates') is False)
            wait_saved(lambda: saved_entry().get('_windowpeekRevision') == stored().get('_windowpeekRevision'))
            expected = saved_entry()
            assert expected['language'] == 'de' and expected['autoUpdates'] is False
            assert stored()['hintsUsed'] == 37, 'Host edits changed the hint count'
            for key, value in preferences.items():
                if key not in ('language', 'autoUpdates'):
                    assert stored()[key] == value, f'Preference lost or changed before restart: {key}'
            print('PASS Omarchy bar settings reach the durable file before restart', flush=True)
            run('omarchy','plugin','enable',PLUGIN)
            assert saved_entry() == expected, 'Idempotent enable changed settings'
            stop(); boot()
            assert enabled() and saved_entry() == expected, 'Restart lost preferences'
            run('omarchy','plugin','update',PLUGIN,'--yes')
            assert saved_entry() == expected, 'Update lost preferences'
            print('PASS repeated enable, shell restart and update preserve preferences', flush=True)
            run('omarchy','plugin','disable',PLUGIN)
            assert not enabled() and installed.is_dir()
            wait_saved(lambda: all(e['id'] != PLUGIN for items in read()['bar']['layout'].values() for e in items))
            stop(); boot()
            run('omarchy','plugin','enable',PLUGIN)
            wait_saved(lambda: enabled() and saved_entry() == expected)
            print('PASS disable/re-enable restores all preferences and hint progress automatically', flush=True)
            run('omarchy','plugin','remove',PLUGIN,'--yes')
            assert not installed.exists()
            deadline = time.monotonic()+5
            while any(p['id']==PLUGIN for p in entries()) and time.monotonic()<deadline: time.sleep(.1)
            assert all(p['id'] != PLUGIN for p in entries())
            wait_saved(lambda: read() == baseline)
            print('PASS removal restores baseline; unrelated settings stay unchanged', flush=True)
            assert (profile/'.local/state/windowpeek/preferences.json').is_file()
            stop(); boot()
            run('omarchy','plugin','add',str(base/'source'),'--enable','--yes')
            wait_saved(lambda: saved_entry() == expected)
            print('PASS reinstall restores saved preferences automatically', flush=True)
            run('omarchy','plugin','remove',PLUGIN,'--yes')
            wait_saved(lambda: read() == baseline)
        finally:
            stop()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--inside')
    parser.add_argument('--remote')
    args = parser.parse_args()
    if args.inside:
        inside(Path(args.inside)); return
    root = Path(__file__).resolve().parents[1]
    actual_config = Path.home() / '.config/omarchy/shell.json'
    before = hashlib.sha256(actual_config.read_bytes()).hexdigest() if actual_config.exists() else None
    with tempfile.TemporaryDirectory(prefix='windowpeek-lifecycle-') as directory:
        base = Path(directory)
        source = base / 'source'
        if args.remote:
            # Public clone without credential helpers, before entering the
            # network-isolated namespace. No plugin code runs during cloning.
            run('git','-c','credential.helper=','clone','--depth','1',args.remote,str(source),
                env=dict(os.environ,GIT_TERMINAL_PROMPT='0',GIT_CONFIG_GLOBAL='/dev/null'))
        else:
            source.mkdir()
            for name in [str(p.relative_to(root)) for p in root.rglob('*') if p.is_file() and not any(part in ('.git','.reference','dist','__pycache__') for part in p.relative_to(root).parts) and p.name not in ('AGENTS.md','HANDOFF.md','NEW_CHAT.txt','install.py')]:
                if not (root/name).is_file(): continue  # Tracked files may be deleted locally.
                dest=source/name; dest.parent.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(root/name,dest)
            run('git','-C',str(source),'init','-q')
            run('git','-C',str(source),'add','.')
            run('git','-C',str(source),'-c','user.name=Lifecycle test','-c','user.email=test@example.invalid',
                'commit','-qm','Disposable test snapshot')
        (base/'profile').mkdir()
        shell_dir=base/'omarchy/shell'; shell_dir.mkdir(parents=True)
        for name in ('Ui','Commons','services','plugins'):
            (shell_dir/name).symlink_to(Path('/usr/share/omarchy/shell')/name,target_is_directory=True)
        shutil.copyfile(root/'tests/lifecycle-host.qml',shell_dir/'shell.qml')
        shutil.copyfile(Path(__file__),base/'driver.py')
        env=dict(os.environ,OMARCHY_PATH=str(base/'omarchy'),XDG_RUNTIME_DIR='/run/user/'+str(os.getuid()),
                 XDG_STATE_HOME=str(Path.home()/'.local/state'), XDG_CONFIG_HOME=str(Path.home()/'.config'), XDG_CACHE_HOME=str(Path.home()/'.cache'),
                 QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',QT_QUICK_CONTROLS_STYLE='Basic',
                 QT_QPA_PLATFORMTHEME='',WAYLAND_DISPLAY='',DISPLAY='',HYPRLAND_INSTANCE_SIGNATURE='',DBUS_SESSION_BUS_ADDRESS='')
        command=['bwrap','--ro-bind','/','/','--bind',str(base),str(base),'--bind',str(base/'profile'),str(Path.home()),
                 '--tmpfs','/run','--dir',env['XDG_RUNTIME_DIR'],'--proc','/proc','--dev','/dev',
                 '--unshare-pid','--unshare-ipc','--unshare-net','--unshare-uts','--die-with-parent','--new-session',
                 '--chdir',str(base),'python3',str(base/'driver.py'),'--inside',str(base)]
        result=subprocess.run(command,env=env,text=True,capture_output=True,timeout=100)
        print(result.stdout,end='')
        if result.returncode:
            print(result.stderr)
            if (base/'lifecycle.log').exists(): print((base/'lifecycle.log').read_text()[-5000:])
        after=hashlib.sha256(actual_config.read_bytes()).hexdigest() if actual_config.exists() else None
        assert before == after, 'Live desktop configuration changed during isolated test'
        if result.returncode: raise SystemExit(result.returncode)
        print('PASS live desktop configuration untouched')


if __name__ == '__main__':
    main()
