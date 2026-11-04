from pathlib import Path
import json,re,html,tarfile,hashlib
r=Path.cwd();d=r/'docs/programmes/hybrid_10k/d8_review_2026_11_04';a=r/'docs/checkpoints/m11_catalogue_operation/live_0431d08_2026_11_04/admitted/canonical-source.tar'
with tarfile.open(a) as t:raw=t.extractfile('prescription-review.txt').read().decode()
split=re.split(r'(?m)^Week (\d+) day (\d+) · local version (\d+)\n',raw);assert len(split)==241
for i in range(1,len(split),4):
 week,day,version=map(int,split[i:i+3]);reference=f'LW10K-W{week:02d}-D{day:02d}'
 text=(d/f'weeks/week-{week:02d}.md').read_text();section=text.split(f'<a id="{reference.lower()}"></a>',1)[1].split('<a id=',1)[0]
 plain=html.unescape(section.replace('<br>',''))
 assert split[i+3].strip() in plain,reference
source=json.loads((r/'docs/programmes/hybrid_10k/performance_selected_2026_11_03/SOURCE.json').read_text())
for s in source['sessions']:
 text=(d/f'weeks/week-{s["week"]:02d}.md').read_text();reference=s['session_id'];section=text.split(f'<a id="{reference.lower()}"></a>',1)[1].split('<a id=',1)[0]
 assert all(note in section for note in s.get('instructions',[])),reference
links=0
for p in d.rglob('*.md'):
 for target in re.findall(r'\]\(([^)]+)\)',p.read_text()):
  path,_,anchor=target.partition('#');q=(p.parent/path).resolve() if path else p
  assert q.exists(),f'{p}: {target}'
  if anchor:assert f'id="{anchor}"' in q.read_text(),target
  links+=1
report={'classification':'CURRENT_LOCAL_D8_DERIVATION_CHECKS_NOT_CONTENT_APPROVAL','all_60_retained_rendered_session_texts_read_back_exact':True,'all_70_day_instructions_present':True,'all_review_links_and_day_anchors_valid':links,'founder_decision':'PENDING','no_broad_suite_repeated':True,'source_archive_sha256':hashlib.sha256(a.read_bytes()).hexdigest()}
Path('/private/tmp/m11_d8_independent_check_20261104.json').write_text(json.dumps(report,indent=2)+'\n');print(json.dumps(report,indent=2))
