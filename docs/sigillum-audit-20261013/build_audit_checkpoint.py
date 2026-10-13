"""Read-only SIGILLUM source index; produces documentation, never patches app/server.

The review ledger is explicit human coverage. Static indexing is not semantic
review or proof of runtime reachability. Materialized backend is a scratch copy.
"""
from pathlib import Path
import json, re, hashlib, gzip
from collections import Counter
import argparse

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--analysis-root', type=Path, default=Path(__file__).resolve().parent,
                    help='Directory with app/backend git-archive snapshots and inventory inputs.')
ROOT = parser.parse_args().analysis_root.resolve()
OUT = ROOT / 'checkpoint'
OUT.mkdir(exist_ok=True)

APP_FULL = '''main.dart sigillum_edition.dart hcv_engine.dart hcv_identity.dart hcv_keystore_signer.dart hcv_secure_store.dart hcv_verifier.dart hcv_photo_semantic_framing_inference.dart hcv_photo_semantic_framing_contract.dart hcv_photo_semantic_framing_runner.dart hcv_photo_framing_evidence.dart hcv_photo_visual_framing.dart hcv_scene_decision_fusion.dart hcv_scene_geometry_classifier.dart hcv_multi_evidence_display_policy.dart hcv_auth_service.dart commercial_account_service.dart commercial_billing_service.dart hcv_package.dart verified_originals_reference.dart hcv_capture_location.dart hcv_capture_provenance.dart hcv_software_attestation.dart video_transcription_service.dart hcv_import_router_page.dart hcv_import_service.dart hcv_registry_service.dart hcv_registry_provenance.dart hcv_secure_media_vault.dart verified_originals_publish_service.dart hcv_ml_model_store.dart hcv_ml_v3_photo_residual.dart hcv_ml_screen_replay_classifier.dart manual_reference_compare_page.dart verified_reference_viewer_page.dart hcv_secure_preview_service.dart'''.split()
APP_EXTRA = ['ios/Runner/AppDelegate.swift', 'ios/Runner/SceneDelegate.swift', 'ios/SigillumShareExtension/ShareViewController.swift', 'codemagic.yaml', 'tool/README_materialization_20260826.md', 'tool/pin_tflite_ios_runtime_20260826.sh', 'tool/build_testflight_ipa_rc2_20260825.sh']
APP_FULL += '''hcv_crypto.dart hcv_provenance_chain.dart hcv_text_integrity.dart hcv_photo_detail_compare.dart hcv_audio_fingerprint.dart hcv_social_fingerprint.dart hcv_spatial_fingerprint_v2.dart hcv_display_final_policy.dart hcv_context_free_display_policy.dart hcv_reference_visual_fingerprint_v3.dart'''.split()
APP_EXTRA += '''test/photo_detail_compare_v4_test.dart test/photo_semantic_capture_isolation_test.dart test/photo_semantic_opencv_preprocessing_parity_test.dart test/photo_semantic_framing_tflite_asset_test.dart ml/sigillum_photo_framing_v1_PARITY.json'''.split()
BACKEND_FULL = '''primary_reference_read_auth.js primary_reference_manifest.js sigillum_connector_runtime.js sigillum_connector_remote.js sigillum_mcp_service.js sigillum_mcp_dispatcher.js sigillum_mcp_auth.js sigillum_connector_bridge.js sigillum_connector_grant_adapter.js sigillum_connector_r2_capture.js sigillum_connector_oauth.js sigillum_mcp_credentials.js sigillum_owner_web_auth.js sigillum_connector_audit_request.js sigillum_connector_oauth_ui.js package.json render.production.yaml tool/apply_verified_originals_production.py tool/apply_sigillum_connector_runtime.py docs/sigillum/HANDOFF.md docs/sigillum/OPEN_ISSUES.md docs/sigillum/DEPLOYMENT_STATE.md REFERENCE_PROVIDER_DECISION_20261001.md'''.split()
BACKEND_FULL += '''photo_detail_compare.js photo_detail_compare_test.js certificate_account_binding.js registry_provenance_v2.js hcv_signature_canonical.js app_store_billing.js production_config.js primary_reference_lifecycle.js primary_reference_provider.js'''.split()
PARTIAL = {
 'app': {
  'lib/camera_page.dart': [[440,660],[663,2665]],
  'lib/registry_verify_page.dart': [[830,1004],[1296,1957],[2068,2305],[2494,2613]],
  'lib/commercial_gate.dart': [[564,1415]],
  'lib/commercial_profile_page.dart': [[465,539]],
 },
 'backend': {
  'production_server.js': [[1,90],[397,421],[590,820],[879,901],[1169,1219],[1378,1552]],
  'verified_originals_production.js': [[1,85],[1377,1518],[1915,2197],[2759,2882],[4870,4989]],
 }
}

