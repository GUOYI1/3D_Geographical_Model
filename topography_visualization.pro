  ;+
  ; :GY
  ; Visualization of Geographical Model
  ; implemented in 2015-8
  ;-
pro Topography_Visualization_event,event
  WIDGET_CONTROL,event.id,get_uvalue=func
  WIDGET_CONTROL,event.top,get_uvalue=sState
  Case func of
    ; Openfile a tif file
    'openfile':begin
;      data=FILE_BASENAME(DIALOG_PICKFILE())       
;      demo_getdata, NewImage, FILENAME=data, /TWO_DIM
;      help,Newimage
;      z=NewImage[*,*,8]data=dialog_pickfile()
      if(data=DIALOG_PICKFILE(FILTER=['*.tif']))then begin
        z=READ_TIFF(data,GEOTIFF=geodata)
        sState.geo_tiff=ptr_new(geodata)


        val_idx=where(z ne 65535,COMPLEMENT=nonval_idx)
        minvalue=min(z[val_idx])
        maxvalue=max(z[val_idx])
        z[nonval_idx]=10
   
        z=smooth(z, 3, /EDGE_TRUNCATE)
        siz = SIZE(z)
        mod1=siz[1] mod 2
        mod2=siz[2] mod 2
        if(mod1 eq 0&&mod2 eq 0) then begin
          z=Congrid(z, siz[1]/2, siz[2]/2)
        endif else if(mod1 ne 0) then begin
          z=Congrid(z, (siz[1]+1)/2, siz[2]/2)
        endif else if(mod2 ne 0) then begin
          z=Congrid(z, siz[1]/2, (siz[2]+1)/2)
        endif
        
        sState.dem_data=ptr_new(z)

        help,z
        sz = SIZE(z)
        maxx = sz[1] - 1
        maxy = sz[2] - 1
        maxz = MAX(z, MIN=minz)
        sState.Z_MAX=maxz+0.1

        xs = [0+sState.bias, 1.0/maxx]
        ys = [0+sState.bias, 1.0/maxy]
        minz2 = minz - 1
        maxz2 = maxz + 1
        sState.slope_x_factor=1
        sState.slope_y_factor=1
        sState.slope_z_factor=10
        zs = [-minz2/(maxz2-minz2)+sState.bias, 1.0/(maxz2-minz2)]/sState.slope_z_factor
        sState.flag=1
        sState.osurface=ptr_new(obj_new('idlgrsurface',style=2,shading=1,color=[230, 230, 230],bottom=[64, 192, 128]))
        sState.obasemodel=ptr_new(obj_new('idlgrmodel'))
        sState.otextimage.setproperty,data=bytscl(rebin(z,sz[1]*4,sz[2]*4))
        *(sState.osurface).setproperty,DATAZ=*(sState.dem_data),TEXTURE_MAP=sState.otextimage, XCOORD_CONV=xs,YCOORD_CONV=ys,ZCOORD_CONV=zs
        
        *(sState.obasemodel).add,*(sState.osurface)
        sState.orotatemodel.add,*(sState.obasemodel)
        sState.owindow.draw,sState.oview
        widget_control,sState.X_stretch,/SENSITIVE
        widget_control,sState.X_shrink,/SENSITIVE
        widget_control,sState.Y_stretch,/SENSITIVE
        widget_control,sState.Y_shrink,/SENSITIVE
        widget_control,sState.Z_stretch,/SENSITIVE
        widget_control,sState.Z_shrink,/SENSITIVE       
        widget_control,event.top,SET_UVALUE=sState
        
      end
     end
     
      ;texture
    'texture':begin  
      filters = ['*.jpg', '*.tif', '*.png','*.shp'] 
      texture_file=DIALOG_PICKFILE(/READ,FILTER = filters,/MULTIPLE_FILES)
           
      readfile=FILE_BASENAME(texture_file)
      n1=SIZE(readfile)
      j=0
      while(sState.txt_file[j] ne '') do j++
      if(j gt 99) then void=dialog_message("The number of the items in the list is out of the range",/information,$
        title='Info')
      for i=0,n1[1]-1 do begin
        sState.txt_file[j]=readfile[i]
        sState.txt_file_path[j]=texture_file[i]
        j++
      endfor
 
      WIDGET_CONTROL,sState.imagelist,SET_VALUE=sState.txt_file[0:j-1]
      widget_control,event.top,SET_UVALUE=sState
    end
    ;clear
    'clear':begin 
      *(sState.obasemodel).cleanup
      sState.owindow.draw,sState.oview
      sState.flag=0
      sState.flag_file=INTARR(100)
      sState.shape_ptr=make_array(100,/PTR)
      widget_control,sState.X_stretch,/SENSITIVE
      widget_control,sState.X_shrink,/SENSITIVE
      widget_control,sState.Y_stretch,/SENSITIVE
      widget_control,sState.Y_shrink,/SENSITIVE
      widget_control,sState.Z_stretch,/SENSITIVE
      widget_control,sState.Z_shrink,/SENSITIVE     
      widget_control,event.top,SET_UVALUE=sState
    end
      ;imagelist
    'imagelist':begin
      index=widget_info(sState.imagelist,/LIST_SELECT)
      if(sState.flag_file[index] eq 0) then begin
        WIDGET_CONTROL,sState.texture_menu1,/SENSITIVE
        WIDGET_CONTROL,sState.texture_menu2,SENSITIVE=0
      endif else begin
        WIDGET_CONTROL,sState.texture_menu1,SENSITIVE=0
        WIDGET_CONTROL,sState.texture_menu2,/SENSITIVE
      endelse
      if(TAG_NAMES(event,/STRUCTURE_NAME) eq 'WIDGET_CONTEXT') then begin     
        if(index ne -1) then WIDGET_DISPLAYCONTEXTMENU,event.id,event.x,event.y,sState.texture_menu
      endif

    end
      ;display_texture   
    'display_texture': begin
      if(sState.flag eq 0) then void=DIALOG_MESSAGE('Missing Object',/error,title='display error') $
      else begin
        index=widget_info(sState.imagelist,/LIST_SELECT)
        sState.flag_file[index]=1
        num=N_ELEMENTS(index)
        if(num eq 1) then begin
          texture=sState.txt_file[index]
          texture_type=STRMID(texture,STRPOS(texture,'.',/REVERSE_SEARCH)+1,STRLEN(texture)-STRPOS(texture,'.',/REVERSE_SEARCH)-1)
         ;only .shp file can be shown as texture
          if(texture_type eq 'shp') then begin
            *(sState.osurface).getproperty,data=dem_temp,XCOORD_CONV=xs,YCOORD_CONV=ys,ZCOORD_CONV=zs
            shapefile=sState.txt_file_path[index]
            oshp=Obj_New('IDLffShape',shapefile)
            oshape_model=OBJ_NEW('IDLgrModel',uvalue=index)
            oshp->getproperty,n_entities=n_ent,Attribute_info=attr_info,n_attributes=n_attr,Entity_type=ent_type
            ;Point
            if(ent_type eq 1||ent_type eq 11) then begin   
              FOR i=0,n_ent-1 do begin
                ent=oshp->getentity(i) ;ith object in the file
                bounds=ent.bounds
                v_center=[bounds[0],bounds[1],bounds[2]]
                v1=[0.0,0.0]
                v2=[0.0,0.0]
                v3=[0.0,0.0]
                startpoint_x=(*(sState.geo_tiff)).MODELTIEPOINTTAG[3]-(*(sState.geo_tiff)).MODELTIEPOINTTAG[0]*(*(sState.geo_tiff)).MODELPIXELSCALETAG[0]
                startpoint_y=(*(sState.geo_tiff)).MODELTIEPOINTTAG[4]-(*(sState.geo_tiff)).MODELTIEPOINTTAG[1]*(*(sState.geo_tiff)).MODELPIXELSCALETAG[1]
                v_center[0]=uint((v_center[0]-startpoint_x)/(*(sState.geo_tiff)).MODELPIXELSCALETAG[0]/2)
                v_center[1]=uint((startpoint_y-v_center[1])/(*(sState.geo_tiff)).MODELPIXELSCALETAG[1]/2)
                ;draw a triangle
                v1[0]=v_center[0]
                v1[1]=v_center[1]+6.0
                v2[0]=v_center[0]-6.0*sqrt(3.0)/2.0
                v2[1]=v_center[1]-3.0
                v3[0]=v_center[0]+6.0*sqrt(3.0)/2.0
                v3[1]=v_center[1]-3.0
                oshape_point=obj_new('IDLgrpolygon',data=[[v1[0],v1[1],sState.Z_MAX],[v2[0],v2[1],sState.Z_MAX],[v3[0],v3[1],sState.Z_MAX]],$
                XCOORD_CONV=xs,YCOORD_CONV=ys,ZCOORD_CONV=zs,COLOR=[255,0,0],REJECT=1)
                oshape_model.add,oshape_point
              endfor
              sState.shape_ptr[index]=ptr_new(oshape_model)
              *(sState.obasemodel).add,oshape_model
              sState.owindow.draw,sState.oview
            endif
            ;Polylines
            if(ent_type eq 3||ent_type eq 13) then begin              
              FOR i=0,n_ent-1 do begin 
                ent=oshp->getentity(i) ;ith object in the file
                n_vert=ent.n_vertices ;the number of vertices
                vert=*(ent.vertices) ;the collection of vertices
                startpoint_x=(*(sState.geo_tiff)).MODELTIEPOINTTAG[3]-(*(sState.geo_tiff)).MODELTIEPOINTTAG[0]*(*(sState.geo_tiff)).MODELPIXELSCALETAG[0]
                startpoint_y=(*(sState.geo_tiff)).MODELTIEPOINTTAG[4]-(*(sState.geo_tiff)).MODELTIEPOINTTAG[1]*(*(sState.geo_tiff)).MODELPIXELSCALETAG[1]
                 for n=0, n_vert-1 do begin
                  vert[0,n]=uint((vert[0,n]-startpoint_x)/(*(sState.geo_tiff)).MODELPIXELSCALETAG[0]/2)
                  vert[1,n]=uint((startpoint_y-vert[1,n])/(*(sState.geo_tiff)).MODELPIXELSCALETAG[1]/2)
                  vert[2,n]=dem_temp[2,vert[0,n],vert[1,n]]
                endfor
                oshape_road=obj_new('IDLgrpolyline',data=vert,XCOORD_CONV=xs,YCOORD_CONV=ys,ZCOORD_CONV=zs,$
                  COLOR=[255,255,255],THICK=3)
                oshape_model.add,oshape_road
               endfor
               sState.shape_ptr[index]=ptr_new(oshape_model)
               *(sState.obasemodel).add,oshape_model
               sState.owindow.draw,sState.oview
            endif 
          ;images
          endif else begin
            texture_data=READ_IMAGE(sState.txt_file_path[index])
            txt_size=size(texture_data)
            if(txt_size[0] eq 2) then begin
              sState.otextimage.getproperty,palette=color_table
              color_table.loadct,0
              sState.otextimage.setproperty,palette=color_table
            endif
            sState.otextimage.setproperty,data=texture_data
            *(sState.osurface).setproperty,TEXTURE_MAP=sState.otextimage
            sState.owindow.draw,sState.oview
          endelse
  
        endif
      endelse
      widget_control,sState.X_stretch,SENSITIVE=0
      widget_control,sState.X_shrink,SENSITIVE=0
      widget_control,sState.Y_stretch,SENSITIVE=0
      widget_control,sState.Y_shrink,SENSITIVE=0
      widget_control,sState.Z_stretch,SENSITIVE=0
      widget_control,sState.Z_shrink,SENSITIVE=0
      widget_control,event.top,SET_UVALUE=sState
    end
    
    ;hind texture
    'hind_texture':begin
      index=widget_info(sState.imagelist,/LIST_SELECT)
      num=widget_info(sState.imagelist,/LIST_NUMBER)
      sState.flag_file[index]=0
      texture=sState.txt_file[index]
      texture_type=STRMID(texture,STRPOS(texture,'.',/REVERSE_SEARCH)+1,STRLEN(texture)-STRPOS(texture,'.',/REVERSE_SEARCH)-1)
      if(texture_type eq 'shp') then begin
        *(sState.obasemodel).remove,*(sState.shape_ptr[index])
        OBJ_DESTROY,*(sState.shape_ptr[index])
        sState.owindow.draw,sState.oview
      endif else begin   
        sState.otextimage.getproperty,palette=color_table
        color_table.loadct,13
        sState.otextimage.setproperty,palette=color_table
        sz = SIZE(*(sState.dem_data))
        sState.otextimage.setproperty,data=bytscl(rebin(*(sState.dem_data),sz[1]*4,sz[2]*4))
        *(sState.osurface).setproperty,TEXTURE_MAP=sState.otextimage
        sState.owindow.draw,sState.oview       
      endelse
      
      FOR i=0,num do begin
        if(sState.flag_file[i] eq 1) then break
      ENDFOR
      if(i eq num+1) then begin 
        widget_control,sState.X_stretch,/SENSITIVE
        widget_control,sState.X_shrink,/SENSITIVE
        widget_control,sState.Y_stretch,/SENSITIVE
        widget_control,sState.Y_shrink,/SENSITIVE
        widget_control,sState.Z_stretch,/SENSITIVE
        widget_control,sState.Z_shrink,/SENSITIVE
       endif
      widget_control,event.top,SET_UVALUE=sState
    end
    
    ;delete texture
    'delete_texture' : begin 

      index=widget_info(sState.imagelist,/LIST_SELECT)
      num=widget_info(sState.imagelist,/LIST_NUMBER)
      if(sState.flag_file[index] eq 1) then begin        
        texture=sState.txt_file[index]
        texture_type=STRMID(texture,STRPOS(texture,'.',/REVERSE_SEARCH)+1,STRLEN(texture)-STRPOS(texture,'.',/REVERSE_SEARCH)-1)
        if(texture_type eq 'shp') then begin
          *(sState.obasemodel).remove,*(sState.shape_ptr[index])
          OBJ_DESTROY,*(sState.shape_ptr[index])
          sState.owindow.draw,sState.oview
        endif else begin
          sState.otextimage.getproperty,palette=color_table
          color_table.loadct,13
          sState.otextimage.setproperty,palette=color_table
          sz = SIZE(*(sState.dem_data))
          sState.otextimage.setproperty,data=bytscl(rebin(*(sState.dem_data),sz[1]*4,sz[2]*4))
          *(sState.osurface).setproperty,TEXTURE_MAP=sState.otextimage
          sState.owindow.draw,sState.oview
        endelse
      endif
      
      for i=index,num-1 do begin
        if(i eq num-1) then begin
          sState.txt_file[i]=''
          sState.txt_file_path[i]=''
          sState.flag_file[i]=0
          sState.shape_ptr[i]=ptr_new()
        end else begin
           sState.txt_file[i]=sState.txt_file[i+1] 
           sState.txt_file_path[i]=sState.txt_file_path[i+1]
           sState.flag_file[i]=sState.txt_flag[i+1]
           sState.shape_ptr[i]=sState.shape_ptr[i+1]
        end
      endfor
      FOR i=0,num do begin
        if(sState.flag_file[i] eq 1) then break
      ENDFOR
      if(i eq num+1) then begin
        widget_control,sState.X_stretch,/SENSITIVE
        widget_control,sState.X_shrink,/SENSITIVE
        widget_control,sState.Y_stretch,/SENSITIVE
        widget_control,sState.Y_shrink,/SENSITIVE
        widget_control,sState.Z_stretch,/SENSITIVE
        widget_control,sState.Z_shrink,/SENSITIVE
      endif
      WIDGET_CONTROL,sState.imagelist,SET_VALUE=sState.txt_file[0:num-1]   
      WIDGET_CONTROL,event.top,SET_UVALUE=sState 
    end
    
    ;draw the model
    'draw':begin
      if(sState.orotatemodel.update(event)) then $
        sState.owindow.draw,sState.oview
      if(event.type eq 7) then begin
        if(event.clicks eq -1) then begin
          scalesize=0.95
          sState.oscalemodel.scale,scalesize,scalesize,scalesize
          sState.owindow.draw,sState.oview
        endif else if(event.clicks eq 1) then begin
          scalesize=1.05
          sState.oscalemodel.scale,scalesize,scalesize,scalesize
          sState.owindow.draw,sState.oview
        endif
      endif
    end
    
   ;X stretch
   'X_stretch':begin
      if(sState.slope_x_factor gt 0) then begin
        *(sState.osurface).getproperty,XCOORD_CONV=temp_xs
        temp_xs=temp_xs*sState.slope_x_factor/(sState.slope_x_factor-0.1)
        sState.slope_x_factor-=0.1
        *(sState.osurface).setproperty,XCOORD_CONV=temp_xs
        sState.owindow.draw,sState.oview
      endif    
           
    end
    
    ;X shrink
    'X_shrink':begin
      if(sState.slope_x_factor gt 0) then begin
        *(sState.osurface).getproperty,XCOORD_CONV=temp_xs
        temp_xs=temp_xs*sState.slope_x_factor/(sState.slope_x_factor+0.2)
        sState.slope_x_factor+=0.2
        *(sState.osurface).setproperty,XCOORD_CONV=temp_xs
        sState.owindow.draw,sState.oview
      endif

    end
    
    ;Y stretch
    'Y_stretch':begin
      if(sState.slope_y_factor gt 0) then begin
        *(sState.osurface).getproperty,YCOORD_CONV=temp_ys
        temp_ys=temp_ys*sState.slope_y_factor/(sState.slope_y_factor-0.2)
        sState.slope_y_factor-=0.2
        *(sState.osurface).setproperty,YCOORD_CONV=temp_ys
        sState.owindow.draw,sState.oview
      endif

    end
    
    ;Y shrink
    'Y_shrink':begin
      if(sState.slope_y_factor gt 0) then begin
        *(sState.osurface).getproperty,YCOORD_CONV=temp_ys
        temp_ys=temp_ys*sState.slope_y_factor/(sState.slope_y_factor+0.2)
        sState.slope_y_factor+=0.2
        *(sState.osurface).setproperty,YCOORD_CONV=temp_ys
        sState.owindow.draw,sState.oview
      endif

    end
    
    ;Z stretch
    'Z_stretch':begin
      if(sState.slope_z_factor gt 0) then begin
        *(sState.osurface).getproperty,ZCOORD_CONV=temp_zs
        temp_zs=temp_zs*sState.slope_z_factor/(sState.slope_z_factor-0.4)
        sState.Z_MAX=sState.Z_MAX*sState.slope_z_factor/(sState.slope_z_factor-0.4)
        sState.slope_z_factor-=0.4   
        *(sState.osurface).setproperty,ZCOORD_CONV=temp_zs
        sState.owindow.draw,sState.oview
      endif    
           
    end
    
    ;Z shrink
    'Z_shrink':begin
      if(sState.slope_z_factor gt 0) then begin
        *(sState.osurface).getproperty,ZCOORD_CONV=temp_zs
        temp_zs=temp_zs*sState.slope_z_factor/(sState.slope_z_factor+0.4)
        sState.Z_MAX=sState.Z_MAX*sState.slope_z_factor/(sState.slope_z_factor+0.4)
        sState.slope_z_factor+=0.4
        *(sState.osurface).setproperty,ZCOORD_CONV=temp_zs
        sState.owindow.draw,sState.oview
      endif
      
    end
    
    'close':begin
      WIDGET_CONTROL,event.top,/destroy
    end

  endcase
