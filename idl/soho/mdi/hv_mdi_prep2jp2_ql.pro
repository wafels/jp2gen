;+
;HISTORY:
;	Written 1-Aug-96 by M.Morrison
;	 5-Aug-96 (MDM) - Added "disp_mdi_hr_fov" to disp_gen call
;	15-Aug-96 (MDM) - Scaled to gauss
;	19-Aug-96 (MDM) - Removed /5 logic (since mk_mdi_fits does it now)
;	21-Aug-96 (MDM) - Added call to mk_gif_mag_index
;	20-Jan-97 (MDM) - Changed outputut directory from
;			  /soho-archive/public/data/summary/mdi  (to)
;			  /soho-archive/public/data/summary/gif/YYMMDD
;	11-Jun-97 (MDM) - Modified to mask out the part of the data which
;			  is off the limb (but within the crop radius)
;	25-Jul-97 (MDM) - Added creation of the continuum GIF images
;			- Changed headers
;	10-Nov-97 (JFC) - Added a couple of lines to adjust the scaling of the
;			  conitnuum images to distinguish umbrae and penumbrae
;			  while we are entering the active cycle
;       12-Feb-99 (RIB) - Set the output directory to /md86/gif; changed the
;                         continuum color table to "3" (red-temperature)
;	04-Aug-99 (CED) - Changed output directory to $MDI_GIF_DIR
;      4-Jan-2000 (RIB) - Changed rebinning of continuum flatfield to match
;			  incoming fits file
;     26-Jan-2001 (RIB) - Changed flatfield file to flat_jan2001.fits
;     07-Jul-2003 (RIB) - Inserted check of CROT = 180 while SOHO is rolled
;     25-Mar-2005 (SEG) - Changing flat field file to flat_mar2005.fits, see
;			  flat_README for more details.
;     11-Jul-2007 (SEG) - Made some temporary changes due to network switch of
;			  SOHO-archive 09 July 2007.  Reading .fts files from
;			  /sas12/temp instead of archive.  Igram and doppl images
;			  on archive cannot be read from our machines for some reason.
;     16-Nov-2007 (SEG) - Undoing change above now that we are on soho-archive network
;			  and mditlm is doing the fits
;     10-Dec-2008 (SEG) - Changing the flat field fits file to flat_Dec2008.fits
;     19-Sep-2009 (SEG) - soho-arch is down, so saving fits on sas and making gifs from them
;     21-Sep-2009 (SEG) - Will always read fits files from mdisas (now saved to mdisas and soho-archive
;			  in go_fits_sci160k.pro) in the event that we cannot access soho-arch.
;     04-Dec-2009 (SEG) - Updating the flat_field file from
;                         flat_Dec2008.fits to flat_Dec2009.fits
;     08-Nov-2010 (JI)  - Image is rotated to take care of the new
;                         SOHO orientation.
;-

PRO HV_MDI_PREP2JP2_QL,details_file = details_file, copy2outgoing = copy2outgoing,output = output, date_start = date_start, date_end = date_end
;
; Program name
;
  progname = 'hv_mdi_prep2jp2_ql'
;
; use the default MDI file is no other one is specified
;
  if not(KEYWORD_SET(details_file)) then details_file = 'hvs_default_mdi'
  info = CALL_FUNCTION(details_file)
  nickname = info.nickname
;
; get general information
;
  ginfo = CALL_FUNCTION('hvs_gen')
;
; start the infinite loop
;
  timestart = systime(0)
  count = 0
  repeat begin
     t0 = systime(1)
     if count eq 0 then begin
        if not(keyword_set(date_start)) then begin
           sttim = anytim2ints(ut_time(), offset=-2*86400)
        endif else begin
           sttim = anytim2ints(date_start)
        endelse
     endif else begin
        sttim = anytim2ints(ut_time(), offset=-2*86400)
     endelse
;
;
;
     if not(keyword_set(date_end)) then begin
        exit_tf = 0
        entim = ut_time()
     endif else begin
        entim = anytim2ints(date_end, offset=86400)
        exit_tf = 1
     endelse

;; ------ temporyary fix for network switch problems where igram and doppl cannot be read from soho-archive 11-Jul-2007 (SEG) 
;;dir = '/soho-archive/private/data/planning/mdi' ;;--- 11-Jul-2007 (SEG)
;;dir = '/sas12/temp' ;------16-nov-2007 (SEG) On the new network, not saving fits to sas4/temp anymore 
		    ;------19-Sep-2009 (SEG) Added this back in since soho-arch down for maintainence, will keep so that
		    ;                        if soho-arch goes down, we will always have fits and gifs.  Soho-arch will get
		    ;                        fits according to go_fits_sci160k.pro
     dir = info.quicklook_directory
