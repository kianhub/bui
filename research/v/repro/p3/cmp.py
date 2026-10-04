import numpy as np, sys
w,h=int(sys.argv[1]),int(sys.argv[2])
a=np.fromfile(sys.argv[3],dtype=np.uint8).reshape(h,w,4)[:,:,:3].astype(int)
b=np.fromfile(sys.argv[4],dtype=np.uint8).reshape(h,w,4)[:,:,:3].astype(int)
d=np.abs(a-b).max(axis=2)
print(f"pixels {w*h} exact {np.mean(d==0)*100:.2f}% <=1 {np.mean(d<=1)*100:.2f}% <=2 {np.mean(d<=2)*100:.3f}% <=8 {np.mean(d<=8)*100:.3f}% max {d.max()} mean {np.abs(a-b).mean():.4f}")
ys,xs=np.nonzero(d>8)
if len(ys): print("worst samples (x,y,blit,p3):", [(int(xs[i]),int(ys[i]),a[ys[i],xs[i]].tolist(),b[ys[i],xs[i]].tolist()) for i in range(0,len(ys),max(1,len(ys)//6))][:6])
if len(sys.argv)>5:
    from PIL import Image
    Image.fromarray(np.concatenate([a,b],axis=1)[:,:,::-1].astype(np.uint8)).save(sys.argv[5])
