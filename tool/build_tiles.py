"""Generate the editable pixel-vector terrain used by the mobile skin."""
from pathlib import Path
import random
root=Path(__file__).resolve().parents[1]/'assets/images/tiles'
def svg(parts):return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32" shape-rendering="crispEdges">'+''.join(parts)+'</svg>'
def rect(x,y,w,h,c):return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{c}"/>'
palettes={
 'dusk':('#797366','#b2a58c','#403f37','#32362f','#45493d'),
 'stone':('#5c7377','#90a5a4','#30474d','#293c40','#344e50'),
 'ice':('#6b7589','#afb7c9','#3e4658','#303643','#424a5c'),
 'lava':('#645147','#aa8670','#342b27','#332a25','#4b3830'),
 'abyss':('#655b78','#a699ba','#383046','#282635','#383448'),
}
for n,(base,light,dark,floor,detail) in palettes.items():
 r=random.Random(n)
 parts=[rect(0,0,32,32,dark)]
 for row in range(4):
  for col in range(-1,3):
   x=col*16+(8 if row%2 else 0);y=row*8
   parts += [rect(x+1,y+1,14,6,base),rect(x+1,y+1,14,1,light),rect(x+1,y+2,1,4,light),rect(x+3,y+4,3,1,dark)]
 if n=='dusk':parts += [rect(0,0,5,2,'#626747'),rect(2,2,2,2,'#4a553a')]
 (root/f'wall_{n}.svg').write_text(svg(parts))
 parts=[rect(0,0,32,32,floor),rect(0,0,32,1,detail),rect(0,0,1,32,detail),rect(31,0,1,32,'#22272a'),rect(0,31,32,1,'#22272a')]
 for _ in range(9):parts.append(rect(r.randint(2,29),r.randint(2,29),r.choice([1,2]),1,detail))
 (root/f'floor_{"forge" if n=="lava" else n}.svg').write_text(svg(parts))
(root/'floor_lava.svg').write_text(svg([rect(0,0,32,32,'#3a2420'),'<path d="M0 8H6V12H12V20H20V24H32M22 0V7H18V12H12M4 32V26H12V20" fill="none" stroke="#e37332" stroke-width="3"/>','<path d="M0 8H6V12H12V20H20V24H32" fill="none" stroke="#ffd080"/>']))
(root/'floor_void.svg').write_text(svg([rect(0,0,32,32,'#141322'),rect(0,0,32,1,'#49405e'),rect(6,9,2,2,'#605173'),rect(23,20,1,1,'#a797c6')]))
