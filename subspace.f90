module subspace
  use, intrinsic:: iso_fortran_env, stderr=>error_unit
  use, intrinsic:: iso_c_binding, only: c_int
  use comm,only: wp,pi, debug
  use covariance,only: autocov
  !use perf, only : sysclock2ms

  Implicit none

  private
  public::esprit

contains


subroutine Cesprit(x,N,L,M,fs,tones,sigma) bind(c)

  integer(c_int), intent(in) :: L,M,N
  complex(wp),intent(in) :: x(N)
  real(wp),intent(in) :: fs
  real(wp),intent(out) :: tones(L),sigma(L)
  
  call esprit(x,M,fs,tones,sigma)
  
end subroutine Cesprit


subroutine esprit(x,M,fs,tones,sigma)

  complex(wp),intent(in) :: x(:)
  integer, intent(in) :: M
  real(wp),intent(in) :: fs
  real(wp),intent(out) :: tones(:),sigma(:)
  
  integer, parameter :: c64 = kind((0._real32, 1._real32))
  integer, parameter :: c128 = kind((0._real64, 1._real64))
!    integer, parameter :: c256 = kind((0._real128, 1._real128))

  integer :: L

  integer :: LWORK,i
  integer,parameter :: LRATIO=8
  complex(wp) :: R(M,M), U(M,M), VT(M,M)
  real(wp) :: S(M,M),RWORK(8*M)
  integer :: stat
  real(wp),allocatable :: ang(:)
  complex(wp),allocatable :: S1(:,:), S2(:,:),W1(:,:),Phi(:,:),junk(:,:), eig(:)
  complex(wp) ::  IPIV(M-1), CWORK(8*M),SWORK(8*M) !yes, this swork is complex


   ! integer(i64) :: tic,toc
   
   L = size(sigma)
   
   allocate(S1(M-1,L), S2(M-1,L), ang(L), eig(L), W1(L,L), Phi(L,L), junk(L,L))

Lwork = 8*M !at least 5M for gesvd
!------ estimate autocovariance from single time sample vector (1-D)
!call system_clock(tic)
call autocov(x, R)
!call system_clock(toc)
!if (sysclock2ms(toc-tic).gt.1) write(stdout,*) 'ms to compute autocovariance estimate:',sysclock2ms(toc-tic)

!-------- SVD -------------------
!call system_clock(tic)
!http://www.netlib.org/lapack/explore-html/d4/dca/group__real_g_esing.html
if (debug) print *,'LWORK: ',LWORK
select case (kind(U))
  case (c64)  
    call cgesvd('A','N',M,M,R,M,S,U,M,VT,M,SWORK,LWORK,RWORK,stat)
  case (c128)  
    call zgesvd('A','N',M,M,R,M,S,U,M,VT,M,SWORK,LWORK,RWORK,stat)
  case default 
    error stop 'unknown type input to GESVD'
end select

if (stat /= 0) then
    write(stderr,*) 'GESVD return code',stat,'  LWORK:',LWORK,'  M:',M
    if (M /= LWORK/LRATIO) write(stderr,*) 'possible LWORK overflow'
    error stop
endif
!call system_clock(toc)
!if (sysclock2ms(toc-tic).gt.1.) write(stdout,*) 'ms to compute SVD:',sysclock2ms(toc-tic)

!-------- LU decomp
S1 = U(1:M-1, :L)
S2 = U(2:M, :L)

!call system_clock(tic)
W1=matmul(conjg(transpose(S1)), S1)
select case (kind(U))
  case (c64) 
    call cgetrf(L,L,W1,L,ipiv,stat) 
  case (c128)
    call zgetrf(L,L,W1,L,ipiv,stat) 
  case default
    error stop 'unknown type input to GETRF'
end select

if (stat /= 0) then
  write(stderr,*) 'GETRF inverse output code',stat
  error stop
endif
!------------ LU inversion
select case (kind(U))
  case (c64) 
    call cgetri(L,W1,L,ipiv,Swork,Lwork,stat) 
  case (c128)
    call zgetri(L,W1,L,ipiv,Swork,Lwork,stat) 
  case default
    error stop 'unknown type input to GETRI'
end select

if (stat /= 0) then
  write(stderr,*) 'GETRI output code',stat
  error stop
endif
!call system_clock(toc)
!if (sysclock2ms(toc-tic).gt.1.) write(stdout,*) 'ms to compute Phi via LU inv():',sysclock2ms(toc-tic)

!-----------
!call system_clock(tic)
Phi = matmul(matmul(W1, conjg(transpose(S1))), S2)

select case (kind(U))
  case (c64) 
    call cgeev('N','N',L,Phi,L,eig,junk,L,junk,L,cwork,lwork,rwork,stat)
  case (c128)
    call zgeev('N','N',L,Phi,L,eig,junk,L,junk,L,cwork,lwork,rwork,stat)
  case default 
    error stop 'unknown type input to GEEV'
end select

if (stat /= 0) then
  write(stderr,*) 'GEEV output code',stat
  error stop
endif
!call system_clock(toc)
!if (sysclock2ms(toc-tic).gt.1.) write(stdout,*) 'ms to compute eigenvalues:',sysclock2ms(toc-tic)

ang = atan2(aimag(eig), real(eig,wp))
!ang = atan2(eig%im, eig%re)  ! Fortran 2008, Gfortran 7 doesn't support yet!!

tones = abs(fs*ang/(2*pi))
!eigenvalues
do concurrent (i = 1:L/2)
  sigma(i) = S(i,i)
enddo

end subroutine esprit

end module subspace