;; outdir2 = '/soho-archive/public/data/summary/gif' -- 11-Jul-2007 (SEG) 
;;outdir2 = '/sas12/temp' -- 11-Jul-2007 (SEG)

;ff_file = '/mdisw/dbase/cal/files/flat_005.fits'
;ff_file = '/mdisw/dbase/cal/files/flat_jan2001.fits'
;ff_file = '/mdisw/dbase/cal/files/flat_mar2005.fits'
;ff_file = '/mdisw/dbase/cal/files/flat_Dec2008.fits'
;ff_file = '/mdisw/dbase/cal/files/flat_Dec2009.fits'
;
; Flatfield file
;
     ff_file = info.flatfield_file

     if (n_elements(types) eq 0) then types = ['maglc_fd', 'igram_fd']
     for itype=0,n_elements(types)-1 do begin
        type = types(itype)
        ff = file_list(dir, '*' + type + '*', file=file)
        timarr = anytim2ints(fid2ex( strmid(file, 16, 11)))
        ss = sel_timrange(timarr, sttim, entim, /between)
        if (ss(0) ne -1) then begin
           output = strarr(n_elements(ss))
;           int_aaa = fltarr(n_elements(ss),2)
;           int_bbb = fltarr(n_elements(ss),2)
           for i=0,n_elements(ss)-1 do begin
;
; keep the file names
;
              error_report = ''
              infil = ff(ss(i))
              break_file, infil, dsk_log, dir00, filnam
              img = rfits(infil, h=h)
              hd = FITSHEAD2STRUCT(h)
;
; Add in required Helioviewer rags
;
              hd = add_tag(hd,hd.radius,'R_SUN')
              error_report = error_report + 'R_SUN tag inserted and value copied from FITS value "RADIUS"; tag added by '+progname +'. '

              error_report = error_report + 'DATE_OBS tag modified '+progname +' as follows: took FITS value "REFTIME" and manipulated it to conform to CCSDS format.  The original value of DATE_OBS is ='+hd.DATE_OBS + '. '
              hd.date_obs = (ji_txtrep(ji_txtrep(hd.reftime,'/','-'),' ','T')) + 'Z'


              case type of
                 'maglc_fd': begin
                    ss2 = circle_mask(img, sxpar(h,'CRPIX1'), sxpar(h,'CRPIX2'), 'GE', sxpar(h,'RADIUS') )
                    if (ss2(0) ne -1) then img(ss2)=-3000
                    dpc_str = string(sxpar(h, 'dpc'), format='(z8.8)')
                    img = img*0.352*8. ;data is 8 m/sec
                    smin = -250.
                    smax = 250.
                    axis1 = 'Gauss'
                    fmt='(f7.2)'
;		outdir = getenv('MDI_GIF_DIR')+'/mag'
                    outdir = '~/Desktop/test'
                    tit = 'SOHO/MDI Magnetogram'
                    loadct = 0
;                    img = bytscl(img,smin,smax,top=!d.n_colors-1)
;                    int_aaa[i,*] = minmax(img)
;                    print,'*',int_aaa[i,*]
                    img = bytscl(img,smin,smax,top=254)
                    hd = add_tag(hd,'FD_Magnetogram','DPC_OBSR')
                    error_report = error_report + 'DPC_OBSR tag inserted and value set by '+progname +'.'
                    measurement = info.details[1].measurement
                 end
                 'igram_fd': begin
                    naxis=sxpar(h,'naxis1')
                    xyz=[sxpar(h,'crpix1'), sxpar(h,'crpix2'), sxpar(h,'radius')]
                    img=(img/10.)^2.
                    if (n_elements(ff_img) eq 0) then begin
                       ff_img = rfits(ff_file)
                       ff_img = rebin(ff_img, naxis, naxis)
                    end
                    img = img * ff_img
                    darklimb_correct, img, img3, limbxyr=xyz, lambda=6767
                    img = temporary(img3)
;                    int_bbb[i,*] = minmax(img)
                    smin = 5000.
                    smax = 13000.
                    gamma=1.8	
                                ;img(*,505:*) = 0	;mask out garbage at the top
                    axis1 = ''
                    fmt='(f7.1)'
