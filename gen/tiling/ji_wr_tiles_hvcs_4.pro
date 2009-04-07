;+
; Project     : HINODE/EIS
;
; Name        : JI_WR_TILES
;
; Purpose     : Write image into specified number of subtiles
;
; Inputs      : IMAGE = 2-d byte image
;               NX, NY = # of tiles in X- and Y- directions
;
; Outputs     : Individual tile files 
;
; Keywords    : FORMAT = output image format [def = 'gif']
;               OUT_DIR = output directory [def = current]
;               STAMP = stamp for each tile filename [def = 'tile']
;               RED, GREEN, BLUE = image color table [def = currently loaded]
;               TRIMFMT = format for the zoom, x and y tile position numbers [def = '(i02)']
;
; Version     : Written 09-Nov-2007, Ireland (ADNET/GSFC)
;               JI_WR_TILES based on WR_TILES
;               Written 14-Feb-2007, Zarro (ADNET/GSFC)
;               Written 29 Feb 2008 Ireland - implemented hv
;                                             co-ordinate system
;
; Contact     : dzarro@solar.stanford.edu
;-


pro ji_wr_tiles_hvcs_4,image,nx,ny,_extra=extra,$
                     stamp=stamp,red=red,green=green,blue=blue,$
                     out_dir=out_dir,verbose=verbose,zoom=zoom,$
                     trimfmt=trimfmt,$
                     scale = scale, origin = origin,fitype = fitype,format=format

;-- def to current directory

verbose=keyword_set(verbose)
if is_blank(out_dir) then out_dir=curdir()
if ~write_dir(out_dir) then begin
 message,'no write access to '+out_dir,/cont
 return
endif

sz=size(image)
if (size(image,/type) ne 1) then begin
 message,'input image must be 3-D byte array',/cont
 return
endif
n1=sz[1] & n2=sz[2]

if ~is_number(nx) then begin
 message,'enter # of tiles',/cont
 return 
endif

if ~is_number(ny) then ny=nx
nx = nint(nx) > 1
ny = nint(ny) > 1

if is_blank(trimfmt) then trimfmt='(i+03)'
if is_blank(stamp) then stamp='tile'
if is_blank(format) then format='jpg'
if is_blank(zoom) then dzoom='' else dzoom='_'+zoom
ns1=nint(n1/nx) & ns2=nint(n2/ny)
if verbose then begin
 message,'processing '+trim(nx)+'x'+trim(ny)+' tiles',/cont
endif

;
; calculate all the tile upper left hand cornors in units of solar radii
; string format. See the wiki page
;
fmt = '(f07.3)'

xpos = dblarr(nx)
xpos_string = strarr(nx)
for j = 0,nx-1 do begin
   xpos(j) = (origin(0) + ns1*j*scale(0))
   if (xpos(j) lt 0.0d0) then begin
      pn = 'n'
   endif else begin
      pn = 'p'
   endelse
   xpos_string(j) = pn + trim(abs(xpos(j)),fmt)
endfor

ypos = dblarr(ny)
ypos_string = strarr(ny)
for j = 0,ny-1 do begin
   ypos(j) = (origin(1) - ns2*j*scale(1))
   if (ypos(j) lt 0.0d0) then begin
      pn = 'n'
   endif else begin
      pn = 'p'
   endelse
   ypos_string(j) = pn + trim(abs(ypos(j)),fmt)
endfor


;
; transparency
;
transparent = 255 + intarr(256)
transparent(0) = 0

;
; colors
;
;image_b = bytscl(image)
;if (format eq 'png') then begin
;   image_ct = color_quan( image, 1,r,g,b)
;   sz = size(image_ct,/dim)
;   transparent(image_ct(sz(0)/2,sz(1)/2)) = 0
;endif
;print,sz(0)/2,sz(1)/2
;modifyct,41,'this',r,g,b
;loadct,41
;plot_image,image_ct
;read,dummy

;
; tile
;
print,'!!! ',nx,ny
tlo = nx/2 -1

for j=0,ny-1 do begin
 for i=0,nx-1 do begin
  k=ny-j-1

  istart=i*ns1 < (n1-1)
  iend=((i+1)*ns1-1) < (n1-1)
  jstart=j*ns2 < (n2-1)
  jend=((j+1)*ns2-1) < (n2-1)

  tile_info = dzoom+'_'+trim(i-tlo-1,trimfmt)+'_'+trim(k-tlo-1,trimfmt)
;
; remove the fitype
;
;  tile_info = dzoom+'-'+trim(i,trimfmt)+'-'+trim(k,trimfmt) +'-'+fitype
  if ((i eq 0) and (k eq 0)) then begin
;
; remove the x and y position
;
;     filename = stamp + tile_info +'-'+xpos_string(i)+'-'+ypos_string(k)+'.'+format
;
; make an empty ".meta" file
;
     wrt_ascii,"",concat_dir(out_dir,stamp + dzoom + '.meta')
;  endif else begin
  endif
;     filename = stamp + tile_info + '.'+format
;  endelse
  filename = stamp + tile_info + '.'+format
;
; create the out_file name
;
  out_file=concat_dir(out_dir,filename)
;
; get the next tile
;
  thisTile =  image[istart:iend,jstart:jend]
;
; find out if the tile is empty or not
; if the tile has at least one non-zero pixel, write it.  otherwise, skip.
;
  nzero = n_elements(where(thisTile eq 0)) - long(iend+1-istart)* long(jend+1-jstart)
  if (nzero ne 0) then begin
     if (format eq 'png') then begin
        write_png,out_file, thisTile, red,green,blue,transparent = transparent 
        spawn,"optipng -q " + out_file
     endif else begin
        write_image,out_file,'JPEG',image[istart:iend,jstart:jend],$
                    red,green,blue,quality=75,/progressive,_extra=extra
     endelse
  endif
 endfor
endfor
  
return & end