def role(repo, path, kind):
 if kind in ['binary','vendored-node_modules','historical-copy','documentation','test','build-or-operations']: return kind
 p=path.lower()
 if '/node_modules/' in p: return 'vendored dependency'
 if p.startswith('lib/'):
  if any(s in p for s in ['copy','localization','theme']): return 'UI copy/localization/theme'
  if any(s in p for s in ['camera','capture','watermark','transcription']): return 'capture/finalization/native media'
  if any(s in p for s in ['photo','screen','display','scene','ml_','motion','temporal','live_']): return 'scene/ML/optical evidence'
  if any(s in p for s in ['commercial','account','auth','identity','secure_store']): return 'account/device/entitlement'
  if any(s in p for s in ['vault','secure_original','publish','verified_original','reference_viewer']): return 'local custody/reference/export'
  if any(s in p for s in ['verify','verifier','fingerprint','ocr','import','provenance','package','crypto','text_']): return 'certification/import/verification'
  return 'app source; see import edges'
 if p.startswith('sigillum_'): return 'connector/OAuth/MCP'
 if 'primary_reference' in p or 'verified_original' in p or 'delegated' in p: return 'private reference/audit lifecycle'
 if p.startswith('ios/'): return 'native iOS/configuration'
 return 'source/configuration; see dependency edges'

indexes={}
edges=[]
for repo in ['app','backend']:
 data=json.loads((ROOT/f'{repo}-inventory.json').read_text())
 fully=set(['lib/'+p for p in APP_FULL]+APP_EXTRA if repo=='app' else BACKEND_FULL)
 for item in data['files']:
  path=item['path']; item['role']=role(repo,path,item['kind'])
  if path in fully:
   item['review']='source-read-complete'
  elif path in PARTIAL[repo]:
   item['review']='source-read-partial'
   item['reviewed_ranges']=PARTIAL[repo][path]
   if repo=='backend' and path=='production_server.js': item['review_ranges_target']='scratch-materialized-runtime'
  else: item['review']='indexed-only'
  for target in item['resolved_imports']: edges.append({'repository':repo,'from':path,'to':target,'kind':'static-local-import','runtime_activation':'not-proven-by-import'})
  if repo=='app':
   for imp in item['imports']:
    if imp.startswith('package:sigillum_iphone/'):
     target='lib/'+imp.removeprefix('package:sigillum_iphone/')
     if (ROOT/repo/target).is_file():
      edges.append({'repository':repo,'from':path,'to':target,'kind':'package-local-import','runtime_activation':'test-or-source-cross-reference'})
 indexes[repo]=data

