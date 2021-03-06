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
! MODULE: diffusion decomposition
!
!> @author
!> Amir Saadat, The University of Tennessee-Knoxville, June 2014
!
! DESCRIPTION: 
!> Decomposes the diffusion tensor for calculating Brownian noise on CPU
!--------------------------------------------------------------------
module diffdcmp_mod

 use :: prcn_mod
 use :: hi_mod, only: DecompMeth,ncols,dw_bltmp,Diff_tens,errormin,mubBlLan,dw_bl,&
   HIcalc_mode,Coeff_tens,aBlLan,WBlLan,VBlLan,Ybar,VcntBlLan,upfactr,mBlLan,mset,&
   mst,hstar
 use :: types, only: decomp
 use :: dcmp_smdlt, only: Lanczos,BlockLanczos
 use :: arry_mod, only: print_vector,print_matrix

contains

  subroutine calcBrownNoise_cpu(decompRes,itime,ntotbeadx3,boxsize)

    use :: arry_mod, only: print_matrix,print_vector
            
    integer,intent(in) :: ntotbeadx3
    integer :: info,ichain,itime,mrst
    real(wp) :: boxsize(3),anorm,rcond
    type(decomp) :: decompRes
    integer :: i,j,ipiv(120)
    real(wp) :: sum(120)

    if (HIcalc_mode == 'Ewald') then

      if (DecompMeth == 'Cholesky') then
        
        dw_bltmp=dw_bl
        if (hstar /= 0._wp) then
          Coeff_tens=Diff_tens
          call potrf(Coeff_tens,info=info)
          if (info /= 0) then
            print '(" Unsuccessful Cholesky factorization of diffusion matrix")'
            print '(" itime: ",i10)',itime
            print '(" info: ",i10)',info
            decompRes%Success=.false.
          else
            decompRes%Success=.true.
          end if
          if (decompRes%Success) call trmm(Coeff_tens,dw_bltmp,transa='T')
        end if

      elseif (DecompMeth == 'Lanczos') then
        if ((mod(itime,upfactr*ncols) == 1) .or. (upfactr == 1)) then
          mrst=mBlLan
          if (ncols == 1) then
#ifdef USE_DP
            call Lanczos(dw_bl,WBlLan,Ybar,ntotbeadx3,errormin,mubBlLan,mrst,dw_bltmp,&
                 decompRes,D=Diff_tens,msetinp=mset)
#elif USE_SP
            ! Note!!: Even if the working precision is sp, the decomposition has to be done with dp.
            call Lanczos(real(dw_bl,kind=double),real(WBlLan,kind=double),real(Ybar,kind=double),ntotbeadx3,&
real(errormin,kind=double),mubBlLan,mrst,real(dw_bltmp,kind=double),decompRes,D=real(Diff_tens,kind=double),&
msetinp=mset)
#endif
          else
#ifdef USE_DP
            call BlockLanczos(dw_bl,aBlLan,WBlLan,Ybar,ntotbeadx3,ncols,errormin,mubBlLan,mrst,dw_bltmp,&
decompRes,D=Diff_tens,msetinp=mset)
#elif USE_SP
            call BlockLanczos(real(dw_bl,kind=double),real(aBlLan,kind=double),real(WBlLan,kind=double)    ,&
real(Ybar,kind=double),ntotbeadx3,ncols,real(errormin,kind=double),mubBlLan,mrst,real(dw_bltmp,kind=double),&
decompRes,D=real(Diff_tens,kind=double),msetinp=mset)
#endif
          endif
          mst=mrst
        else
          if (ncols == 1) then
#ifdef USE_DP
            call Lanczos(dw_bl,WBlLan,Ybar,ntotbeadx3,errormin,mubBlLan,mst,dw_bltmp,decompRes,D=Diff_tens,&
msetinp=mset)
#elif USE_SP
            call Lanczos(real(dw_bl,kind=double),real(WBlLan,kind=double),real(Ybar,kind=double),ntotbeadx3,&
real(errormin,kind=double),mubBlLan,mst,real(dw_bltmp,kind=double),decompRes,D=real(Diff_tens,kind=double) ,&
msetinp=mset)
#endif
          else
