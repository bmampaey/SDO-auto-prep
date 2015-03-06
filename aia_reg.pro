
PRO aia_reg, input1, input2, oindex, odata, input_mode=input_mode, $
  cutout=cutout, index_ref=index_ref, $
  infil=infil, nearest=nearest, interp=interp, cubic=cubic, $
  use_hdr_pnt=use_hdr_pnt, mpt_rec_num=mpt_rec_num, t_ref=t_ref, $
  no_uncomp_delete=no_uncomp_delete, $
  do_write_fits=do_write_fits, outdir=outdir, outfile=outfile, _extra=_extra, $
  verbose=verbose, run_time=run_time, progver=progver, prognam=prognam, $
  qstop=qstop

;+
; NAME:
;   AIA_REG
; PURPOSE:
;   Perform image registration (rotation, translation, scaling) of Level 1 AIA images, and update
;   the header information.
; CATEGORY:
;   Image alignment
; SAMPLE CALLS:
;   Inputing infil (in this case iindex and idata are returned with 
;   IDL> AIA_PREP, infil, [0,1,2], oindex, odata
;   Inputing iindex and idata: 
;   IDL> AIA_PREP, iindex, idata, oindex, odata
; INPUTS:
;   There are 2 basic usages for inputing the image and header data into AIA_PREP:
;   Case 1: References FITS file name on disk:
;           input1 - String array list of AIA FITS files
;           input2 - List of indices of FITS files to read 
;   Case 2. References index structure and data array in memory
;           (index, data already read from FITS file using, for example, READ_SDO.PRO):
;           input1 - index structure
;           input2 - data array
; OUTPUTS (OPTIONAL):
;   oindex - The updated index structure of the input image
;   odata - Registered output image.
; KEYWORDS:
;   USE_REF - If set then align all images to a reference index (if INDEX_REF is not supplied then
;             use the first index of the array as the reference index).
;             NOTE - If USE_REF is not set and if INDEX_REF is not supplied, then all images will
;             be aligned to sun center.
;   CUTOUT - Same effect as USE_REF above.
;   INDEX_REF - Reference index for alignment coordinates.
;   DO_WRITE_FITS - If set, write the registered image and updated header structure to disk
;   NEAREST - If set, use nearest neighbor interpolatipon
;   INTERP - If set, use bilinear interpolation
;   CUBIC - If set, use cubic convolution interpolation ith the specified value (in the range [-1,0]
;           as the interpolation parameter.  Cubic interpolation with this parameter equal -0.5
;           is the default.
; TODO:
;   Calculate NAXIS1, NAXIS2 as follows:
;     naxis1,2 = gt_tagval(oindex0, /znaxis1,2, missing=gt_tagval(oindex0, /naxis1,2))
; HISTORY:

; Start the clock running
t0 = systime(1)
t1 = t0	; Keep track of running time

if keyword_set(no_uncomp_delete) then uncomp_delete = 0 else uncomp_delete = 1

; Loop through images:

n_img = n_elements(input1)
for i=0, n_img-1 do begin  
  if input_mode eq 'file_list' then begin
    file0 = input1[i]
    if ( not exist(idata0) or (i ne 0) ) then $
      read_sdo, file0, iindex0, idata0, uncomp_delete=uncomp_delete, /mixed
  endif else begin
    if i eq 0 then begin
      iindex = input1
      idata = input2
    endif
    iindex0 = iindex[i]
    idata0 = idata[*,*,i]
  endelse
HELP, CUTOUT, USE_REF, INDEX_REF, USE_HDR_PNT
; If use_ref is set and index_ref not passed, then set INDEX_REF equal to first index structure,
;   and calculate wcs_ref to be used for all other images:
  if keyword_set(cutout) and not exist(wcs_ref) then begin
    if not exist(index_ref) then index_ref = iindex[0]
    wcs_ref = aia2wcsmin(index_ref, cutout=cutout, use_hdr_pnt=use_hdr_pnt, rec_num=mpt_rec_num, $
                         t_ref=t_ref, mpo_str=mpo_str, use_indmpo=use_indmpo, use_sswmp=use_sswmp, $
                         verbose=0, _extra=_extra)
  endif

  iwcs0 = aia2wcsmin(iindex0, cutout=cutout, use_hdr_pnt=use_hdr_pnt, rec_num=mpt_rec_num, $
                     t_ref=t_ref, mpo_str=mpo_str, use_indmpo=use_indmpo, use_sswmp=use_sswmp, $
                     verbose=0, _extra=_extra)

; Register single image using IDL function ROT.PRO:
  ssw_reg, iwcs0, idata0, owcs0, odata0, cutout=cutout, wcs_ref=wcs_ref, $
    scale_ref=scale_ref, roll_ref=roll_ref, crpix1_ref, crpix2_ref, $
    interp=interp, cubic=cubic, x_off=x_off, y_off=y_off, $
    _extra=_extra, qstop=qstop

; Update output header as needed:
  oindex0 = aia_fix_header(iindex0, owcs0, odata0, progver=progver)

; If output index array or data cube is requested (params 3 and 4) then update these arrays:
  if n_params() ge 3 then begin
    if i eq 0 then oindex = oindex0 else oindex = concat_struct(oindex, oindex0)
  endif
  if n_params() ge 4 then odata[0,0,i] = odata0

; Optionally write out new FITS file:
  if keyword_set(do_write_fits) then aia_write_fits, oindex0, odata0, outdir=outdir, outfile=outfile

endfor

if keyword_set(qstop) then stop,' Stopping on request.'

end
