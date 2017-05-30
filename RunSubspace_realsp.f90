program test_subspace
use,intrinsic:: iso_fortran_env, only: int64, stderr=>error_unit
use,intrinsic:: iso_c_binding, only: c_int,c_bool
use comm, only: sp, sizeof
use perf, only: sysclock2ms,assert
use subspace, only: esprit
use signals,only: signoise
use filters,only: fircircfilter

implicit none

integer(c_int) :: Ns = 1024, &
                  Ntone = 2
real(sp) :: fs=48000, &
            f0=12345.6, &
            snr=60  !dB
character(len=*),parameter :: bfn='../bfilt.txt'

integer(c_int) :: M,Nb
integer:: fstat
logical(c_bool) :: filtok
 

real(sp),allocatable :: x(:), b(:), y(:)
real(sp),allocatable :: tones(:),sigma(:)

integer(int64) :: tic,toc
integer :: narg,u
character(len=16) :: arg
!----------- parse command line ------------------
M = Ns / 2
narg = command_argument_count()

if (narg > 0) call get_command_argument(1,arg); read(arg,*) Ns
if (narg > 1) call get_command_argument(2,arg); read(arg,*) fs
if (narg > 2) call get_command_argument(3,arg); read(arg,*) Ntone
if (narg > 3) call get_command_argument(4,arg); read(arg,*) M
if (narg > 4) call get_command_argument(5,arg); read(arg,*) snr !dB

print *, "Fortran Esprit: Real Single Precision"
!---------- assign variable size arrays ---------------
allocate(x(Ns), y(Ns), tones(Ntone/2), sigma(Ntone/2))
!--- checking system numerics --------------
if (sizeof(fs) /= 4) then
    write(stderr,*) 'expected 4-byte real but you have real bytes: ', sizeof(fs)
    error stop
endif
!------ simulate noisy signal ------------ 
call signoise(fs,f0,snr,Ns,&
              x)
!------ filter noisy signal --------------
! read coefficients 'b'
filtok=.false.
open (newunit=u, file=bfn, status='old', action='read', iostat=fstat)
if (fstat == 0) then
    read(u,*) Nb !first line of file: number of coeff
    allocate(b(Nb))
    read(u,*) b ! second line all coeff
    close(u)
    print *, b

    call system_clock(tic)
    call fircircfilter(x, size(x), b, size(b), y, filtok)
    call system_clock(toc)
    print *, 'seconds to FIR filter: ',sysclock2ms(toc-tic)/1000
endif

if (fstat /= 0 .or. .not. filtok) then
    write(stderr,*) 'skipped FIR filter.'
    y=x
endif
!------ estimate frequency of sinusoid in noise --------
call system_clock(tic)
call esprit(y, size(y), Ntone, M, fs, &
            tones,sigma)
call system_clock(toc)

! -- assert <0.1% error ---------
call assert(abs(tones(1)-f0) <= 0.001*f0)

print *, 'estimated tone freq [Hz]: ',tones
print *, 'with sigma: ',sigma
print *, 'seconds to estimate frequencies: ',sysclock2ms(toc-tic)/1000

print *,'OK'

! deallocate(x,y,tones,sigma)  ! this is automatic going out of scope
end program test_subspace