end
pro Topography_Visualization
  ; main function
  device,get_screen_size=scr
  xdim=scr[0]*0.6
  ydim=xdim*0.8

  bias = -0.5
  aspect = float(xdim)/float(ydim)
  if (aspect > 1) then $
    myview = [(1.0-aspect)/2.0+bias, 0.0+bias, aspect, 1.0] $
  else $
    myview = [0.0+bias, (1.0-(1.0/aspect))/2.0+bias, 1.0, (1.0/aspect)]
  slope_x_factor=1
  slope_y_factor=1
  slope_z_factor=10
  ;
  txt_file=make_array(100,/STRING)
  txt_file_path=make_array(100,/STRING)
  flag_file=INTARR(100)
  shape_ptr=make_array(100,/PTR)
  flag=0
  geo_tiff=ptr_new()
  dem_data=ptr_new()
  Z_MAX=0
  ;UI
  tlb=widget_base(mbar=mainmenu,title='Topography_Visualizaiton',/row)
  menu1=widget_button(mainmenu,value='File')
  menu2=widget_button(mainmenu,value='View')
  menu11=widget_button(menu1,value='Open TIF file',uvalue='openfile')
  menu12=widget_button(menu1,value='Close',/SEPARATOR,uvalue='close')
  menu21=widget_button(menu2,value='Load Texture',uvalue='texture')
  menu22=widget_button(menu2,value='Clear view',uvalue='clear')
  operate=widget_base(tlb,/column)