#ifdef USE_DP
            call BlockLanczos(dw_bl,aBlLan,WBlLan,Ybar,ntotbeadx3,ncols,errormin,mubBlLan,mst,dw_bltmp,&
decompRes,D=Diff_tens,msetinp=mset)
#elif USE_SP
            call BlockLanczos(real(dw_bl,kind=double),real(aBlLan,kind=double),real(WBlLan,kind=double)   ,&
real(Ybar,kind=double),ntotbeadx3,ncols,real(errormin,kind=double),mubBlLan,mst,real(dw_bltmp,kind=double),&
decompRes,D=real(Diff_tens,kind=double),msetinp=mset)
#endif
          end if
        end if
      else
        print '(" Incorrect Decomposition method: ",a)',DecompMeth
        stop
      end if ! DecompMeth

    elseif (HIcalc_mode == 'PME') then

      if (DecompMeth == 'Lanczos') then
        if ((mod(itime,upfactr*ncols) == 1) .or. (upfactr == 1)) then
          mrst=mBlLan
          if (ncols == 1) then
#ifdef USE_DP
            call Lanczos(dw_bl,WBlLan,Ybar,ntotbeadx3,errormin,mubBlLan,mrst,dw_bltmp,decompRes,boxsizeinp=boxsize,&
msetinp=mset)
#elif USE_SP
            call Lanczos(real(dw_bl,kind=double),real(WBlLan,kind=double),real(Ybar,kind=double),ntotbeadx3,&
real(errormin,kind=double),mubBlLan,mrst,real(dw_bltmp,kind=double),decompRes,boxsizeinp=boxsize,msetinp=mset)
#endif
          else
#ifdef USE_DP
            call BlockLanczos(dw_bl,aBlLan,WBlLan,Ybar,ntotbeadx3,ncols,errormin,mubBlLan,mrst,dw_bltmp,&
decompRes,boxsizeinp=boxsize,msetinp=mset)
#elif USE_SP
            call BlockLanczos(real(dw_bl,kind=double),real(aBlLan,kind=double),real(WBlLan,kind=double)    ,&
real(Ybar,kind=double),ntotbeadx3,ncols,real(errormin,kind=double),mubBlLan,mrst,real(dw_bltmp,kind=double),&
decompRes,boxsizeinp=boxsize,msetinp=mset)
#endif
          endif
          mst=mrst
        else
          if (ncols == 1) then
#ifdef USE_DP
            call Lanczos(dw_bl,WBlLan,Ybar,ntotbeadx3,errormin,mubBlLan,mst,dw_bltmp,decompRes,boxsizeinp=boxsize,&
msetinp=mset)
#elif USE_SP
            call Lanczos(real(dw_bl,kind=double),real(WBlLan,kind=double),real(Ybar,kind=double),ntotbeadx3,&
real(errormin,kind=double),mubBlLan,mst,real(dw_bltmp,kind=double),decompRes,boxsizeinp=boxsize,msetinp=mset)
#endif
          else
#ifdef USE_DP
            call BlockLanczos(dw_bl,aBlLan,WBlLan,Ybar,ntotbeadx3,ncols,errormin,mubBlLan,mst,dw_bltmp,&
decompRes,boxsizeinp=boxsize,msetinp=mset)
#elif USE_SP
            call BlockLanczos(real(dw_bl,kind=double),real(aBlLan,kind=double),real(WBlLan,kind=double)   ,&
real(Ybar,kind=double),ntotbeadx3,ncols,real(errormin,kind=double),mubBlLan,mst,real(dw_bltmp,kind=double),&
decompRes,boxsizeinp=boxsize,msetinp=mset)
#endif
          end if
        end if
      else
        print '(" Incorrect Decomposition method: ",a)',DecompMeth
        stop
      end if ! DecompMeth

    end if ! HIcalc_mode

  end subroutine calcBrownNoise_cpu

end module diffdcmp_mod
