import math, json, sys
from PIL import Image, ImageDraw
def bez(p0,p1,p2,p3,n=40): return [((1-t)**3*p0[0]+3*(1-t)**2*t*p1[0]+3*(1-t)*t*t*p2[0]+t**3*p3[0],(1-t)**3*p0[1]+3*(1-t)**2*t*p1[1]+3*(1-t)*t*t*p2[1]+t**3*p3[1]) for t in [i/n for i in range(n+1)]]
# Splash mark in a unit square (y down). Each segment: cubic (p0 implied), shared with the Swift Path.
SEGS = [
  # start at the surface, left edge
  ("M", (0.07, 0.56)),
  # bowl: bottom half of a circle, left -> bottom -> right
  ("C", (0.07, 0.79), (0.25, 0.95), (0.47, 0.95)),
  ("C", (0.70, 0.95), (0.88, 0.78), (0.88, 0.55)),
  # right side climbs into the wave
  ("C", (0.88, 0.36), (0.80, 0.20), (0.67, 0.12)),
  # crest curls over to the left
  ("C", (0.60, 0.075), (0.50, 0.085), (0.50, 0.15)),
  ("C", (0.50, 0.215), (0.585, 0.225), (0.635, 0.245)),
  # inner side of the wave falls back down to the surface
  ("C", (0.70, 0.29), (0.70, 0.38), (0.66, 0.44)),
  ("C", (0.63, 0.49), (0.61, 0.52), (0.60, 0.54)),
  # surface back to the left
  ("C", (0.45, 0.50), (0.20, 0.50), (0.07, 0.56)),
]
SURFACE = (0.335, 0.535, 0.27, 0.045)   # ellipse cx, cy, rx, ry (lighter tone)
DROPS = [(0.585, 0.305, 0.03), (0.605, 0.415, 0.036)]  # floating droplets beside the wave
def outline():
    pts=[]; cur=None
    for s in SEGS:
        if s[0]=="M": cur=s[1]; pts.append(cur)
        else: pts+=bez(cur,s[1],s[2],s[3])[1:]; cur=s[3]
    return pts
def render(size, bg, fg, fg2, hole, pad=0.16, out="splash.png", rounded=False):
    SS=4; S=size*SS
    im=Image.new("RGBA",(S,S),bg if bg else (0,0,0,0)); d=ImageDraw.Draw(im)
    k=S*(1-2*pad); o=S*pad
    T=lambda p:(o+p[0]*k, o+p[1]*k)
    d.polygon([T(p) for p in outline()], fill=fg)
    cx,cy,rx,ry=SURFACE; d.ellipse([T((cx-rx,cy-ry)), T((cx+rx,cy+ry))], fill=fg2)
    for x,y,r in DROPS: d.ellipse([T((x-r,y-r)),T((x+r,y+r))], fill=fg)
    im=im.resize((size,size),Image.LANCZOS)
    if rounded:
        m=Image.new("L",(size,size),0); ImageDraw.Draw(m).rounded_rectangle([0,0,size-1,size-1],radius=int(size*0.225),fill=255); im.putalpha(m)
    im.save(out); return im
if __name__=="__main__":
    B=(139,21,56,255); W=(255,255,255,255); OW=(240,217,196,255)
    a=render(512,B,W,OW,B,out="splash_icon.png",rounded=True)
    b=render(512,(255,255,255,255),B,(216,40,90,255),(255,255,255,255),out="splash_mark.png")
    S=Image.new("RGB",(1060,520),"white"); S.paste(a,(0,0),a); S.paste(b,(540,0)); S.save("splash_sheet.png")
