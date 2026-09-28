#!/usr/bin/env python3
"""Prepare pinned MIT logo assets offline; requires ImageMagick. Never run by the plugin."""
from pathlib import Path
import urllib.request, subprocess, json, hashlib
root=Path(__file__).resolve().parents[1]
out=root/'vendor/ttfx';out.mkdir(exist_ok=True)
sha='702b630512e76dc8edcbba47cf948e857bed8d77'
base=f'https://raw.githubusercontent.com/omacom/ttfx/{sha}/'
names='beams binarypath blackhole bouncyballs bubbles burn colorshift crumble decrypt errorcorrect expand fireworks highlight laseretch matrix middleout orbittingvolley overflow pour print rain randomsequence rings scattered slice slide smoke spotlights spray swarm sweep synthgrid thunderstorm unstable vhstape waves wipe'.split()
meta={'commit':sha,'files':{}}
cache=Path.home()/'.cache/windowpeek-logo-sources'/sha;cache.mkdir(parents=True,exist_ok=True)
for name in names:
    src=cache/(name+'.gif')
    if not src.exists(): src.write_bytes(urllib.request.urlopen(base+'docs/effects/'+name+'.gif').read())
    # Coalesce disposal before removing only the exact corner backdrop. Keep timings,
    # canvas, original effect colours and full frame geometry. All work is build-time.
    background=subprocess.check_output(['magick',str(src)+'[0]','-format','%[pixel:p{0,0}]','info:'],text=True).strip()
    target=out/(name+'.gif')
    # -dispose only supplies a default for newly read frames; it does not
    # overwrite the originals' disposal metadata. Transparent full frames must
    # clear between displays or earlier moving characters accumulate forever.
    subprocess.run(['magick',str(src),'-coalesce','-transparent',background,'-background','none','-set','dispose','Background','+dither','-loop','0',str(target)],check=True,capture_output=True)
    original=subprocess.check_output(['magick',str(src),'-coalesce','-depth','8','rgb:-'])
    prepared=subprocess.check_output(['magick',str(target),'-coalesce','-background',background,'-alpha','remove','-alpha','off','-depth','8','rgb:-'])
    if original != prepared: raise RuntimeError(f'{name}: prepared playback differs from original frames')
    expected_mask=subprocess.check_output(['magick',str(src),'-coalesce','-transparent',background,'-alpha','extract','-depth','8','gray:-'])
    actual_mask=subprocess.check_output(['magick',str(target),'-coalesce','-alpha','extract','-depth','8','gray:-'])
    if expected_mask != actual_mask: raise RuntimeError(f'{name}: transparent playback leaves trails or drops pixels')
    timing=lambda file: subprocess.check_output(['magick','identify','-format','%w,%h,%T\\n',str(file)])
    # Source GIFs may store partial frames; compare their coalesced dimensions.
    original_timing=subprocess.check_output(['magick',str(src),'-coalesce','-format','%w,%h,%T\\n','info:'])
    if original_timing != timing(target): raise RuntimeError(f'{name}: frame geometry or timing changed')
    subprocess.run(['magick',str(src),'-coalesce','-delete','0--2','-transparent',background,str(out/(name+'.png'))],check=True,capture_output=True)
    meta['files'][name]={'sourceSha256':hashlib.sha256(src.read_bytes()).hexdigest(),'sha256':hashlib.sha256(target.read_bytes()).hexdigest()}
    print(name, target.stat().st_size, 'all frames, transparency, colours and timings exact', flush=True)
for name in ['LICENSE','NOTICE']:
    (out/name).write_bytes(urllib.request.urlopen(base+name).read())
(out/'sources.json').write_text(json.dumps(meta,indent=2)+'\n')
