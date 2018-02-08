module actuator_line_turbine
    
    use decomp_2d, only: mytype, nrank
    use actuator_line_model_utils
    use Airfoils
    use actuator_line_element
    use actuator_line_controller

    implicit none

type TurbineType 
    character(len=100) :: name
    character(len=100) :: blade_geom_file
    character(len=100) :: type
    integer :: ID
    integer :: NBlades
    real(mytype), dimension(3) :: RotN, origin ! Rotational vectors in the normal and perpendicular directions
    real(mytype) :: hub_tilt_angle, blade_cone_angle, yaw_angle 
    real(mytype) :: Rmax ! Reference radius, velocity, viscosity
    real(mytype) :: IRotor ! Inertia of the Rotor
    real(mytype) :: A ! Rotor area
    real(mytype) :: Torque, angularVel,deltaOmega,TSR,Uref ! Torque and rotation for the shaft
    real(mytype) :: AzimAngle=0.0
    real(mytype) :: dist_from_axis=0.0
    integer :: No_rev=0.0
    logical :: Is_constant_rotation_operated = .false. ! For a constant rotational velocity (in Revolutions Per Minute)
    logical :: Is_control_based = .false. ! For a active control-based rotational velocity computed at run time
    type(ControllerType) :: controller
    logical :: IsClockwise = .false.
    logical :: IsCounterClockwise = .false. 
    logical :: Has_Tower=.false.
    real(mytype) :: Towerheight, TowerOffset, TowerDrag, TowerLift, TowerStrouhal
    logical :: Has_BladeEndEffectModelling=.false.
    logical :: do_tip_correction=.false.
    logical :: do_root_correction=.false.
    logical :: EndEffectModel_is_Glauret=.false.
    logical :: EndEffectModel_is_Shen=.false.
    real(mytype) :: ShenCoeff_c1, ShenCoeff_c2
    type(ActuatorLineType), allocatable :: Blade(:)
    type(AirfoilType), allocatable :: AirfoilData(:)
    type(ActuatorLineType) :: tower
    real(mytype) :: CP  ! Power coefficient 
    real(mytype) :: CTR ! Torque coefficient 
    real(mytype) :: CFx ! Fx coefficient 
    real(mytype) :: CFy ! Fy coefficient 
    real(mytype) :: CFz ! Fz coefficient 
    real(mytype) :: CT  ! Thrust coefficient    
   
    ! Rotor Statistics
    real(mytype) :: CT_ave, CP_ave, Torque_ave

end type TurbineType
    

