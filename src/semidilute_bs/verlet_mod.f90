!%------------------------------------------------------------------------%
!|  Copyright (C) 2013 - 2016:                                            |
!|  Material Research and Innovation Laboratory (MRAIL)                   |
!|  University of Tennessee-Knoxville                                     |
!|  Author:    Amir Saadat   <asaadat@vols.utk.edu>                       |
!|  Advisor:   Bamin Khomami <bkhomami@utk.edu>                           |
!|                                                                        |
!|  This file is part of BDpack.                                          |
!|                                                                        |
!|  BDpack is a free software: you can redistribute it and/or modify      |
!|  it under the terms of the GNU General Public License as published by  |
!|  the Free Software Foundation, either version 3 of the License, or     |
!|  (at your option) any later version.                                   |
!|                                                                        |
!|  BDpack is distributed in the hope that it will be useful,             |
!|  but WITHOUT ANY WARRANTY; without even the implied warranty of        |
!|  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         |
!|  GNU General Public License for more details.                          |
!|                                                                        |
!|  You should have received a copy of the GNU General Public License     |
!|  along with BDpack.  If not, see <http://www.gnu.org/licenses/>.       |
!%------------------------------------------------------------------------%
!--------------------------------------------------------------------
!
! MODULE: verlet
!
!> @author
!> Amir Saadat, The University of Tennessee-Knoxville, Dec 2015
!
! DESCRIPTION: construction of verlet list
!> 
!
!--------------------------------------------------------------------

module verlet_mod
  
  use :: prcn_mod

  implicit none

  ! Private module procedures:
  private :: init_verlet_t,&
             init_clllst  ,&
             get_ncps     ,&
             cnstr_clllst ,&
             cnstr_nablst ,&
             del_verlet_t

  !> A public type for constructing verlet list
  type verlet
   
    private

    !> The number of the cells per side
    integer :: ncps(3)
    !> Total number of cells in the cubic box
    integer :: nct
    !> The dimension of the cells in each direction
    real(wp) :: cll_sz(3)
    !> The volume of the cells
    real(wp) :: cll_vol
    !> Maximum number of beads per cell
    integer :: mbpc
    !> The array which contains the number of beads in cells
    integer,allocatable :: head(:)
    !> The array which contains the beads index in cells
    integer,allocatable :: binc(:,:)
    !> The array which contains the neighboring cell list
    integer,allocatable :: nclst(:,:)
    !> Maximum occupancy of the cells
    integer :: mocc
    !> i index in all possible interactions
    integer,allocatable :: iidx(:)
    !> j index in all possible interactions
    integer,allocatable :: jidx(:)
    !> An array for keeping track of interactions of interest
    logical,allocatable :: inside(:)
    !> The x-component of vector between beads with indices i,j
    real(wp),allocatable :: Rijx(:)
    !> The y-component of vector between beads with indices i,j
    real(wp),allocatable :: Rijy(:)
    !> The temporary y-component of vector between beads with indices i,j
    real(wp),allocatable :: Rijytmp(:)
    !> The z-component of vector between beads with indices i,j
    real(wp),allocatable :: Rijz(:)
    !> The squared distance between beads with indices i,j
    real(wp),allocatable :: Rijsq(:)
    !> Total number of interactions possible
    integer :: num_int

  contains

    procedure,pass(this) :: init => init_verlet_t
    procedure,pass(this) :: init_cll => init_clllst
    procedure,pass(this) :: cnstr_cll => cnstr_clllst
    procedure,pass(this) :: cnstr_nab => cnstr_nablst
    procedure,pass(this) :: get_ncps
    final :: del_verlet_t

  end type verlet


  ! Private module variables:
  private :: cll_dns,nnc,shifts,j_clx,j_cly,j_clz,j_cll
  ! Protected module variables:
