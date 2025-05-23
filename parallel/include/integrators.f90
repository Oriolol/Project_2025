!
! integrators.f90
! Molecular Dynamics Simulation of a Van der Waals Gas
! Oriol Miro
!
! Integrators for Molecular Dynamics.
! A 3-dimensional cubic system is assumed.
!

module integrators
    use global_vars
    use lj_forces
    use geometry
    use mpi

    implicit none

    contains

        subroutine velocity_verlet(positions, velocities, lj_potential)
            implicit none

            real(8), allocatable, intent(inout) :: positions(:, :), velocities(:, :)
            real(8), intent(out) :: lj_potential
            real(8), allocatable ::  forces(:, :)                             

            ! From here it will be moved to the main, and the variables passed as parameters.
            integer :: rank, nproc, ierror, i
            integer, allocatable :: counts(:), displs(:)


            call MPI_Comm_rank(MPI_COMM_WORLD, rank, ierror)
            call MPI_Comm_size(MPI_COMM_WORLD, nproc, ierror) 

            ! MASTER = 0

            allocate(counts(0:nproc - 1))
            allocate(displs(0:nproc - 1))

            do i = 0, nproc - 1
                if (i < mod(part_num, nproc)) then
                    counts(i) = (part_num / nproc + 1) 
                else
                    counts(i) = (part_num / nproc) 
                end if
            end do
            
            displs(0) = 0

            do i = 1, nproc - 1
                displs(i) = displs(i - 1) + counts(i - 1) 
            end do
    
            call compute_forces(positions, forces, lj_potential)
            do i = displs(rank) + 1, displs(rank) + counts(rank)
                positions(i,1) = positions(i,1) + velocities(i,1)*timestep + 0.5 * forces(i,1)*timestep*timestep
                positions(i,2) = positions(i,2) + velocities(i,2)*timestep + 0.5 * forces(i,2)*timestep*timestep
                positions(i,3) = positions(i,3) + velocities(i,3)*timestep + 0.5 * forces(i,3)*timestep*timestep
                
                velocities(i,1) = velocities(i,1) + 0.5 * forces(i,1)*timestep
                velocities(i,2) = velocities(i,2) + 0.5 * forces(i,2)*timestep
                velocities(i,3) = velocities(i,3) + 0.5 * forces(i,3)*timestep
            end do

            call MPI_Barrier(MPI_COMM_WORLD, ierror)
            do i = 1, 3
                call MPI_Allgatherv(positions(displs(rank) + 1 : displs(rank) + counts(rank), i), counts(rank), MPI_REAL8, &
                                    positions(:,i), counts, displs, MPI_REAL8, MPI_COMM_WORLD, ierror)
            end do

            if (rank == 0) then
                call apply_pbc(positions)
            end if

            call compute_forces(positions, forces, lj_potential)
            velocities = velocities + 0.5 * forces*timestep

            ! The simulation works without this gathering, but it's better if all the velocities are only divided inside the subroutine.
            ! to work better in the final versions of the code.
            do i = 1, 3
                call MPI_Allgatherv(velocities(displs(rank) + 1 : displs(rank) + counts(rank), i), counts(rank), MPI_REAL8, &
                                    velocities(:, i), counts, displs, MPI_REAL8, MPI_COMM_WORLD, ierror)
            end do
        end subroutine velocity_verlet
end module integrators