contains
    
    subroutine set_turbine_geometry(turbine)

    implicit none
    type(TurbineType),intent(inout) :: turbine
    real(mytype), allocatable :: rR(:),ctoR(:),pitch(:),thick(:)
    real(mytype) :: SVec(3), theta
    integer :: Nstations, iblade, Istation,ielem

    if (nrank==0) then        
    write(6,*) 'Turbine Name : ', adjustl(turbine%name)
    write(6,*) '-------------------------------------------------------------------'
    write(6,*) 'Number of Blades : ', turbine%Nblades
    write(6,*) 'Origin           : ', turbine%origin
    write(6,*) 'Axis of Rotation : ', turbine%RotN
    write(6,*) '-------------------------------------------------------------------'
    end if

    call read_actuatorline_geometry(turbine%blade_geom_file,turbine%Rmax,SVec,rR,ctoR,pitch,thick,Nstations)
    ! Make sure that the spanwise is [0 0 1]
    Svec = [0.0,0.0,1.0]
    ! Make sure that origin is [0,0,0] : we set everything to origin 0 and then translate the
    ! turbine to the actual origin(this is for simplicity)
    theta=2*pi/turbine%Nblades
    do iblade=1,turbine%Nblades
    call allocate_actuatorline(Turbine%blade(iblade),Nstations)
    turbine%blade(iblade)%name=trim(turbine%name)//'_blade_'//int2str(iblade)
    
    turbine%blade(iblade)%COR(1:3)=turbine%origin(1:3)
    turbine%blade(iblade)%L=turbine%Rmax
    turbine%blade(iblade)%NElem=Nstations-1 
    
    do istation=1,Nstations
    turbine%blade(iblade)%QCx(istation)=rR(istation)*turbine%Rmax*Svec(1)+turbine%blade(iblade)%COR(1)+turbine%dist_from_axis
    turbine%blade(iblade)%QCy(istation)=rR(istation)*turbine%Rmax*Svec(2)+turbine%blade(iblade)%COR(2)
    turbine%blade(iblade)%QCz(istation)=rR(istation)*turbine%Rmax*Svec(3)+turbine%blade(iblade)%COR(3)
    if(turbine%IsCounterClockwise) then
        turbine%blade(iblade)%tx(istation)=sin(pitch(istation)/180.0*pi)    
        turbine%blade(iblade)%ty(istation)=-cos(pitch(istation)/180.0*pi)    
        turbine%blade(iblade)%tz(istation)= 0.0
        turbine%blade(iblade)%C(istation)=ctoR(istation)*turbine%Rmax
        turbine%blade(iblade)%thick(istation)=thick(istation)
        turbine%blade(iblade)%pitch(istation)=pitch(istation)/180.0*pi
    elseif(turbine%IsClockwise) then
        turbine%blade(iblade)%tx(istation)=sin(pitch(istation)/180.0*pi)    
        turbine%blade(iblade)%ty(istation)=cos(pitch(istation)/180.0*pi)    
        turbine%blade(iblade)%tz(istation)= 0.0
        turbine%blade(iblade)%C(istation)=ctoR(istation)*turbine%Rmax
        turbine%blade(iblade)%thick(istation)=thick(istation)
        turbine%blade(iblade)%pitch(istation)=pitch(istation)/180.0*pi
        turbine%blade(iblade)%FlipN = .true.
    endif
    end do

    ! Rotate Blade 1 to forme the other blades 
    call rotate_actuatorline(turbine%blade(iblade),turbine%blade(iblade)%COR,turbine%RotN,(iblade-1)*theta)   
 
    call make_actuatorline_geometry(turbine%blade(iblade))

    ! Populate element Airfoils 
    call populate_blade_airfoils(turbine%blade(iblade)%NElem,turbine%Blade(iblade)%NAirfoilData,turbine%Blade(iblade)%EAirfoil,turbine%Blade(iblade)%AirfoilData,turbine%Blade(iblade)%ETtoC)
    
    turbine%Blade(iblade)%EAOA_LAST(:)=-666
    turbine%Blade(iblade)%Eepsilon(:)=0.0
    turbine%Blade(iblade)%EEndeffects_factor(:)=1.0
    
    ! Initialise Dynamic stall model
    do ielem=1,turbine%blade(iblade)%Nelem
    	if(turbine%blade(iblade)%do_Sheng_stall) then
    	call dystl_init(turbine%blade(iblade)%EDynstall(ielem),turbine%blade(iblade)%DynStallFile)
    	endif
    	if(turbine%blade(iblade)%do_lb_stall) then
	call dystl_init_lb(turbine%blade(iblade)%ELBstall(ielem),turbine%blade(iblade)%DynStallFile)
	endif
    end do 
    
    ! Apply Initial Yaw and Tilt for the turbine

    ! Rotate the turbine according to the tilt and yaw angle
    ! Yaw
    !call rotate_turbine(turbine,(/0.0d0,0.0d0,-1.0d0/),turbine%yaw_angle*pi/180.0d0)
    ! Tilt
    !call rotate_turbine(turbine,(/0.0d0,-1.0d0,0.0d0/),turbine%hub_tilt_angle*pi/180.0d0)

    end do

    !=========================================================
    ! Create a Tower
    !=========================================================
    if(turbine%has_Tower) then
    call read_actuatorline_geometry(turbine%tower%geom_file,turbine%Towerheight,SVec,rR,ctoR,pitch,thick,Nstations)
    ! Make sure that the spanwise is [0 0 1]
    Svec = (/0.0,1.0,0.0/)
    
    call allocate_actuatorline(Turbine%Tower,Nstations)
    turbine%tower%name=trim(turbine%name)//'_tower'
   
    turbine%Tower%COR=turbine%origin
    turbine%Tower%NElem=Nstations-1  
    
    do istation=1,Nstations
    turbine%Tower%QCx(istation)= turbine%Tower%COR(1) + turbine%TowerOffset  
    turbine%Tower%QCy(istation)= turbine%Tower%COR(2) - rR(istation)*turbine%Towerheight*Svec(2) 
    turbine%Tower%QCz(istation)= turbine%Tower%COR(3) 
    turbine%Tower%tx(istation)= 1.0    
    turbine%Tower%ty(istation)= 0.0    
    turbine%Tower%tz(istation)= 0.0
    turbine%Tower%C(istation)=ctoR(istation)*turbine%Towerheight
    turbine%Tower%thick(istation)=thick(istation)
    turbine%Tower%pitch(istation)=pitch(istation)/180.0*pi
    enddo
    
    call make_actuatorline_geometry(turbine%tower)
    
    turbine%tower%EAOA_LAST(:)=-666
    
    !Set the tower body velocity to zero
    turbine%tower%EVbx(:)=0.0
    turbine%tower%EVby(:)=0.0
    turbine%tower%EVbz(:)=0.0
    turbine%tower%EObx(:)=0.0
    turbine%tower%EOby(:)=0.0
    turbine%tower%EObz(:)=0.0
    turbine%tower%Eepsilon(:)=0.0
    endif
     
    !========================================================
    !Compute a number of global parameters for the turbine
    !========================================================
    turbine%angularVel=turbine%Uref*turbine%TSR/turbine%Rmax
    turbine%A=pi*turbine%Rmax**2
    
    turbine%IRotor=0. 
    do iblade=1,turbine%NBlades
    turbine%IRotor=turbine%IRotor+turbine%Blade(iblade)%Inertia
    enddo   
 
    call Compute_Turbine_RotVel(turbine)
    
    return

    end subroutine set_turbine_geometry
    
    subroutine compute_performance(turbine)

    implicit none
    type(TurbineType), intent(inout) :: turbine
    real(mytype) :: Torque_i,FX_i,FY_i,FZ_i,fx_tot,fy_tot,fz_tot,torq_tot 
    real(mytype) :: xe,ye,ze,o1,o2,o3,fx,fy,fz,trx,try,trz,te,ms,sxe,sye,sze
    real(mytype) :: rotx,roty,rotz
    integer :: iblade, ielem
    !write(*,*) 'In calculate_performance'

    RotX=turbine%RotN(1)
    RotY=turbine%RotN(2)
    RotZ=turbine%RotN(3)

    ! Compute Torque for each Blade
        Fx_tot=0.
        Fy_tot=0.
        Fz_tot=0.
        Torq_tot=0

        do iblade=1,turbine%Nblades
        Fx_i=0.
        Fy_i=0.
        Fz_i=0.
        Torque_i=0.

        do ielem=1,turbine%blade(iblade)%NElem
            
            xe=turbine%blade(iblade)%PEX(ielem)
            ye=turbine%blade(iblade)%PEY(ielem)
            ze=turbine%blade(iblade)%PEZ(ielem)
            o1=turbine%blade(iblade)%COR(1)
            o2=turbine%blade(iblade)%COR(2)
            o3=turbine%blade(iblade)%COR(3)
            fx=turbine%blade(iblade)%EFX(ielem)
            fy=turbine%blade(iblade)%EFY(ielem)
            fz=turbine%blade(iblade)%EFZ(ielem)
            ms=turbine%blade(iblade)%EMS(ielem)
            sxe=turbine%blade(iblade)%sex(ielem)
            sye=turbine%blade(iblade)%sey(ielem)
            sze=turbine%blade(iblade)%sez(ielem)

            call cross(xe-o1,ye-o2,ze-o3,fx,fy,fz,trx,try,trz)
            te=(trx*RotX+try*RotY+trz*RotZ)+ms*(sxe*RotX+sye*RotY+sze*RotZ)
            
            Fx_i=Fx_i+fx
            Fy_i=Fy_i+fy
            Fz_i=Fz_i+fz
            Torque_i=Torque_i+te
        end do
            
            Fx_tot=Fx_tot+Fx_i
            Fy_tot=Fy_tot+Fy_i
            Fz_tot=Fz_tot+Fz_i
            Torq_tot=torq_tot+Torque_i
    end do

    ! Assign torque and loads
    turbine%torque=Torq_tot
  
    ! Coefficients
    turbine%CFx=FX_tot/(0.5*turbine%A*turbine%Uref**2)
    turbine%CFy=FY_tot/(0.5*turbine%A*turbine%Uref**2)
    turbine%CFz=Fz_tot/(0.5*turbine%A*turbine%Uref**2)
    turbine%CT=sqrt(turbine%CFx**2.0+turbine%CFy**2.0+turbine%CFz**2.0)
    turbine%CTR=Torq_tot/(0.5*turbine%A*turbine%Rmax*turbine%Uref**2.0)
    turbine%CP= abs(turbine%CTR)*turbine%TSR
    
    ! PRINT ON SCREEN
    if(nrank==0) then
        write(6,*) 'Turbine :', turbine%name
        write(6,*) "Thrust Coefficient : ",  turbine%CT
        write(6,*) "Power  Coefficient : ",  turbine%CP
    endif

    end subroutine compute_performance
    
    subroutine Compute_Turbine_EndEffects(turbine)
    
    implicit none
    type(TurbineType),intent(inout) :: turbine
    integer :: iblade,ielem
    real(mytype) ::g1,alpha,pitch,F,Froot,Ftip,rtip, rroot, phi, axis_mag
    real(mytype) :: nxe,nye,nze,txe,tye,tze,sxe,sye,sze,u,v,w,ub,vb,wb,urdc,urdn,ur
    
    
    do iblade=1,turbine%Nblades
    ! Compute angle phi at the tip 
    do ielem=1,turbine%blade(iblade)%Nelem
        nxe=turbine%blade(iblade)%nEx(ielem)
        nye=turbine%blade(iblade)%nEy(ielem)
        nze=turbine%blade(iblade)%nEz(ielem)
        txe=turbine%blade(iblade)%tEx(ielem)
        tye=turbine%blade(iblade)%tEy(ielem)
        tze=turbine%blade(iblade)%tEz(ielem)
        sxe=turbine%blade(iblade)%sEx(ielem)
        sye=turbine%blade(iblade)%sEy(ielem)
        sze=turbine%blade(iblade)%sEz(ielem)
        u=turbine%blade(iblade)%EVx(ielem)
        v=turbine%blade(iblade)%EVy(ielem)
        w=turbine%blade(iblade)%EVz(ielem) 

        !=====================================
        ! Solid Body Rotation of the elements
        !=====================================
        ub=turbine%blade(iblade)%EVbx(ielem)
        vb=turbine%blade(iblade)%EVby(ielem)
        wb=turbine%blade(iblade)%EVbz(ielem)
        urdn=nxe*(u-ub)+nye*(v-vb)+nze*(w-wb)! Normal 
        urdc=txe*(u-ub)+tye*(v-vb)+tze*(w-wb)! Tangential
        ur=sqrt(urdn**2.0+urdc**2.0) 
        ! This is the dynamic angle of attack 
        axis_mag=sqrt(turbine%RotN(1)**2+turbine%RotN(2)**2+turbine%RotN(3)**2)
        phi=pi/2.0
        if (ur>10e-8) then
            if (turbine%IsCounterClockwise) then
        phi=asin(-(turbine%RotN(1)*(u-ub)+turbine%RotN(2)*(v-vb)+turbine%RotN(3)*(w-wb))/(axis_mag*ur))
            else if (turbine%IsClockwise) then
        phi=asin((turbine%RotN(1)*(u-ub)+turbine%RotN(2)*(v-vb)+turbine%RotN(3)*(w-wb))/(axis_mag*ur))
            endif
        endif
	
        rroot=turbine%blade(iblade)%ERdist(ielem)/turbine%Rmax
        rtip=(turbine%Rmax-turbine%blade(iblade)%ERdist(ielem))/turbine%Rmax
        
        ! Set them into 1.0 before the calculation
        Ftip=1.0
        Froot=1.0
        if (turbine%do_tip_correction) then 
            if (turbine%EndEffectModel_is_Glauret) then
                g1=1.0
            else if (turbine%EndEffectModel_is_Shen) then
                g1=exp(-turbine%ShenCoeff_c1*(turbine%NBlades*turbine%TSR-turbine%ShenCoeff_c2))+0.1
            else
                write(*,*) "Only Glauret and ShenEtAl2005 are available at the moment"
                stop
            endif
            if (abs(exp(-g1*turbine%Nblades/2.0*(1.0/rroot-1.0)/sin(phi)))>1) then
                write(*,*) "Something went wrong with the tip correction model -- phi =", phi
                Ftip=1.
            endif
            Ftip=2.0/pi*acos(exp(-g1*turbine%Nblades/2.0*(1.0/rroot-1.0)/sin(phi)))
        endif
        if (turbine%do_root_correction) then
            if (turbine%EndEffectModel_is_Glauret) then
                g1=1.0
            else if (turbine%EndEffectModel_is_Shen) then
                g1=exp(-turbine%ShenCoeff_c1*(turbine%NBlades*turbine%TSR-turbine%ShenCoeff_c2))+0.1
            else
                write(*,*) "Only Glauret and ShenEtAl2005 are available at the moment"
                stop
            endif
            Froot=2.0/pi*acos(exp(-g1*turbine%Nblades/2.0*(1.0/rtip-1.0)/sin(phi)))
        endif
            turbine%blade(iblade)%EEndeffects_factor(ielem)=Ftip*Froot
        end do
    end do

    end subroutine Compute_Turbine_EndEffects

    subroutine Compute_Turbine_RotVel(turbine)
    implicit none
    type(TurbineType),intent(inout) :: turbine
    integer :: iblade,ielem
    real(mytype) :: wRotX,wRotY,wRotZ,Rx,Ry,Rz,ublade,vblade,wblade
    
    !========================================================
    ! Compute Element local rotational velocity
    !========================================================
    wRotX=turbine%angularVel*turbine%RotN(1)
    wRotY=turbine%angularVel*turbine%RotN(2)
    wRotZ=turbine%angularVel*turbine%RotN(3)
    
    do iblade=1,turbine%NBlades
    do ielem=1,turbine%Blade(iblade)%Nelem
     
    Rx=-turbine%blade(iblade)%COR(1)+turbine%Blade(iblade)%PEx(ielem);
    Ry=-turbine%blade(iblade)%COR(2)+turbine%Blade(iblade)%PEy(ielem);
    Rz=-turbine%blade(iblade)%COR(3)+turbine%Blade(iblade)%PEz(ielem);

   ! ! Find the cross product Ublade = Omega x R
    call cross(wRotX,wRotY,wRotZ,Rx,Ry,Rz,ublade,vblade,wblade)
    
    turbine%Blade(iblade)%EVbx(ielem)=ublade
    turbine%Blade(iblade)%EVby(ielem)=vblade
    turbine%Blade(iblade)%EVbz(ielem)=wblade
    turbine%Blade(iblade)%EObx(ielem)=wRotX
    turbine%Blade(iblade)%EOby(ielem)=wRotY
    turbine%Blade(iblade)%EObz(ielem)=wRotZ
    
    end do
    end do
    
    end subroutine Compute_Turbine_RotVel

    subroutine rotate_turbine(turbine,Axis,theta)
    
    implicit none
    type(TurbineType),intent(inout) :: turbine
    real(mytype),intent(in) :: Axis(3)
    real(mytype),intent(in) :: theta
    real(mytype) :: nrx,nry,nrz,px,py,pz 
    integer :: j,ielem,i
    real(mytype) :: vrx,vry,vrz,VMag
    real(mytype) :: xtmp,ytmp,ztmp, txtmp, tytmp, tztmp
    ! Rotates data in blade arrays. Rotate element end geometry and recalculate element geometry.

        
    nrx=Axis(1)
    nry=Axis(2)
    nrz=Axis(3) 
    px =turbine%origin(1)
    py =turbine%origin(2)
    pz =turbine%origin(3)


    do j=1,turbine%NBlades
        do ielem=1,turbine%Blade(j)%Nelem+1
        ! Blade end locations (quarter chord). xBE(MaxSegEnds)
        xtmp=turbine%Blade(j)%QCx(ielem)
        ytmp=turbine%Blade(J)%QCy(ielem)
        ztmp=turbine%Blade(j)%QCz(ielem)
        
        Call QuatRot(xtmp,ytmp,ztmp,theta,nrx,nry,nrz,px,py,pz,vrx,vry,vrz)
        turbine%Blade(j)%QCx(ielem)=vrx                                       
        turbine%Blade(j)%QCy(ielem)=vry                                       
        turbine%Blade(j)%QCz(ielem)=vrz                                  
        
        txtmp=turbine%Blade(j)%tx(ielem)
        tytmp=turbine%Blade(j)%ty(ielem)
        tztmp=turbine%Blade(j)%tz(ielem)
        
        ! Tangent vectors (rotated assuming the origina as 0)
        Call QuatRot(txtmp,tytmp,tztmp,theta,nrx,nry,nrz,0.0d0,0.0d0,0.0d0,vrx,vry,vrz)
        VMag=sqrt(vrx**2+vry**2+vrz**2)
        turbine%Blade(j)%tx(ielem)=vrx/VMag                                      
        turbine%Blade(j)%ty(ielem)=vry/VMag                                  
        turbine%Blade(j)%tz(ielem)=vrz/VMag                                       
  
        end do
        
        call make_actuatorline_geometry(turbine%Blade(j))
    end do 
    
    end subroutine rotate_turbine  
    
end module actuator_line_turbine 