!  protected ::

  !> The density of particles in a cell
  real(wp),save :: cll_dns
  !> Number of neighbering cells
  integer,save :: nnc
  !> The neighboring cells offset
  integer,allocatable,save :: shifts(:,:)
  !> The coordinates for neighboring cells
  integer,allocatable :: j_clx(:),j_cly(:),j_clz(:),j_cll(:)

contains 

  !> Initializes the verlet module
  !! \param id The rank of the process
  subroutine init_verlet(id)

    use :: arry_mod, only: print_vector
    use :: flow_mod, only: FlowType
    use :: strg_mod
    use :: iso_fortran_env

    integer,intent(in) :: id
    integer :: il,j,ntokens,u1,stat,ios
    character(len=1024) :: line
    character(len=100) :: tokens(10)

    open (newunit=u1,action='read',file='input.dat',status='old')
    il=1
ef: do
      read(u1,'(A)',iostat=stat) line
      if (stat == iostat_end) then
        exit ef ! end of file
      elseif (stat > 0) then
        print '(" io_mod: Error reading line ", i0, " Process ID ", i0)', il,id
        stop
      else
        il=il+1
      end if
      call parse(line,': ',tokens,ntokens)
      if (ntokens > 0) then
        do j=1,ntokens
          if(trim(adjustl(tokens(j))) == 'cll_dns') then
            call value(tokens(j+1),cll_dns,ios)
          end if
        end do ! j
      end if ! ntokens
    end do ef
    close(u1)

    select case (FlowType)

      case ('Equil','PSF')
        nnc=13
        allocate(shifts(nnc,3))
        shifts(1,:) =[ 0, 0,-1]
        shifts(2,:) =[ 1, 0,-1]
        shifts(3,:) =[ 1, 0, 0]
        shifts(4,:) =[ 1, 0, 1]
        shifts(5,:) =[-1, 1,-1]
        shifts(6,:) =[ 0, 1,-1]
        shifts(7,:) =[ 1, 1,-1]
        shifts(8,:) =[-1, 1, 0]
        shifts(9,:) =[ 0, 1, 0]
        shifts(10,:)=[ 1, 1, 0]
        shifts(11,:)=[-1, 1, 1]
        shifts(12,:)=[ 0, 1, 1]
        shifts(13,:)=[ 1, 1, 1]

      case ('PEF')
        nnc=31
        allocate(shifts(nnc,3))
        shifts(1,:) =[ 0, 0,-1]
        shifts(2,:) =[ 1, 0,-1]
        shifts(3,:) =[ 2, 0,-1]
        shifts(4,:) =[ 3, 0,-1]
        shifts(5,:) =[ 1, 0, 0]
        shifts(6,:) =[ 2, 0, 0]
        shifts(7,:) =[ 3, 0, 0]
        shifts(8,:) =[ 1, 0, 1]
        shifts(9,:) =[ 2, 0, 1]
        shifts(10,:)=[ 3, 0, 1]
        shifts(11,:)=[-3, 1,-1]
        shifts(12,:)=[-2, 1,-1]
        shifts(13,:)=[-1, 1,-1]
        shifts(14,:)=[ 0, 1,-1]
        shifts(15,:)=[ 1, 1,-1]
        shifts(16,:)=[ 2, 1,-1]
        shifts(17,:)=[ 3, 1,-1]
        shifts(18,:)=[-3, 1, 0]
        shifts(19,:)=[-2, 1, 0]
        shifts(20,:)=[-1, 1, 0]
        shifts(21,:)=[ 0, 1, 0]
        shifts(22,:)=[ 1, 1, 0]
        shifts(23,:)=[ 2, 1, 0]
        shifts(24,:)=[ 3, 1, 0]
        shifts(25,:)=[-3, 1, 1]
        shifts(26,:)=[-2, 1, 1]
        shifts(27,:)=[-1, 1, 1]
        shifts(28,:)=[ 0, 1, 1]
        shifts(29,:)=[ 1, 1, 1]
        shifts(30,:)=[ 2, 1, 1]
        shifts(31,:)=[ 3, 1, 1]
