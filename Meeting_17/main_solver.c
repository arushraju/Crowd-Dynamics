//Introduction
/**
 * This is the solver of the Hughe's Pedestrian flow. And the full documentation of this code could be found at https://arushraju.github.io/Crowd-Dynamics. Now this code is the sectino that uses all the functions that are programmed to solve the benchmark problem. So see the results and the solver, working. After which the actual code will be written.
 */
#include<stdio.h>
#include<stdlib.h>
#include<string.h>
#include<math.h>

// Output Files
/**
 * These are the descriptions of each of the files : 
 * 1) Density.csv : This will contain the density at each points and this will therefore be at the very beginning of the 
 */
FILE *Density_Output = NULL;
FILE *Eikonal_Output = NULL;

//Dimension of the Domain
#define Lx 100
#define Ly 50

//Grid Points
/**
 * There are three grid points at each side of the domain. SO this means that means that each direction (x and y) there will be the 3 points in the domain, and these will be 
 */
#define Nx 106
#define Ny 56

// Space interval from the dimension and the number of grid points.
const double h = Lx / Nx;

//Important parameters in the loops.
#define inf 1000000000000
#define eta 0.000001
#define safe 0.00000000001
#define cfl 0.5
#define total_time 300

//These are the factors
double** speed;
double** discomfort;
double** cost;
double** x_velocity;
double** y_velocity;
double** rho;

// Obstacle Modelling
/**obstacle [i][j] where i will correspond to the column, and the y will correspond to the row*/
/** Obstacle will be the two dimensional array of the boolean value*/
int** obstacle;
//Function to initialse the obstacle
void makeObstacle(){
    //Initialse the obstacle
    for(int i=0; i<Nx; i++){
        for(int j=0; j<Ny; j++){
            obstacle[i][j] = 0;
        }
    }
}


//Paramaters for the crowd
const double max_speed = 2;
const double max_density = 10;
const double discomfort_factor = 0.002;

//Condition for zero density

//This will initialse the rho_zero to zero, and this variable will only be used to initialse the values of rho.

//Function to calcuate the speed from the passed rho. Takes the array of rho and returns the array pointing to speed.
void makeSpeed(){
    //Compute the spped from the greensheild's relation
    for(int i = 0; i < Nx; i++){
        for(int j = 0; j < Ny; j++){
            speed[i][j] = max_speed * (1 - (rho[i][j] / max_density));
        }
    }
}

//Function to compute the dicomfort function from the density. It takes the rho and retuns the discomfort array pointer. The function allocates the memory.
void makeDiscomfort(){
    //Compute the discomfort
    for(int i=0;i<Nx;i++){
        for(int j=0;j<Ny;j++){
            discomfort[i][j] = discomfort_factor * rho[i][j] * rho[i][j];
        }
    }
}

//Function to calculate the cost function
void makeCost(){
    //Compute the cost function
    for(int i = 0;i<Nx;i++){
        for(int j = 0;j<Ny;j++){
            cost[i][j] = (1 / speed[i][j]) + discomfort[i][j];
        }
    }
}

//This is the flux value.
struct Flux_struct{
    double flux_x;
    double flux_y;
};
typedef struct Flux_struct Flux;
//Function to make the flux values using the density and the velocity
void makeFlux(Flux** flux, double** x_velocity, double** y_velocity, double** rho){
    for(int i=0; i<Nx; i++){
        for(int j=0; j<Ny; j++){
            flux[i][j].flux_x = rho[i][j] * x_velocity[i][j];
            flux[i][j].flux_y = rho[i][j] * y_velocity[i][j];
        }
    }
    return;
}


