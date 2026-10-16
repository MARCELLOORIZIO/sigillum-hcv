#!/usr/bin/env python3
"""SIGILLUM V4 external training: two distinct YOLO8 detectors.
Run in Colab/Linux or Windows with Python >=3.10.
Dependencies: pip install ultralytics py7zr pillow pyyaml
Does NOT change V2/V3/HFR or app production.
Never load third-party torch .pt files unless you trust the source.
"""
import argparse, collections, hashlib, json, shutil, subprocess, sys
from pathlib import Path
import yaml

IMG_EXT={'.jpg','.jpeg','.png','.webp'}
def sha(p):
 h=hashlib.sha256()
 with p.open('rb') as f:
  for chunk in iter(lambda:f.read(1024*1024),''):h.update(chunk)
 return h.hexdigest()
def unpack_mobile(first, output):
 import py7zr
 first=Path(first); output=Path(output); output.mkdir(parents=True,exist_ok=True)
 second=first.with_name(first.name[:-3]+'002')
 if not second.is_file():raise FileNotFoundError(f'Missing volume {second}')
 # py7zr handles multi-volumes through multivolumefile; it must receive .001.
 import multivolumefile
 with multivolumefile.open(str(first),'rb') as stream:
  with py7zr.SevenZipFile(stream,mode='r') as archive:archive.extractall(path=output)
 return output
def unpack_screen(p,out):
 import zipfile
 out.mkdir(parents=True,exist_ok=True)
 with zipfile.ZipFile(p) as z:
  for member in z.infolist():
   target=(out/member.filename).resolve()
   if not target.is_relative_to(out.resolve()):raise ValueError('Unsafe zip path')
   if member.file_size>500_000_000:raise ValueError('Unexpectedly huge single archive member')
  z.extractall(out)
 return out
def root_with_yaml(path):
 files=list(path.rglob('data.yaml'))+list(path.rglob('dataset.yaml'))
 if not files:raise FileNotFoundError(f'No YOLO data.yaml below {path}')
 for f in files:
  d=yaml.safe_load(f.read_text(encoding='utf8'))
  if isinstance(d,dict) and 'train' in d and 'names' in d:return f,d
 raise ValueError('No valid YOLO data config')
def check_dataset(root):
 f,d=root_with_yaml(root);base=f.parent
 classes=d['names']; nc=len(classes)
 result={'yaml':str(f),'classes':classes,'splits':{},'errors':[],'sha_to_paths':{}}
 for split in ('train','val','valid','test'):
  folder=base/split
  if not folder.exists():continue
  imgfolder=folder/'images'; labfolder=folder/'labels'
  if not imgfolder.exists():continue
  images=[x for x in imgfolder.rglob('*') if x.suffix.lower() in IMG_EXT]
  nbox=0; missing=0
  for p in images:
   label=labfolder/(p.stem+'.txt')
   if not label.exists():missing+=1;continue
   for line in label.read_text(encoding='utf8').splitlines():
    cells=line.split()
    if not cells:continue
    try:
     vals=[float(v) for v in cells]
     if len(vals)!=5 or not 0<=int(vals[0])<nc or any(not 0<=v<=1 for v in vals[1:]):raise ValueError()
    except Exception:result['errors'].append(str(label))
    nbox+=1
   k=sha(p);result['sha_to_paths'].setdefault(k,[]).append(str(p))
  result['splits'][split]={'images':len(images),'missing_labels':missing,'boxes':nbox}
 result['duplicates_sha256']={k:v for k,v in result['sha_to_paths'].items() if len(v)>1}
 result.pop('sha_to_paths')
 return f,result
def run_train(yaml_path,name,epochs,imgsz,batch,device,weights,out):
 from ultralytics import YOLO
 # Only trusted official base weights here; do not blindly deserialize dataset best.pt.
 model=YOLO(weights)
 res=model.train(data=str(yaml_path),epochs=epochs,imgsz=imgsz,batch=batch,device=device,
   project=str(out),name=name,seed=20261016,patience=15,exist_ok=True)
 final=out/name/'weights'/'best.pt'
 m=YOLO(str(final))
 # Native dataset test split, never train on it.
 try:metrics=m.val(data=str(yaml_path),split='test',imgsz=imgsz,device=device,plots=True)
 except Exception as e:metrics={'test_error':str(e)}
 return {'weights':str(final),'test_metrics':str(getattr(metrics,'results_dict',metrics))}
def main():
 ap=argparse.ArgumentParser()
 ap.add_argument('--mobile-first',required=True,help='Path to .7z.001; .002 must be alongside it')
 ap.add_argument('--screen-zip',required=True)
 ap.add_argument('--workdir',default='sigillum_v4_external_training')
 ap.add_argument('--epochs',type=int,default=60)
 ap.add_argument('--imgsz',type=int,default=640)
 ap.add_argument('--batch',type=int,default=16)
 ap.add_argument('--device',default='0')
 ap.add_argument('--weights',default='yolov8n.pt',help='Official Ultralytics weights')
 ap.add_argument('--inspect-only',action='store_true')
 args=ap.parse_args();w=Path(args.workdir).resolve();w.mkdir(parents=True,exist_ok=True)
 mobile=unpack_mobile(args.mobile_first,w/'mobile')
 screen=unpack_screen(Path(args.screen_zip),w/'screen')
 m_yaml,m=check_dataset(mobile);s_yaml,s=check_dataset(screen)
 report={'mobile':m,'screen':s,'warning':'Separate detectors: datasets have incompatible class taxonomies. Test native splits are never used for training.'}
 (w/'audit.json').write_text(json.dumps(report,indent=2,default=str))
 if m['errors'] or s['errors']:raise ValueError('Invalid YOLO coordinates: see audit.json')
 if args.inspect_only:
  print(json.dumps(report,indent=2));return
 report['training']=[
  run_train(m_yaml,'device_detector',args.epochs,args.imgsz,args.batch,args.device,args.weights,w/'runs'),
  run_train(s_yaml,'screen_detector',args.epochs,args.imgsz,args.batch,args.device,args.weights,w/'runs')]
 (w/'results.json').write_text(json.dumps(report,indent=2,default=str))
 print(json.dumps(report['training'],indent=2))
if __name__=='__main__':main()