;		outdir = getenv('MDI_GIF_DIR')+'/igram'
                    outdir = '~/Desktop/test'
                    tit = 'SOHO/MDI Continuum'
                    loadct = 3
;                    img = bytscl(img,smin,smax,top=!d.n_colors-1)
                    img = bytscl(img,smin,smax,top=254)
                    hd = add_tag(hd,'FD_Continuum','DPC_OBSR')
                    error_report = error_report + 'DPC_OBSR tag inserted and value set by '+progname +'.'
                    measurement = info.details[0].measurement
                    
                 end
              endcase
;
; De-rotate if necessary
;
              sohoRotAngle = sxpar(h, 'CROT')
              if (sohoRotAngle eq 180) then begin
                 img = rotate(img,2)
                 ;window,3
                 ;plot_image,img, title = 'most recent 180 degree orientation ' + hd.DATE_OBS
              endif else begin
                 if (sohoRotAngle ne 0) then begin
                    pivotCenter = [hd.crpix1,hd.crpix2]
                    ;window,0
                    ;plot_image,img,title = hd.DATE_OBS
                    img = rot(img,sohoRotAngle,1.0,pivotCenter[0],pivotCenter[1],/pivot,/interp,missing = 0.0)                 ; IDL says the images are rotated clockwise
                    ;window,1
                    ;plot_image,img,title = 'rotated '+ hd.DATE_OBS
                    ;read, dummy
                    ;hd = add_tag(hd,hd.crpix1,'hv_crpix1_original')       ; keep a store of the original sun centre
                    ;hd = add_tag(hd,hd.crpix2,'hv_crpix2_original')
                    ;rotatedSolarCentre = HV_CALC_ROT_CENTRE( [hd.crpix1,hd.crpix2], sohoRotAngle, [511.5, 511.5] ) ; calculate the new solar centre given that we have performed a clockwise rotation on the original image
                    ;hd.crpix1 = rotatedSolarCentre[0]
                    ;hd.crpix2 = rotatedSolarCentre[1]
                 endif else begin
                    ;window,2
                    ;plot_image,img, title = 'most recent zero degree orientation ' + hd.DATE_OBS
                 endelse
              endelse
              hd = add_tag(hd,sohoRotAngle,'hv_rotation')
;
; Add in error report
;
              hd = add_tag(hd,error_report,'HV_ERROR_REPORT')
;
; Add in a notfication that this is based on quicklook data
;
              hd = add_tag(hd,'TRUE','HV_QUICKLOOK')
;
; Get the times
;           
              aaa = HV_PARSE_CCSDS(hd.date_obs)
;
; Get the outfile name
;
              zzz = strsplit(hd.outfil,path_sep(),/extract)
;
; Construct the HVS
;
              hvsi = {dir:dir,$
                      fitsname:ff[ss[i]],$
                      header:hd,$
                      comment:error_report,$
                      measurement:measurement,$
                      yy:aaa.yy, mm:aaa.mm, dd:aaa.dd, hh:aaa.hh, mmm:aaa.mmm, ss:aaa.ss, milli:aaa.milli,$
                      details:info}
              hvs = {hvsi:hvsi,img:img}
;
; Call the JP2 writing
;
              HV_MAKE_JP2,hvs,jp2_filename = jp2_filename, already_written = already_written
;
;              HV_WRITE_LIST_JP2,hvs,jp2_filename = jp2_filename, already_written = already_written
;              if not(already_written) then begin
;                 log_comment = 'read ' + ff(ss(i)) + $
;                               ' ; ' +HV_JP2GEN_CURRENT(/verbose) + $
;                               ' ; at ' + systime(0)
;                 HV_LOG_WRITE,hvs.hvsi,log_comment + ' ; wrote ' + jp2_filename
;              endif else begin
;                 jp2_filename = ginfo.already_written
;              endelse
              output[i] = jp2_filename
           endfor ; end of file loop
           nawind = where(output eq ginfo.already_written,naw)
           nnew = n_elements(output)- naw
;
; Report time
;
           HV_REPORT_WRITE_TIME,progname,t0,nnew,report=report
;
; Copy to outgoing
;
           if keyword_set(copy2outgoing) then begin
              HV_COPY2OUTGOING,output
           endif

        endif ; check for at least one file
     endfor ; check for all types
;
; Wait for 15 minutes
;
     count = count + 1
     HV_REPEAT_MESSAGE,progname,count,timestart,/web,more = report
     HV_WAIT,progname,15,/minutes,/web

  endrep until 1 eq exit_tf ; infinite repeat permissible

end