!        this%ncps(1:2)=bs(1:2)/(sqrt(10._wp)*rc_F)
!        this%ncps(3)=bs(3)/rc_F
    end select

    allocate(j_clx(nnc))
    allocate(j_cly(nnc))
    allocate(j_clz(nnc))
    allocate(j_cll(nnc))

  end subroutine init_verlet

  !> Constructor for  verlet type
  !! \param rc The cutoff radius
  !! \param bs The dimension of the box
  subroutine init_verlet_t(this,rc,bs,ntotbead)
  
    class(verlet),intent(inout) :: this
    real(wp),intent(in) :: rc,bs(3)
    integer,intent(in) :: ntotbead

    this%ncps=0
    call this%init_cll(rc,bs,ntotbead)

  end subroutine init_verlet_t

  subroutine get_ncps(this)

    class(verlet),intent(inout) :: this

    print *
    print '(" Initial number of cells for EV calculation: ")'
    print '(3(i10,1x))',this%ncps

  end subroutine get_ncps

  !> Initializes the cell list
  !! \param rc The cutoff radius
  !! \param bs The dimension of the box
  subroutine init_clllst(this,rc,bs,ntotbead)

    use :: flow_mod, only: FlowType
!    use :: inp_smdlt, only: ntotbead
    use :: arry_mod, only: print_vector

    class(verlet),intent(inout) :: this
    real(wp),intent(in) :: rc,bs(3)
    integer,intent(in) :: ntotbead
    integer :: clx,cly,clz,cll,czNxNy,cyNx
    real(wp) :: ncpsl(3)

    
    ncpsl=this%ncps

    select case (FlowType)
      case ('Equil')
        this%ncps(:)=bs(:)/rc
      case ('PSF')
        this%ncps(1)=bs(1)/(sqrt(2._wp)*rc)
        this%ncps(2:3)=bs(2:3)/rc
      case ('PEF')
        this%ncps(1)=bs(1)/(sqrt(10._wp)*rc/3)
        this%ncps(2:3)=bs(2:3)/rc
    end select
    this%cll_sz(1:3)=bs(1:3)/this%ncps(1:3)
    this%nct=this%ncps(1)*this%ncps(2)*this%ncps(3)
    this%cll_vol=bs(1)*bs(2)*bs(3)/this%nct

!print*,'bs',bs
!print*,'rc',rc
!print *,'ncps',this%ncps,cll_dns
!print *,'size',this%cll_sz
!!
!print *,'cll_vol',this%cll_vol,'cll_vol',this%cll_sz(1)*this%cll_sz(2)*this%cll_sz(3)

    this%mbpc=int(this%cll_vol*cll_dns)

    if (allocated(this%binc)) deallocate(this%binc)
    allocate(this%binc(this%nct,this%mbpc))

    if (any(this%ncps /= ncpsl)) then

      if (allocated(this%head)) deallocate(this%head)
      if (allocated(this%nclst)) deallocate(this%nclst)
  
      allocate(this%head(this%nct))
      allocate(this%nclst(this%nct,nnc))

!print *,'mbpc',this%mbpc

!print *,'nnc:',nnc
!print *,'nct',this%nct
!print *,'ncps',this%ncps
!print *,'ncps',this%ncps
!print *,'ncpsl',ncpsl

      do clz=0, this%ncps(3)-1
        czNxNy=clz*this%ncps(1)*this%ncps(2)
        do cly=0, this%ncps(2)-1
          cyNx=cly*this%ncps(1)
          do clx=0, this%ncps(1)-1
            cll=czNxNy+cyNx+clx+1
            j_clx=clx+shifts(:,1)
            j_cly=cly+shifts(:,2)
            j_clz=clz+shifts(:,3)
            j_clx=modulo(j_clx,this%ncps(1))
            j_cly=modulo(j_cly,this%ncps(2))
            j_clz=modulo(j_clz,this%ncps(3))
            j_cll=j_clz*this%ncps(1)*this%ncps(2)+j_cly*this%ncps(1)+j_clx+1
            this%nclst(cll,:)=j_cll