//Graident of the values of phi.
/*For this I am going to make the gradient like this. So I will calculate the gradient variable inside the domain with the central difference and the gradient at the surface will be with the forward or backward difference apporximation.*/
void makeVelocityComp(){
    //First Calculate the phi_x and phi_y at each point
    double phi_x[Nx][Ny];
    double phi_y[Nx][Ny];
    double phi_mag[Nx][Ny];

    for(int i=0;i<Nx;i++){
        for(int j=0;j<Ny;j++){
            //If at the boundary
            if(i == 0){phi_x[0][j] = ((phi[1][j] - phi[0][j]) / h);}
            else if(i == Nx-1){phi_x[Nx-1][j] = ((phi[Nx-1][j] - phi[Nx-2][j]) / h);}
            else { phi_x[i][j] = ((phi[i+1][j] - phi[i-1][j]) / (2*h)); }

            //Similarly in the Y direction
            if(j == 0){phi_y[i][j] = ((phi[i][1] - phi[i][0]) / h);}
            else if(j == Ny-1){phi_y[i][j] = ((phi[i][Ny-1] - phi[i][Ny-2]) / h);}
            else {phi_y[i][j] = ((phi[i][j+1] - phi[i][j-1]) / (2*h));}

            //magnitude of the Phi values
            phi_mag[i][j] = pow((pow( phi_x[i][j] ,2) + pow( phi_y[i][j] ,2)) , 0.5);

            //Components of velocity
            x_velocity[i][j] = (-1) * speed[i][j] * (phi_x[i][j] / phi_mag[i][j]);
            y_velocity[i][j] = (-1) * speed[i][j] * (phi_y[i][j] / phi_mag[i][j]);
        }
    }

}

//Function to give the maximumm of veloctiy components
double maximum(double** velocity_comp){
    double max = 0;

    for(int i=0;i<Nx;i++){
        for(int j=0;j<Ny;j++){
            max = max > fabs(velocity_comp[i][j]) ? max : fabs(velocity_comp[i][j]);
        }
    }

    return max;
}

const double stop_low = -1;
const double stop_high = 11;

//------FAST SWEEP------//
//Potential
double** phi;
//First Order Fast Sweep
void firstOrderFastSweep(){
    //Lower Order Fast Sweep;
}
void WenoFastSweep(){
    //Higher Order Fast Sweep;
}
//To extraplote the phi value
void extrapolatePhi(){
    for(int j=0;j<Ny;j++){
        //Left Boundary
        phi[2][j] = phi[3][j];
        phi[1][j] = phi[2][j];
        phi[0][j] = phi[1][j];

        //Right Boundary
        phi[Nx-3][j] = phi[Nx-4][j];
        phi[Nx-2][j] = phi[Nx-3][j];
        phi[Nx-1][j] = phi[Nx-2][j];
    }

    for(int i=0;i<Nx;i++){
        //Bottom Boundary
        phi[i][2] = phi[i][3];
        phi[i][1] = phi[i][2];
        phi[i][0] = phi[i][1];

        //Top Boundary
        phi[i][Ny-3] = phi[i][Ny-4];
        phi[i][Ny-2] = phi[i][Ny-3];
        phi[i][Ny-1] = phi[i][Ny-2];
    }
}


//This is the main solver
void main_solver(double** initial_density, int** obstacle){
    double t = 0;
    int step = 0;
    double dt;

    //Pre-Allocationg the memory
    double** rho_n = (double*)malloc(sizeof(double*)*Nx);
    double** rho_1 = (double*)malloc(sizeof(double*)*Nx);
    double** rho_2 = (double*)malloc(sizeof(double*)*Nx);
    double** rho_next = (double*)malloc(sizeof(double*)*Nx);
    for(int i=0;i<Nx;i++){
        rho_n[i] = (double*)calloc(sizeof(double),Ny);
        rho_1[i] = (double*)calloc(sizeof(double),Ny);
        rho_2[i] = (double*)calloc(sizeof(double),Ny);
        rho_next[i] = (double*)calloc(sizeof(double*),Ny);
    }

    //This will be the rho that will be advected.
    rho = initial_density;
    
    //The main solver
    while(t < total_time){

        //1. Computing cost for the density at time t
        makeSpeed(); //Make the speed
        makeDiscomfort(); //Make the discomfort
        makeCost();//Make the cost

        //2. Computing the initial guess of the potential using first order fast sweep
        firstOrderFastSweep();
        //Higher Order Potential Field
        WenoFastSweep();

        //Function to extrapolate the phi value
        extrapolatePhi();

        //This will calculate the graident of the phi values and will fill the velocity
        makeVelocityComp();

        //Update the Time step
        int u_max = maximum(x_velocity);
        int v_max = maximum(y_velocity);
        dt = ( cfl * h ) / ( u_max + v_max +  safe);

        //Make Rho_n
        rho_n = rho;
    }
}

int main(){
    
}