# Re-read every tracked file in both exact snapshots. Original inventory hash
# refers to checked-in bytes; a separate hash identifies materialized runtime.
for repo,data in indexes.items():
 for f in data['files']:
  b=(ROOT/repo/f['path']).read_bytes()
  f['snapshot_sha256']=hashlib.sha256(b).hexdigest()
  f['runtime_materialized_difference']=f['snapshot_sha256']!=f['sha256']
  try: source=b.decode('utf-8')
  except UnicodeDecodeError: continue
  # Supplement original import extractor with Node requires after precheck.
  if repo=='backend' and f['runtime_materialized_difference']:
   f['materialized_imports']=re.findall(r'require\([\'"]([^\'"]+)[\'"]\)',source)
   for imp in f['materialized_imports']:
    if not imp.startswith('.'): continue
    target=(Path(f['path']).parent/imp).as_posix()
    target=target.removeprefix('./')
    if not Path(target).suffix: target+='.js'
    edges.append({'repository':repo,'from':f['path'],'to':target,'kind':'materialized-local-import','runtime_activation':'see-prestart-order'})
  f['native_invocations']=sorted(set(re.findall(r'invoke(?:Map|List)?Method(?:<[^;\n]*?>)?\s*\(\s*[\'"]([^\'"]+)[\'"]',source)))
  f['channel_methods']=sorted(set(re.findall(r'(?:case\s+|call\.method\s*==\s*)[\'"]([^\'"]+)[\'"]',source)))
  # API strings are a lexical cross-reference, including templates/parameters.
  f['api_literals']=sorted(set(re.findall(r'[\'"`]([^\'"`\n]*?/api/[^\'"`\n]*)[\'"`]',source)))

combined={'app':indexes['app'],'backend':indexes['backend'],
 'notes':['All tracked paths indexed. Human semantic review coverage is explicit; indexed-only is not reviewed.',
 'Backend snapshot was materialized only in scratch via Python precheck scripts; DB prestart schema installer was not executed.',
 'Static import closure includes Lab routes and legacy code; it is not an execution trace.'],
 'dependency_edges':edges,
 'backend_materialization':json.loads((ROOT/'backend-materialization.json').read_text())}
(OUT/'SOURCE_INDEX.json').write_text(json.dumps(combined,ensure_ascii=False,indent=2)+'\n')
with gzip.GzipFile(filename=str(OUT/'SOURCE_INDEX.json.gz'),mode='wb',mtime=0) as out:
 out.write(json.dumps(combined,ensure_ascii=False,separators=(',',':')).encode())

lines=['# Inventario e registro di lettura','',
 'Snapshot app: `f7023853bcdfce927fd760357fe427e9d92ad34b` (base 157 indicata nel documento utente).',
 'Snapshot backend: `7e3bcbd694a75079e605277ce81535f4d9785c54` (HEAD documentale; deploy distinto).','',
 '**La revisione integrale non è conclusa.** Tutti i file tracciati sono indicizzati; solo le righe con stato `source-read-complete` attestano lettura semantica completa. `source-read-partial` indica gli intervalli letti; `indexed-only` indica soltanto indicizzazione. Asset binari e dipendenze vendorizzate non sono equiparati a sorgente esaminato.','',
 'Gli import, canali, metodi nativi e stringhe API sono in [SOURCE_INDEX.json.gz](SOURCE_INDEX.json.gz). Sono relazioni statiche: non provano che ogni ramo sia eseguito nell’edizione User.','']
for repo,data in indexes.items():
 lines+=['## '+repo,'',f"File: {len(data['files'])}. Stati: "+', '.join(f'{k}: {v}' for k,v in sorted(Counter(f['review'] for f in data['files']).items()))+'.','',
 '| File | Ruolo/categoria | Lettura |','| --- | --- | --- |']
 for f in data['files']:
  scope='; '+','.join(f'{a}–{b}' for a,b in f.get('reviewed_ranges',[])) if f.get('reviewed_ranges') else ''
  lines.append('| `'+f['path'].replace('|','\\|')+'` | '+f['role']+' | '+f['review']+scope+' |')
 lines.append('')
(OUT/'FILE_INVENTORY.md').write_text('\n'.join(lines)+'\n')
print(json.dumps({'files':{k:len(v['files']) for k,v in indexes.items()},'review':{k:dict(Counter(f['review'] for f in v['files'])) for k,v in indexes.items()},'static_edges':len(edges),'output':str(OUT)}))