!          print *,'cell:',clx,cly,clz,cll
!          call print_vector(this%nclst(cll,:),'nclst')
          end do ! clx
        end do ! cly
      end do ! clz

    end if

    this%num_int=ntotbead*nnc*this%mbpc*0.5
!print *,'num_int',this%num_int

    if (allocated(this%iidx)) deallocate(this%iidx)
    if (allocated(this%jidx)) deallocate(this%jidx)
    if (allocated(this%inside)) deallocate(this%inside)
    if (allocated(this%Rijx)) deallocate(this%Rijx)
    if (allocated(this%Rijy)) deallocate(this%Rijy)
    if (allocated(this%Rijz)) deallocate(this%Rijz)
    if (allocated(this%Rijsq)) deallocate(this%Rijsq)
    if (FlowType == 'PEF') then
      if (allocated(this%Rijytmp)) deallocate(this%Rijytmp)
    end if

    allocate(this%iidx(this%num_int))
    allocate(this%jidx(this%num_int))
    allocate(this%inside(this%num_int))
    allocate(this%Rijx(this%num_int))
    allocate(this%Rijy(this%num_int))
    allocate(this%Rijz(this%num_int))
    allocate(this%Rijsq(this%num_int))
    if (FlowType == 'PEF') then
      allocate(this%Rijytmp(this%num_int))
    end if

  end subroutine init_clllst

  !> Constructs the cell list
  !! \param Rbx x-coordinate of the position vector
  !! \param Rby y-coordinate of the position vector
  !! \param Rbz z-coordinate of the position vector
  subroutine cnstr_clllst(this,Rbx,Rby,Rbz,itime,ntotbead,ntotbeadx3)

!    use :: inp_smdlt, only: ntotbead,ntotbeadx3
    use :: arry_mod, only: print_vector,print_matrix

    class(verlet),intent(inout) :: this
    real(wp),intent(in) :: Rbx(:)
    real(wp),intent(in) :: Rby(:)
    real(wp),intent(in) :: Rbz(:)
    integer,intent(in) :: ntotbead,ntotbeadx3
    integer :: i,clx,cly,clz,cll,itime,j

    this%head=0
    this%binc=0

    do i=1, ntotbead
      
      clx=int(Rbx(i)/this%cll_sz(1))
      cly=int(Rby(i)/this%cll_sz(2))
      clz=int(Rbz(i)/this%cll_sz(3))

      ! if the bead is exactly on the boundary
      if (clx == this%ncps(1)) clx=clx-1
      if (cly == this%ncps(2)) cly=cly-1
      if (clz == this%ncps(3)) clz=clz-1

      cll=clz*this%ncps(1)*this%ncps(2)+cly*this%ncps(1)+clx+1

      this%head(cll)=this%head(cll)+1
      this%binc(cll,this%head(cll))=i

!      print *,'cll,head,i',cll,this%head(cll),i
!      print *,'binc',this%binc(cll,this%head(cll))

    end do
    this%mocc=maxval(this%head)

!if (itime==8479)then
!    call print_vector(this%head,'newhead')
!do i=1,size(this%binc,1)
!do j=1,size(this%binc,2)
!if (this%binc(i,j)/=0)then
!print*,'i,j',i,j
!print*,'binc',this%binc(i,j)
!endif
!enddo
!enddo
!    print *,'mocc',this%mocc
!endif

  end subroutine cnstr_clllst

  !> Constructs the neighbor list
  !! \param Rbx x-coordinate of the position vector
  !! \param Rby y-coordinate of the position vector
  !! \param Rbz z-coordinate of the position vector
  !! \param bs the dimension of the box
  !! \param invbs the inverse of box dimensions
  !! \param nlst The neighbor list
  subroutine cnstr_nablst(this,Rbx,Rby,Rbz,rc,bs,invbs,nlst,itime,ntotbead,ntotbeadx3)
     