;  texture_list=widget_tree(operate,uvalue='texture_list',SCR_XSIZE=200,SCR_YSIZE=300,/CONTEXT_EVENTS)
  imagelist=widget_list(operate,uvalue='imagelist',SCR_XSIZE=200,SCR_YSIZE=300,/CONTEXT_EVENTS)
  texture_menu=WIDGET_BASE(imagelist,/CONTEXT_MENU)
  texture_menu1=WIDGET_BUTTON(texture_menu,value='display',uvalue='display_texture')
  texture_menu2=WIDGET_BUTTON(texture_menu,value='hind',uvalue='hind_texture')
  texture_menu3=WIDGET_BUTTON(texture_menu,value='delete',uvalue='delete_texture')
  
  toolbar_x=widget_base(operate,/row)
  X_stretch=widget_button(toolbar_x,value='X_stretch',uvalue='X_stretch',SENSITIVE=0)
  X_shrink=widget_button(toolbar_x,value='X_shrink',uvalue='X_shrink',SENSITIVE=0)
  toolbar_y=widget_base(operate,/row)
  Y_stretch=widget_button(toolbar_y,value='Y_stretch',uvalue='Y_stretch',SENSITIVE=0)
  Y_shrink=widget_button(toolbar_y,value='Y_shrink',uvalue='Y_shrink',SENSITIVE=0)
  toolbar_z=widget_base(operate,/row)
  Z_stretch=widget_button(toolbar_z,value='Z_stretch',uvalue='Z_stretch',SENSITIVE=0)
  Z_shrink=widget_button(toolbar_z,value='Z_shrink',uvalue='Z_shrink',SENSITIVE=0)
  
  hydro_data=widget_base(operate)
  wdraw=widget_draw(tlb,xsize=xdim,ysize=ydim,graphics_level=2,/BUTTON_EVENTS,/RETAIN,/EXPOSE_EVENTS,$
    /MOTION_EVENTS,/WHEEL_EVENTS,uvalue='draw',/SENSITIVE)
  widget_control,tlb,/realize
  ; view model
  oview=obj_new('idlgrview',projection=1,eye=3,zclip=[1.5,-1.5],view=myview,color=[0,0,0])
  oscalemodel=obj_new('idlgrmodel')
  orotatemodel=obj_new('idlexrotator',[xdim/2,ydim/2],ydim/2)
  ; IDL image
  opalette=obj_new('idlgrpalette')
  opalette.loadct,13
  otextimage=obj_new('idlgrimage',palette=opalette)
  ; surface model
  osurface=ptr_new()
