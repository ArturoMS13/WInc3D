
module actuator_line_source

    use actuator_line_model_utils
    use actuator_line_model

    implicit none
    real,save :: constant_epsilon, meshFactor, thicknessFactor,chordFactor
    real, allocatable :: Sx(:),Sy(:),Sz(:),Sc(:),Se(:),Sh(:),Su(:),Sv(:),Sw(:),SFX(:),SFY(:),SFZ(:)
    real, allocatable :: Snx(:),Sny(:),Snz(:),Stx(:),Sty(:),Stz(:),Ssx(:),Ssy(:),Ssz(:),Ssegm(:) 
    real, allocatable :: A(:,:)
    logical, allocatable :: inside_the_domain(:)
    integer :: NSource
    logical, save :: rbf_interpolation=.false.
    logical, save :: pointwise_interpolation=.false.
    logical, save :: anisotropic_projection=.false. 
    logical, save :: has_mesh_based_epsilon=.false.
    logical, save :: has_constant_epsilon=.false.
    public get_locations, get_forces, set_vel, initialize_actuator_source
    
contains
    
    subroutine initialize_actuator_source

    implicit none
    integer :: counter,itur,iblade,ielem,ial
    
    write(*,*) 'Entering initialize_source_terms'  
    !> Get Source term parameters
    !if (have_option("/turbine_models/actuator_line_model/source_terms_interpolation/radial_basis_function_interpolation")) then
    !    rbf_interpolation=.true.
    !    has_constant_epsilon=.true.
    !    call get_option("/turbine_models/actuator_line_model/source_terms_interpolation/radial_basis_function_interpolation/constant_epsilon",constant_epsilon)
    !else if (have_option("/turbine_models/actuator_line_model/source_terms_interpolation/pointwise_interpolation")) then
    !    pointwise_interpolation=.true.
    !    if (have_option("/turbine_models/actuator_line_model/source_terms_interpolation/pointwise_interpolation/constant_epsilon")) then
    !        has_constant_epsilon=.true.
    !        call get_option("/turbine_models/actuator_line_model/source_terms_interpolation/pointwise_interpolation/constant_epsilon",constant_epsilon)
    !    else if (have_option("/turbine_models/actuator_line_model/source_terms_interpolation/pointwise_interpolation/mesh_based_epsilon")) then
    !        has_mesh_based_epsilon=.true.
    !        call get_option("/turbine_models/actuator_line_model/source_terms_interpolation/pointwise_interpolation/mesh_based_epsilon/meshFactor",meshFactor,default=2.00)
    !        call get_option("/turbine_models/actuator_line_model/source_terms_interpolation/pointwise_interpolation/mesh_based_epsilon/chordFactor",chordFactor,default=0.25)
    !    else 
    !        write(*,*) "Source term parameters not set"
    !        stop
    !    end if
    !    if(have_option("/turbine_models/actuator_line_model/source_terms_interpolation/pointwise_interpolation/mesh_based_epsilon/anisotropic_source")) then
    !        anisotropic_projection=.true.
    !    endif
    !else
    !    write(*,*) "Source term parameters not set"
    !    stop
    !end if

    counter=0
    if (Ntur>0) then
        do itur=1,Ntur
            
            ! Blades
            do iblade=1,Turbine(itur)%Nblades
                do ielem=1,Turbine(itur)%Blade(iblade)%Nelem
                counter=counter+1
                end do
            end do
            
            ! Tower 
            if(turbine(itur)%has_tower) then
                do ielem=1,Turbine(itur)%Tower%Nelem
                counter=counter+1
                end do
            endif
        
        end do
    endif
    
    if (Nal>0) then
        do ial=1,Nal
            do ielem=1,actuatorline(ial)%NElem
                counter=counter+1
            end do
        end do
    endif
    NSource=counter
    allocate(Sx(NSource),Sy(NSource),Sz(NSource),Sc(Nsource),Su(NSource),Sv(NSource),Sw(NSource),Se(NSource),Sh(NSource),Sfx(NSource),Sfy(NSource),Sfz(NSource))
    allocate(Snx(NSource),Sny(NSource),Snz(NSource),Stx(Nsource),Sty(NSource),Stz(NSource),Ssx(NSource),Ssy(NSource),Ssz(NSource),Ssegm(NSource))
    allocate(A(NSource,NSource))
    allocate(inside_the_domain(NSource))
    write(*,*) 'exiting initialize_source_terms'

    end subroutine initialize_actuator_source

    subroutine get_locations
    
    implicit none
    integer :: counter,itur,iblade,ielem,ial

    counter=0
    if (Ntur>0) then
        do itur=1,Ntur
            do iblade=1,Turbine(itur)%Nblades
                do ielem=1,Turbine(itur)%Blade(iblade)%Nelem
                counter=counter+1
                Sx(counter)=Turbine(itur)%Blade(iblade)%PEX(ielem)
                Sy(counter)=Turbine(itur)%Blade(iblade)%PEY(ielem)
                Sz(counter)=Turbine(itur)%Blade(iblade)%PEZ(ielem)
                Sc(counter)=Turbine(itur)%Blade(iblade)%EC(ielem)
                Snx(counter)=Turbine(itur)%Blade(iblade)%nEx(ielem)
                Sny(counter)=Turbine(itur)%Blade(iblade)%nEy(ielem)
                Snz(counter)=Turbine(itur)%Blade(iblade)%nEz(ielem)
                Stx(counter)=Turbine(itur)%Blade(iblade)%tEx(ielem)
                Sty(counter)=Turbine(itur)%Blade(iblade)%tEy(ielem)
                Stz(counter)=Turbine(itur)%Blade(iblade)%tEz(ielem)
                Ssx(counter)=Turbine(itur)%Blade(iblade)%sEx(ielem)
                Ssy(counter)=Turbine(itur)%Blade(iblade)%sEy(ielem)
                Ssz(counter)=Turbine(itur)%Blade(iblade)%sEz(ielem)
                Ssegm(counter)=Turbine(itur)%Blade(iblade)%EDS(ielem)

                end do
            end do
                !Tower 
                if(turbine(itur)%has_tower) then
                do ielem=1,Turbine(itur)%Tower%Nelem
                counter=counter+1
                Sx(counter)=Turbine(itur)%Tower%PEX(ielem)
                Sy(counter)=Turbine(itur)%Tower%PEY(ielem)
                Sz(counter)=Turbine(itur)%Tower%PEZ(ielem)
                Sc(counter)=Turbine(itur)%Tower%EC(ielem) 
                Snx(counter)=Turbine(itur)%Tower%nEx(ielem)
                Sny(counter)=Turbine(itur)%Tower%nEy(ielem)
                Snz(counter)=Turbine(itur)%Tower%nEz(ielem)
                Stx(counter)=Turbine(itur)%Tower%tEx(ielem)
                Sty(counter)=Turbine(itur)%Tower%tEy(ielem)
                Stz(counter)=Turbine(itur)%Tower%tEz(ielem)
                Ssx(counter)=Turbine(itur)%Tower%sEx(ielem)
                Ssy(counter)=Turbine(itur)%Tower%sEy(ielem)
                Ssz(counter)=Turbine(itur)%Tower%sEz(ielem)
                Ssegm(counter)=Turbine(itur)%Tower%EDS(ielem)
                end do
                endif 
        end do
    endif
    
    if (Nal>0) then
        do ial=1,Nal
            do ielem=1,actuatorline(ial)%NElem
                counter=counter+1
                Sx(counter)=actuatorline(ial)%PEX(ielem)
                Sy(counter)=actuatorline(ial)%PEY(ielem)
                Sz(counter)=actuatorline(ial)%PEZ(ielem)
                Sc(counter)=actuatorline(ial)%EC(ielem)
                Snx(counter)=actuatorline(ial)%nEx(ielem)
                Sny(counter)=actuatorline(ial)%nEy(ielem)
                Snz(counter)=actuatorline(ial)%nEz(ielem)
                Stx(counter)=actuatorline(ial)%tEx(ielem)
                Sty(counter)=actuatorline(ial)%tEy(ielem)
                Stz(counter)=actuatorline(ial)%tEz(ielem)
                Ssx(counter)=actuatorline(ial)%sEx(ielem)
                Ssy(counter)=actuatorline(ial)%sEy(ielem)
                Ssz(counter)=actuatorline(ial)%sEz(ielem)
                Ssegm(counter)=actuatorline(ial)%EDS(ielem)
            end do
        end do
    endif
  
    end subroutine get_locations
    
    subroutine set_vel
    
    implicit none
    integer :: counter,itur,iblade,ielem,ial
    
    write(*,*) 'Entering set_vel'
    counter=0
    if (Ntur>0) then
        do itur=1,Ntur
            ! Blades
            do iblade=1,Turbine(itur)%Nblades
                do ielem=1,Turbine(itur)%Blade(iblade)%Nelem
                counter=counter+1
                Turbine(itur)%Blade(iblade)%EVX(ielem)=Su(counter)
                Turbine(itur)%Blade(iblade)%EVY(ielem)=Sv(counter)
                Turbine(itur)%Blade(iblade)%EVZ(ielem)=Sw(counter)
                Turbine(itur)%Blade(iblade)%Eepsilon(ielem)=Se(counter) 
                end do
            end do
            ! Tower
            if(turbine(itur)%has_tower) then
                do ielem=1,Turbine(itur)%Tower%Nelem
                counter=counter+1
                Turbine(itur)%Tower%EVX(ielem)=Su(counter)
                Turbine(itur)%Tower%EVY(ielem)=Sv(counter)
                Turbine(itur)%Tower%EVZ(ielem)=Sw(counter)
                Turbine(itur)%Tower%Eepsilon(ielem)=Se(counter) 
                end do
            endif
        end do
    endif
    
    if (Nal>0) then
        do ial=1,Nal
            do ielem=1,actuatorline(ial)%NElem
                counter=counter+1
                actuatorline(ial)%EVX(ielem)=Su(counter)
                actuatorline(ial)%EVY(ielem)=Sv(counter)
                actuatorline(ial)%EVZ(ielem)=Sw(counter)
                actuatorline(ial)%Eepsilon(ielem)=Se(counter)
            end do
        end do
    endif

    write(*,*) 'Exiting set_vel'
  
    end subroutine set_vel
    
    subroutine get_forces
    
    implicit none
    integer :: counter,itur,iblade,ielem,ial

    counter=0
    if (Ntur>0) then
        do itur=1,Ntur
            !Blade
            do iblade=1,Turbine(itur)%Nblades
                do ielem=1,Turbine(itur)%Blade(iblade)%Nelem
                counter=counter+1
                Sfx(counter)=Turbine(itur)%Blade(iblade)%EFX(ielem)
                Sfy(counter)=Turbine(itur)%Blade(iblade)%EFY(ielem)
                Sfz(counter)=Turbine(itur)%Blade(iblade)%EFZ(ielem)
                end do
            end do
            
            !Tower 
            if(turbine(itur)%has_tower) then
                do ielem=1,Turbine(itur)%Tower%Nelem
                counter=counter+1
                Sfx(counter)=Turbine(itur)%Tower%EFX(ielem)
                Sfy(counter)=Turbine(itur)%Tower%EFY(ielem)
                Sfz(counter)=Turbine(itur)%Tower%EFZ(ielem)
                end do
            endif
        end do
    endif
    
    if (Nal>0) then
        do ial=1,Nal
            do ielem=1,actuatorline(ial)%NElem
                counter=counter+1
                Sfx(counter)=actuatorline(ial)%EFX(ielem)
                Sfy(counter)=actuatorline(ial)%EFY(ielem)
                Sfz(counter)=actuatorline(ial)%EFZ(ielem)
            end do
        end do
    endif
  
    end subroutine get_forces

    !subroutine Compute_Momentum_Source_Term_RBF
 
    !    implicit none
    !    integer :: counter,itur,iblade,ielem,jelem,ial
    !    real    :: dx,dy,dz,d
    !    real,allocatable(:) :: Fx,Fy,Fz
    !    
    !    counter=0
    !    if(Ntur>0) then
    !        do itur=1,Ntur
    !            !Blades>
    !            do iblade=1,Turbine(itur)%Nblades
    !                !> Form Matrix A_rbf
    !                allocate(Fx(Turbine(itur)%Blade(iblade)%Nelem),Fy(Turbine(itur)%Blade(iblade)%Nelem),Fx(Turbine(itur)%Blade(iblade)%Nelem)
    !                do jelem=1,Turbine(itur)%Blade(iblade)%Nelem
    !                    do ielem=1,Turbine(itur)%Blade(iblade)%Nelem
    !                    dx=Turbine(itur)%Blade(iblade)%PEx(ielem)-Turbine(itur)%Blade(iblade)%PEy(jelem)
    !                    dy=Turbine(itur)%Blade(iblade)%PEy(ielem)-Turbine(itur)%Blade(iblade)%PEy(jelem)
    !                    dz=Turbine(itur)%Blade(iblade)%PEz(ielem)-Turbine(itur)%Blade(iblade)%PEz(jelem) 
    !                    d=sqrt(dx*dx+dy*dy+dz*dz)
    !                    Turbine(itur)%Blade(iblade)%A_rbf(ielem,jelem)=IsoKernel(d,Turbine(itur)%Blade(iblade)%Eepsilon(ielem),3)
    !                    enddo
    !                enddo
    !
    !                !> Compute the forces by solving 
    !                call solve(Turbine(itur)%Blade(iblade)%A_rfb,fx)
    !                call solve(Turbine(itur)%Blade(iblade)%A_rfb,fy)
    !                call solve(Turbine(itur)%Blade(iblade)%A_rfb,fz)
    !                
    !                do ielem=1,Turbine(itur)%Blade(iblade)%Nelem
    !                counter=counter+1
    !                Sfx(counter)=fx
    !                Sfy(counter)=fy
    !                Sfz(counter)=fz    
    !                enddo
    !                deallocate(fx,fy,fz)
    !            enddo
    !        enddo
    !    endif
    !end subroutine Compute_Momentum_Source_Term_RBF
    
end module actuator_line_source
