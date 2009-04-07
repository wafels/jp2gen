pro ji_write_trace, index, data, flat_fits=flat_fits, $
                    fitstype=fitstype, outfile=outfile, outdir=outdir, $
                    append=append, nocomment=nocomment, loud=loud,  quiet=quiet, $
                    prefix=prefix, extension=extension, incwave=incwave, incsize=incsize, $
                    soho=soho, summary=summary, planning=planning, file_type=file_type, $
                    comments=fcomments, history=history, temp=temp, $
                    gif=gif, tiff=tiff, jpeg=jpeg, nolabel=nolabel,seconds=seconds,$ 
                    hvoutdir = hvoutdir
;+
;   Name: write_trace
;
;   Purpose: write trace index/data to specified type of FITS or WWW file
;
;   Input Parameters:
;      index - trace structures (ex: from read_trace.pro)
;      data  - corresponding 2d/3d data array
;  
;   Keyword Parameters:
;      outfile - if supplied, use this/these file names (including outdir/path)
;      outdir  - if supplied, direct files to this directory (names derived)
;      fitstype - type of file; 0=>mxf (standard trace) 1=>2D FITS (1/image)
;      flat_fits - switch, if set, fitstype=1 (2D FITS, 1/image)
;      incwave, incsize, soho, prefix, extension - imply 2D fits
;          (keywords used to auto-dervive name via:  trace_struct2filename)
;      nocomment - switch, if set, dont add comment from this routine
;      soho & summary (synonyms) if set, FLAT w/soho name->$
;      planning - if set, FLAT w/soho name -> $TRACE_PRIVATE  (planning)
;      temp - if set, temporary file made in $HOME and copy to OUTFILE
;                     is done in background (for bad NFS links?)  
;      gif/tiff/jpeg - if set, write specified 'www' format 
;  
;   History:
;      6-March-1998 - S.L.Freeland
;      9-March-1998 - S.L.Freeland - call 'required_tags', add binary extension
;     12-March-1998 - S.L.Freeland - change default names 'trf' (flat)
;                                                         'trb' (binary)  
;     13-March-1998 - S.L.Freeland - completed 12-mar default name updates
;                                    [binary defaults include seconds]
;                                    add /PLANNING keyword 
;     
;     25-March-1998 - S.L.Freeland - file_type (pass to write_trace_bin)
;     26-March-1998 - S.L.Freeland - align keyword_db comments properly  
;                                    (index may differ from original)
;     18-May-1998   - S.L.Freeland - add /TEMP (offline copy)
;     26-May-1998   - S.L.Freeland - enable EXTENSION for non-FLAT (binary)
;                                    ( default = .mxf )
;      5-Jun-1998   - S.L.Freeland - add /gif,/tiff,/jpeg
;      8-Jun-1998   - S.L.Freeland - predefine a variable
;      9-Jun-1998   - S.L.Freeland - redirect WWW formats->SYNOP
;      8-Jul-1998   - S.L.Freeland - clarify internal outfile/outdir logic
;     15-Dec-1999   - S.L.Freeland - scalarized a potential logic problem
;     11-Mar-2002    - D.M. Zarro - added /seconds
;      8-jun-2005   - S.L. Freeland - eliminate header lines w/length ne 80
;
;  
;   Calling Sequence:
;      write_trace, index, data            ; write -> 3D fits (read_trace compat)  
;      write_trace, index, data ,/flat     ; write -> n2D flat FITS
;      write_trace, index, data, [,/gif,/tiff,/jpeg] ; n2D in WWW formats
;     
;   Calls:
;      data_chk, keyword_db, trace_struct2filename, time2file, fxhmake, $
;          writefits, box_message, required_tags, write_trace_bin, zbuff2file
;
;   Restrictions:
;      /SUMMARY and /PLANNING intended imply a shared output directory
;      /gif,/tiff,and, /jpeg -> imply FLAT and autoscale/coloring
;-

version='1.0'
pcomment='Written by write_trace, Version:' + version + '  ' + systime()
nocomment=keyword_set(nocomment)
case 1 of
  nocomment:
  data_chk(fcomments,/string):fcomments=[fcomments,pcomment]
  else: fcomments=pcomment
endcase

; ------------ WWW outputs (imply autoscaling/colors)
gif=keyword_set(gif) & tiff=keyword_set(tiff) & jpeg=keyword_set(jpeg)
wwwfmt=gif or tiff or jpeg

wext='.gif'
if wwwfmt then begin
   case 1 of 
      gif: wext='.gif'
      tiff:wext='.tiff'
      jpeg:wext='.jpg'
      else:
   endcase
endif   
; ----------------------------------------------

summary=keyword_set(summary)
planning=keyword_set(planning)
soho=keyword_set(soho) or planning or summary 

loud=keyword_set(loud)
named=data_chk(outfile,/string)
nooutdir=1-data_chk(outdir,/string)
nind=n_elements(index)                                 ; number of struct
nimg=data_chk(data,/nimages)                           ; number of images
if n_elements(fitstype) eq 0 then fitstype=0           ; default

case 1 of
   named: break_file,outfile,ll,outdir                                    ; fully specified
;   wwwfmt: outdir=concat_dir(concat_dir('$SYNOP_DATA', $
;	str_replace(wext,'.','')),time2file(index(0),/year2,/date_only))
   wwwfmt: outdir = hvoutdir
   planning and nooutdir:   outdir=get_logenv('TRACE_PRIVATE')
   summary and nooutdir:    outdir=get_logenv('TRACE_SUMMARY')
   data_chk(outdir,/string): outdir=outdir(0)
   nooutdir: outdir=curdir()
   else: box_message,'I thought it would never get here???'