;  osurface=obj_new('idlgrsurface',style=2,shading=1,color=[230, 230, 230],bottom=[64, 192, 128])
  ; base view model
  obasemodel=ptr_new()
  oscalemodel.add,orotatemodel
  oview.add,oscalemodel

  orotatemodel.Rotate,[1,0,0],-90
  orotatemodel.Rotate,[0,1,0],30
  orotatemodel.Rotate,[1,0,0],30

  scalesize=0.75
  oscalemodel.Scale, scalesize, scalesize, scalesize
  
  widget_control,wdraw,get_value=owindow
  
  sState={bias:bias,$
    slope_x_factor:slope_x_factor,$
    slope_y_factor:slope_y_factor,$
    slope_z_factor:slope_z_factor,$
    txt_file:txt_file,$
    txt_file_path:txt_file_path,$
    flag_file:flag_file,$
    shape_ptr:shape_ptr,$
    geo_tiff:geo_tiff,$
    dem_data:dem_data,$
    Z_MAX:Z_MAX,$
    flag:flag,$
    texture_menu:texture_menu,$
    texture_menu1:texture_menu1,$
    texture_menu2:texture_menu2,$
    texture_menu3:texture_menu3,$
    imagelist:imagelist,$
    X_stretch:X_stretch,$
    X_shrink:X_shrink,$
    Y_stretch:Y_stretch,$
    Y_shrink:Y_shrink,$
    Z_stretch:Z_stretch,$
    Z_shrink:Z_shrink,$
    owindow:owindow,$
    oview:oview,$
    wdraw:wdraw,$
    obasemodel:obasemodel,$
    orotatemodel:orotatemodel,$
    oscalemodel:oscalemodel,$
    opalette:opalette,$
    otextimage:otextimage,$
    osurface:osurface}
  widget_control,tlb,set_uvalue=sState
  owindow.draw,oview
  xmanager,'Topography_Visualization',tlb
  ptr_free,shape_ptr
end