!    use :: inp_smdlt, only: ntotbead,ntotbeadx3
    use :: arry_mod, only: print_vector,print_matrix
    use :: flow_mod, only: FlowType
    use :: trsfm_mod, only: eps_m,tanb,sinth,costh

    class(verlet),intent(inout) :: this
    real(wp),intent(in) :: Rbx(:)
    real(wp),intent(in) :: Rby(:)
    real(wp),intent(in) :: Rbz(:)
    real(wp),intent(in) :: rc
    integer,intent(in) :: itime,ntotbead,ntotbeadx3
    integer,allocatable,intent(inout) :: nlst(:,:)
    integer,allocatable :: beadi_tmp(:),beadj(:),beadj_tmp(:)
    logical,allocatable :: pair(:)
    integer :: i,j,nab,idx,cll,beadi,k
    real(wp) :: bs(3),invbs(3),rcsq

    this%iidx=0
    this%jidx=0
    allocate(beadi_tmp(this%nct))
    allocate(beadj_tmp(this%nct))
    allocate(pair(this%nct))

    ! Same-cell interactions:
    idx=1
    do i=1, this%mocc-1
      beadi_tmp=this%binc(:,i)
      do j=i+1, this%mocc
        beadj_tmp=this%binc(:,j)
        pair=beadi_tmp < beadj_tmp
        nab=count(pair)
        this%iidx(idx:(idx+nab-1))=pack(beadi_tmp,mask=pair)
        this%jidx(idx:(idx+nab-1))=pack(beadj_tmp,mask=pair)
!if(itime==6028) then
!print *,'i',i,j
!print *,'nab',nab
!call print_vector(beadi_tmp,'bi')
!call print_vector(beadj_tmp,'bj')
!call print_vector(this%iidx(idx:(idx+nab-1)),'iidx')
!call print_vector(this%jidx(idx:(idx+nab-1)),'jidx')
!end if
        idx=idx+nab
      end do
    end do

    deallocate(beadi_tmp)
    deallocate(beadj_tmp)
    deallocate(pair)
    
    ! Different-cell interactions:
    allocate(beadj(nnc*this%mbpc))
    allocate(beadj_tmp(nnc*this%mbpc))
    allocate(pair(nnc*this%mbpc))

    do cll=1, this%nct
      beadj=0
      beadj_tmp=0
      do j=1, nnc
        beadj_tmp((j-1)*this%mbpc+1:j*this%mbpc)=this%binc(this%nclst(cll,j),:)
      end do
      pair=beadj_tmp /= 0
      nab=count(pair)
      beadj(1:nab)=pack(beadj_tmp,mask=pair)
      do i=1, this%mbpc
        beadi=this%binc(cll,i)
        if (beadi == 0) exit
        this%iidx(idx:(idx+nab-1))=beadi
        this%jidx(idx:(idx+nab-1))=beadj(1:nab)
        idx=idx+nab
      end do ! i
    end do ! cll
    idx=idx-1
    
    deallocate(beadj)
    deallocate(beadj_tmp)
    deallocate(pair)
!print *,'idx',idx
!print *,maxval(this%iidx)
!print *,maxval(this%jidx)
!print *,size(Rbx)
!print *,size(this%Rijx)
!print *,size(this%iidx)
!print *,'n5'
!call print_vector(this%iidx(1:idx),'iidx')
!call print_vector(this%jidx(1:idx),'jidx')

    this%Rijx(1:idx)=Rbx(this%iidx(1:idx))-Rbx(this%jidx(1:idx))
    this%Rijy(1:idx)=Rby(this%iidx(1:idx))-Rby(this%jidx(1:idx))
    this%Rijz(1:idx)=Rbz(this%iidx(1:idx))-Rbz(this%jidx(1:idx))