endcase

if keyword_set(temp) then begin        ; offline copy
   finaldir=outdir(0)                  ; desired directory
   outdir=get_logenv('HOME')           ; use home temporarily
endif   
if outdir(0) eq '' then outdir = curdir()

if  not file_exist(outdir(0)) then begin
  box_message,['Requested output directory',outdir(0), 'does not exist'],/center
  return
end  

flat=keyword_set(flat_fits) or soho or planning or summary or wwwfmt     ; FLAT FITS

required='naxis1, naxis2, crpix1, cdelt1, date_obs'
if not required_tags(index,required,missing=missing) then begin
   box_message,'Required tags: ' + arr2str(missing) +' are missing from input structures...'
   return
endif   

if flat then begin
   if keyword_set(nolabel) then imglab=strarr(n_elements(index)) else $
;      imglab=get_infox(index, $
;	    'wave_len,naxis1,naxis2,sht_mdur,xcen,ycen',fmt_tim='vms',$
;             format='a5,    i5,     i5,    f8.3,  f7.1,f7.1')
      imglab=get_infox(index, $
	    'wave_len,naxis1,naxis2,xcen,ycen,cdelt1,cdelt2',$
             format='a5,    i5,     i5,  f7.1, f7.1, f7.1, f7.1')
   if not data_chk(prefix,/string) then prefix='trf'
   fext=(['.fits','.fts'])(soho)                     ; flat fits extensions
   exten=([fext,wext])(wwwfmt)                       ; WWW extentions
   if 1-named then $
       outfile=trace_struct2filename(index, outdir=outdir, $
		     incwave=incwave, incsize=incsize, soho=soho, $
		     prefix=prefix, extension=exten,seconds=seconds )
   ok=(nind eq nimg) and (nind eq n_elements(outfile))
   if not ok then begin
      box_message,'Mismatch between index, data, and outnames'
   endif else begin
      box_message,['Ready to write files:', outfile]
      keyword_db,xx,key,exes,comms,taglist=strlowcase(tag_names(index(0)))
;     ----- align dbase field comments with actual tags ---------
      tcomms=strarr(n_tags(index))
      tindex=tag_index(index,key)
      cgood=where(tindex ge 0,cgcnt)
      if cgcnt gt 0 then tcomms(tindex(cgood))=comms(cgood)
;     ------------------------------------------------------------
      for i=0,nind-1 do begin
         img=data(0:index(i).naxis1-1, 0:index(i).naxis2-1,i)  ; subarray?
         if wwwfmt then begin                                  ; WWW formats
;          ------------- WWW format via zbuff2file ---------------
            if (index(i).naxis1 gt 128) then begin
               dtemp=!d.name
               wdef,im=img,/zbuffer
               box_message,'Scaling, Despiking, and Coloring image...'
               sdata=trace_scale(index(i),img,/despike,/byte,/magrange) ; scale/despike
               trace_colors,index(i),r,g,b                              ; colors
               tv,sdata
;            xyouts,5,10,imglab(i),/device,size=.5+(index(i).naxis1/1024),color=220
               print,imglab(i)
;               zbuff2file,outfile(i) + '_' + imglab(i) + '.gif',r,g,b
               print,i,outfile(i)
               set_plot,dtemp   ; restore
; HV save files
               set_plot,'z'
               trace_colors,index(i),r,g,b                              ; colors
               tvlct,red,green,blue,/get                            
               hvs = {img:sdata, red:red, green:green, blue:blue}
               print,'Saving to ' +  outfile(i) + '_' + imglab(i) + '.sav'
               save,filename = outfile(i) + '_' + imglab(i) + '.sav', hvs
            endif
;           ------------------------------------------------
	endif else begin 
;          --------- standard FLAT FITS -------------------
	   newhead=struct2fitshead(index(i), $         ; TRACE struct->header
			  comments=' ' + tcomms)    ; include dbase descripts
	     fxhmake,newhead,img                         ; clean, add data info
             sslok=where(strlen(newhead) eq 80,okcnt)
             newhead=temporary(newhead(sslok))
             writefits, outfile(i), img, newhead        ; write FITS 2D
;          --------------------------------------------------
	 endelse
          if loud then box_message,'Wrote>> ' + outfile(i)
      endfor	
   endelse
endif  else begin
   case 1 of
      data_chk(extension,/string): exten='.'+str_replace(extension(0),'.','')
      keyword_set(extension): exten='.mxf'
      else: exten=''
   endcase
   case 1 of
      data_chk(outfile,/string):
      data_chk(prefix,/string): outfile=concat_dir(outdir,$
			        prefix+time2file(index(0),/sec))+exten
      else: outfile=concat_dir(outdir,'trb'+time2file(index(0),/sec))+exten
   endcase      
;  -------------- TRACE 'standard' (FITs w/binary extensions)
   write_trace_bin, index, data, outfile=outfile, append=append, file_type=file_type, $
		    comments=fcomments, history=history
endelse

if n_elements(finaldir) gt 0 then begin
   mvcmd='mv -f ' + outfile + ' ' + finaldir + ' &'
   box_message,['Backgrounding move command:',mvcmd]
   spawn,mvcmd
endif  

return
end
