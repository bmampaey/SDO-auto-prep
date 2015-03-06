
function aia_fix_header, iindex, owcs, odata, normalize=normalize, $
  progver=progver

; TODO: Handle case of differeing sizes of image and reference image
; Update header tag values as needed:

;+
; NAME:
;   AIA_FIX_HEADER
; PURPOSE:
;   Update headers for registered images
; CATEGORY:
; SAMPLE CALLS:
; INPUTS:
; OUTPUT:
;   Updated header structure
; KEYWORDS:
;   normalize - If set, and image is AIA, then document in HISTORY tag.
; TODO:
; HISTORY:
;   GLS - 2013-04-01 - If exposure normailzation has been done, then
;                      add this to history tag
;   Benjamin Mampaey - 2013-06-06 Corrected RMS and added percentile update
;-
print, "Using modified aia_fix_header"

oindex = iindex

instr_prefix = strupcase(strmid(oindex.instrume,0,3))

; Update LVL_NUM tag:
if tag_exist(oindex, 'LVL_NUM') then oindex.lvl_num = 1.5 else $
  oindex = add_tag(oindex, 1.5, 'LVL_NUM')

oindex.crota2 = owcs.crota2
oindex.cdelt1 = owcs.cdelt1
oindex.cdelt2 = owcs.cdelt2
oindex.crpix1 = owcs.crpix1
oindex.crpix2 = owcs.crpix2

; Update or add XCEN, YCEN tags:
xcen = comp_fits_cen(oindex.crpix1, oindex.cdelt1, oindex.naxis1, oindex.crval1)
if tag_exist(oindex, 'XCEN') then oindex.xcen = xcen else $
  oindex = add_tag(oindex, xcen, 'XCEN')
ycen = comp_fits_cen(oindex.crpix2, oindex.cdelt2, oindex.naxis2, oindex.crval2)
if tag_exist(oindex, 'YCEN') then oindex.ycen = ycen else $
  oindex = add_tag(oindex, ycen, 'YCEN')

; Update or add R_SUN tag, if RSUN_OBS tag exists:
if tag_exist(iindex, 'RSUN_OBS') then $
  if tag_exist(oindex, 'R_SUN') then $
    oindex.r_sun = iindex.rsun_obs/oindex.cdelt1 else $
      oindex = add_tag(oindex, iindex.rsun_obs/oindex.cdelt1, 'R_SUN')

; Update data statistics header tags:
if tag_exist(oindex, 'DATAMIN')  then oindex.datamin = min(odata)
if tag_exist(oindex, 'DATAMAX')  then oindex.datamax = max(odata)
if tag_exist(oindex, 'DATAMEDN') then oindex.datamedn = median(odata)

; If exposure normalization has been done, then update history for this:
if keyword_set(normalize) then begin
  new_hist_rec = 'Exposure nor0, malization preformed.'
  update_history, oindex, new_hist_rec
endif

moments_odata = moment(odata)
if tag_exist(oindex, 'DATAMEAN') then oindex.datamean = moments_odata[0]
if tag_exist(oindex, 'DATARMS')  then oindex.datarms  = sqrt(moments_odata[1])
if tag_exist(oindex, 'DATASKEW') then oindex.dataskew = moments_odata[2]
if tag_exist(oindex, 'DATAKURT') then oindex.datakurt = moments_odata[3]

; Compute percentiles
percentiles = percentile(odata, [0.01, 0.1, 0.25, 0.75, 0.90, 0.95, 0.98, 0.99], srt=1)
tags = ['DATAP01', 'DATAP10', 'DATAP25', 'DATAP75', 'DATAP90', 'DATAP95', 'DATAP98', 'DATAP99'] 
oindex_tags = TAG_NAMES(oindex)

FOR i=0, N_ELEMENTS(tags)-1 DO BEGIN 
	IF TAG_EXIST(oindex, tags[i]) THEN oindex.(WHERE(STRCMP(oindex_tags,tags[i]) EQ 1)) = percentiles[i]
ENDFOR

; Update or add miscellaneous header keyword records:

; Add miscellaneous HISTORY keyword records:

; Add AIA_PREP version number to history tag
update_history, oindex, version=progver, caller='AIA_PREP'

return, oindex

end


