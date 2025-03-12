! This module is used for the storage of the n (number of atoms/particles),
! t(simulation time), frame  and positions information.
! Also it ensures that these variables can be accessed by the subroutine.
module var
    implicit none

    integer :: n, t
    integer, allocatable :: frame(:)
    real, allocatable :: x(:,:), y(:,:), z(:,:)
    real :: d, a, v
end module var

! Test main program. Eliminate this program when all subroutine can be merged.
program main
    use var

    implicit none

    ! n: number of atoms/particles = d * v    test
    ! t: simulation time                      test
    ! d: density = n/v                        test
    ! a: lenght of cube                       test
    ! v: volume                               test
    t = 5
    d = 0.8
    a = 1.55
    v = a**3

    ! nint is necessary to truncate the nearest integer number
    n = nint(d * v)                         ! test

    ! allocate memory for x y z variable that is labeled following the
    ! n(atom1, atom2, ...) and the time frame (time1,time2,...)
    allocate(x(n, t), y(n, t), z(n, t), frame(t))

    ! Read the trajectory file
    call read_trajectory

    ! call test1()
    ! call test2()

    print *, n

    call compute_rdf()
    call compute_rmsd()

    deallocate(x, y, z, frame)
end program main

subroutine read_trajectory
    use var

    implicit none

    integer :: i, j, ios, f

    open(1, file = 'traj.xyz', status = 'old', action = 'read')

    ! Read information line by line.
    ! i.e. at time j=1 or frame=1, read n atoms xyz information, then for
    ! j = 2, 3, ... the same
    do j = 1, t
        do i = 1, n
            ! this 'xyz' format is： frame x y z
            ! these positions are vectorized following the the atom number
            ! (i = atom1, atom2, ...) and the frame that is registered
            ! (j = 1, 2, ...)
            read(1, *, iostat = ios) f, x(i, j), y(i, j), z(i, j)

            ! store the frame information (it's enough with register first atom
            ! frame)
            if (i == 1) then
                frame(j) = f
            end if
        end do
    end do

    close(1)

    print *, 'Finished reading the trajectories.'
end subroutine reading

! Test to proove that the program has access to all the stored xyz information.
subroutine test1()
    use var

    implicit none
    integer :: i, j

    print *, 'Processing stored coordinates...'

    do j = 1, t
        print *, 'frame:', frame(j)

        do i = 1, n
            print *,'(', x(i, j), y(i, j), z(i, j), ')'
        end do
    end do
end subroutine test1

! Test to access certain frame xyz information.
subroutine test2()
    use var

    implicit none

    integer :: i, j

    print *, 'Testing specific frame data:'

    do j = 1, t
        if (frame(j) == 3) then  ! let's test for frame=3
            print *, 'frame:', frame(j)

            do i = 1, n
                print *, 'x', x(i, j), 'y', y(i, j), 'z', z(i, j)
            end do
        end if
    end do
end subroutine test2

! Compute RDF using the stored data.
subroutine compute_rdf()
    use var

    implicit none

    integer :: i, j, k, fi
    real(4), parameter :: rmax = 1.0               ! maximum radius
    real(4), parameter :: dr = 0.1                 ! rangesteps
    integer :: bins                                ! bin number
    real(4), allocatable :: rdf(:), r_values(:)
    real(4) :: r, dx, dy, dz, dv, density          ! dx,dy,dz positions variations
    integer :: bi                                  ! bi bv are respectively bin index and spherical volume
    real(4) :: volume

    bins = int(rmax / dr)
    allocate(rdf(bins), r_values(bins))
    rdf = 0.0

    do fi = 1, t       ! loop for all frames
        do i = 1, n-1  ! loop for all atoms i.e. i=1 j=2 dx=x1-x2 ...
            do j = i+1, n
                ! x y z variation between frames to calculate r
                dx = x(j, fi) - x(i, fi)
                dy = y(j, fi) - y(i, fi)
                dz = z(j, fi) - z(i, fi)

                r = sqrt(dx**2 + dy**2 + dz**2)    ! r = sqrt(dx^2 + dy^2 + dz^2)
                print *, 'r:',r                    ! check the calculated r

                ! consider sphere to calculate rdf
                if (r < rmax) then
                    bi = int(r / dr) + 1  ! there a different portions/zones of spheres, each zone/portions labeled as bi=1,2,3,...
                    rdf(bi) = rdf(bi) + 1 ! bi correspond to the zone of sphere that this r belongs and we will increase the size to accumulate the rdf
                end if
            end do
        end do
    end do

    ! volume != entire cubic volume, it's refering the rdf related spherical
    ! volume. Therefore, it's necessary to set a maximum radius
    volume = (4.0/3.0) * 3.1415926 * rmax**3
    density = n  / volume

    do k = 1, bins
        r_values(k) = k * dr
        dv = 4.0 * 3.14159 * r_values(k)**2 * dr  ! volume between r to r + dr to normalize the rdf
        rdf(k) = rdf(k) / (density * n * dv )     ! normalize the rdf
    end do

    open(2, file = 'rdf_data.txt', status = 'replace')
    do k = 1, bins
        write(2, *) r_values(k), rdf(k)
    end do
    close(2)

    print *, 'RDF calculation completed and saved to rdf_data.txt'

    deallocate(rdf, r_values)
end subroutine compute_rdf

! Compute RMSD using the stored data.
subroutine compute_rmsd()
    use var

    implicit none

    integer :: i, j
    real(4), allocatable :: rmsd(:)
    real(4) :: dx, dy, dz, sum_sq

    allocate(rmsd(t))

    do j = 1, t   ! for all time frame
        sum_sq = 0.0  ! summation using the acumulation
        do i = 1, n
            ! here difference of positions is between the xj and x1 (as
            ! reference and changeble).
            dx = x(i, j) - x(i, 1)
            dy = y(i, j) - y(i, 1)
            dz = z(i, j) - z(i, 1)

            sum_sq = sum_sq + (dx**2 + dy**2 + dz**2)
        end do

        rmsd(j) = sqrt(sum_sq / n)    !   rmsd=sqrt(summation(r-r')^2 / n)
    end do

    open(2, file = 'rmsd_data.txt', status = 'replace')
    do j = 1, t
        write(2, *) frame(j), rmsd(j)
    end do
    close(2)

    print *, 'RMSD calculation completed and saved to rmsd_data.txt'

    deallocate(rmsd)
end subroutine compute_rmsd