!if (itime==8479)then
!print*,'i,j',this%iidx(16),this%jidx(16)
!print*,'ri',Rbx(this%iidx(16)),Rby(this%iidx(16)),Rbz(this%iidx(16))
!print*,'rj',Rbx(this%jidx(16)),Rby(this%jidx(16)),Rbz(this%jidx(16))
!print*,'rijx1',this%Rijx(16)
!print*,'rijy1',this%Rijy(16)
!print*,'rijz1',this%Rijz(16)
!endif
!print *,'bs',bs
!print *,'invbs',invbs
    ! Minimum Image Covention:
    this%Rijx(1:idx)=this%Rijx(1:idx)-nint(this%Rijx(1:idx)*invbs(1))*bs(1)
    this%Rijy(1:idx)=this%Rijy(1:idx)-nint(this%Rijy(1:idx)*invbs(2))*bs(2)
    this%Rijz(1:idx)=this%Rijz(1:idx)-nint(this%Rijz(1:idx)*invbs(3))*bs(3)
    select case (FlowType)
      case ('PSF')
        this%Rijx(1:idx)=this%Rijx(1:idx)+eps_m*this%Rijy(1:idx)
      case ('PEF')
        this%Rijytmp=this%Rijy
        this%Rijx=this%Rijx+tanb*this%Rijytmp
        this%Rijy=sinth*this%Rijx+costh*this%Rijytmp
        this%Rijx=costh*this%Rijx-sinth*this%Rijytmp
    end select
    this%Rijsq(1:idx)=this%Rijx(1:idx)*this%Rijx(1:idx) + &
                      this%Rijy(1:idx)*this%Rijy(1:idx) + &
                      this%Rijz(1:idx)*this%Rijz(1:idx)
!if (itime==8479)then
!print*,'rijx2',this%Rijx(16)
!print*,'rijy2',this%Rijy(16)
!print*,'rijz2',this%Rijz(16)
!print*,'r22',this%Rijsq(16)
!endif
!    this%inside(1:idx)=this%Rijsq(1:idx) <= rs**2
    this%inside=.false.
    this%inside(1:idx)=this%Rijsq(1:idx) <= rc**2
    nab=count(this%inside)

!if(itime==6028)then
!k=0
!do i=1,idx
!if(this%iidx(i)==0.or.this%jidx(i)==0)then
!print*,'ohoh'
!stop
!print*,this%iidx(i),this%jidx(i)
!endif
!if(this%inside(i))then
!k=k+1
!print*,'idx',i,k
!print*,this%iidx(i),this%jidx(i)
!endif
!enddo
!print*,'idx',idx
!call print_vector(this%iidx(1:idx),'iidx')
!call print_vector(this%jidx(1:idx),'jidx')
!print*,'nab',nab
!endif


    if(allocated(nlst)) deallocate(nlst)
    allocate(nlst(nab,2))
    nlst(:,1)=pack(this%iidx,mask=this%inside)
    nlst(:,2)=pack(this%jidx,mask=this%inside)
!if(itime==6028)then
!do i=1,nab
!if(nlst(i,1)==0.or.nlst(i,2)==0)then
!print*,'ohoh'
!print*,'i',i
!endif
!enddo
!endif

!do i=1, num_int
!  if (this%iidx(i) /= 0) then
!    print *,'beadi,j',this%iidx(i),this%jidx(i)
!    print *,'r:',this%Rijx(i),this%Rijy(i),this%Rijz(i)
!    print *,'rijmag',this%Rijsq(i),rc**2
!    print *,'ins',this%inside(i)
!  end if
!end do
!call print_matrix(nlst,'nlst')
! print *,'nab',nab

  end subroutine cnstr_nablst
  

  !> Destructor for  verlet type
  subroutine del_verlet_t(this)

    type(verlet),intent(inout) :: this

  end subroutine del_verlet_t

  subroutine del_verlet()

    deallocate(shifts)
    deallocate(j_clx,j_cly,j_clz,j_cll)

  end subroutine del_verlet

end module verlet_mod
