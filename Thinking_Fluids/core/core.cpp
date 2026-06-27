/**
 * @file core.c
 * @brief Main solver for the Hughes crowd flow model.
 * @author Arush Chinchkhede
 * @date 2026-06-20
 * @version 0.1.0
 */

#include<stdio.h>
#include<stdlib.h>
#include<math.h>
#include<string.h>

//This for colors
#define RED    "\033[31m"
#define GREEN  "\033[32m"
#define YELLOW "\033[33m"
#define BLUE   "\033[34m"
#define RESET  "\033[0m"
#define CLEAR "\033[2J\033[H"
#define BOLD "\033[1m"
#define UNDERLINE "\033[4m"

//This is one of the convention that the value of the density inside the obstacle will be equal to -1.

//Important Variables
double** density;       // Density Matrix
double** speed;         // Speed Matrix      
double** discomfort;    // Discomfort Matrix
double** cost;          // Cost Matrix
double** potential;     // Potential Matrix
double** x_component;   // X Component Matrix
double** y_component;   // Y Component Matrix


/**
 * |------------------------|
 * | SPEED-DENSITY RELATION |
 * |------------------------|
 * 
*/
/* GREENSHEILD'S RELATION */
double Vmax;    //Maximum Velocity
double rho_max; //Maximum Density
// This is the flag for the Greensheield's Relation
void greenshield(int Nx, int Ny){
    for(int i = 0;i<Nx;i++){
        for(int j = 0;j<Ny;j++){
            speed[i][j] = Vmax * (1 - ( density[i][j] / rho_max ));
        }
    }
}

/* GREENBERG'S RELATION */
void greenberg(int Nx, int Ny){
    return;
}

/* UNDERWOOD'S RELATION */
void underwood(int Nx, int Ny){
    return;
}

/* PIPE'S RELATION */
void pipe(int Nx, int Ny){
    return;
}

/* DRAKE'S RELATION */
void drake(int Nx, int Ny){
    return;
}

/**
 * |---------------------|
 * | DISCOMFORT RELATION |
 * |---------------------|
 * 
*/
//This is my function to calculate the discomfort
void my_discomfort_model(int Nx, int Ny){
    for(int i = 0;i<Nx;i++){
        for(int j = 0;j<Ny;j++){
            discomfort[i][j] = 0.002 * pow(density[i][j],2);
        }
    }
    return;
}
/**
 * |---------------------|
 * |    COST FUNCTION    |
 * |---------------------|
 * 
*/
//Function to calculate the cost
void my_cost(int Nx, int Ny){
    for(int i = 0;i<Nx;i++){
        for(int j = 0;j<Ny;j++){
            cost[i][j] = ( 1 / speed[i][j] ) + discomfort[i][j];
        }
    }
    return;
}

/**
 * |---------------------|
 * |   TEST CASE SOLVER  |
 * |---------------------|
 * 
*/
/**
 * @brief Main Solver for solving the test case.
 * @param right Right Boundary Flux Values
 * @param left Left Boundary Flux Values,
 * @param top Top Boundary Values
 * @param bottom Bottom Boundary Values
 * @param speed_density_relation Function that will be passed to select the relation between Velocity and Density
 * 
 * @return - Updates the file containing the density evolution (CSV File).Later the function could be made to print the output for backend.
*/
void test_case_solver(double* right, double* top, double* left, double* bottom, void (*speed_density_relation)(int, int), void (*discomfort_relation)(int, int)){
    const double CFL = 0.5;
    const double Lx = 100;
    const double Ly = 100;
    const double Nx = 100;
    const double Ny = 100;

    // Make the Density

    //Defining the Space Interval
    const double h = Lx/Nx;

    const double total_time = 15;
    double time = 0;
    double dt;

    //Start only when user press y
    char start = 'n';
    while(start != 'y'){
        printf(RED "\nStart Computation? (y) : ");
        scanf("%c",&start);
    }
    printf("\n");
    while (time < total_time){
        // Print the time of computation
        printf("Time Step : %lf\n",time);

        // Calculate the Cost from the speed and discomfort
        speed_density_relation(Nx,Ny);  // To calculate the speed
        discomfort_relation(Nx,Ny);     // To calculate the discomfort


        // Then solve the eikonal equation using the cost and the boundary condition of the outflow and inflow and obstacle.

        // And then compute the components of the velocity using the potential and the speed value.

        // Calculate the time interval
        dt = 1;

        // And then solve the density at the next time step using the components of velocity and density in current time step.

        // Update the files and time step
        time = time + dt;
    }

}

//Prints the Headign of the software
void print_head(){
    printf(CLEAR);
    printf(BOLD UNDERLINE YELLOW "\tTHINKING FLUIDS\n\n" RESET);
    printf("|-----------------------------------|\n");
    printf("| Version    | 0.1.0                |\n");
    printf("| Developer  | https://hi-arush.com |\n");
    printf("| Build Date | 22-06-2026           |\n");
    printf("| Software   | Hughes Flow Solver   |\n");
    printf("|-----------------------------------|\n");
}
//Prints the introduction of the software
void print_intro(){
    printf(RED "\n\nINSTRUCTION\033[0m\n\n" RESET);
    printf(GREEN "\nWelcome to the software. Given below are the " BOLD UNDERLINE "instructions" RESET GREEN " to use the software. Before using the software it is useful to have the knowledge about the Crowd-Dynamics and Hughe's Model to be able to use the software smoothly. For more information you can vist the website " UNDERLINE BOLD "https://arushraju.github.io/Crowd-Dynamics/" RESET GREEN " to understand about my work\n\n");
    printf("The input to the software will be put in the form of different steps. And tye are listed below.\n\n");
    printf("1.\tSpeed-Density Relation\n");
    printf("2.\tProblem Type\n");
    printf("3.\tSimulation Parameters\n");
    printf("4.\tSomething Else\n");
    
    printf("\n");

    char temp = 'n';

    while (temp != 'y') {
        printf("Continue ? (y): ");
        scanf(" %c", &temp);
    }
}
//Prints the instructions to the type of problem
void print_problem(){
    printf(RED "\n\nTYPE OF PROBLEM\tSelect the Problem\n\n");
    printf(GREEN "Test Problem\t\t0\nStandard Problem\t1\n");
    printf("\nEnter the Problem : ");
    return;
}
//Prints the option to select the spped and density relation
void print_speed_density(){
    printf(RED "\n\nSPEED - DENSITY RELATION\tSelect the Model\n\n");
    printf(GREEN "Greensheild's relation\t\t0\nGreenberg's Relation\t\t1\nUnderwood Relation\t\t2\nPipe's Relation\t\t\t3\nDrake's Relation\t\t4\n");
    printf("\nEnter the Model : ");
    return;
}

// Main Function
int main(){

    printf(CLEAR);

    /* INSTRUCTION */
    print_head();
    print_intro();

    /* SPEED AND DENSITY RELATION */
    print_head();
    print_speed_density();

    int model;
    char* model_expression = (char*)malloc(200);
    scanf("%d",&model);

    /* TYPE OF PROBLEM */
    print_head();
    print_problem();
 
    int problem;
    scanf("%d",&problem);

    /* SOLVE PROBLEM */
    print_head();
    printf("\n\n" RED BOLD "SUMMARY OF SOLVER\n\n" RESET);
    //print the model used for speed and density and also assign the appropriate speed density function
    void (*speed_relation)(int ,int); //This is the pointer to the function depending on the model selected
    void (*discomfort_relation)(int, int);//This points to the discomfort function
    printf(GREEN "Speed-Density Model : \t" RESET);
    switch (model)
    {
        case 0:
            printf(YELLOW "GREENSHEILD'S RELATION\n\n" RESET);
            speed_relation = greenshield;
            printf(GREEN "Free Crowd Velocity (Velocity of crowd at zero density) : ");
            scanf("%lf",&Vmax);
            printf("Jam Density (Density at which crowd cannot move) : ");
            scanf("%lf",&rho_max);

            //Express the Model in Equation
            sprintf(model_expression,"speed = %lf * (1 - (density / %lf))",Vmax,rho_max);
            break;
        case 1:
            printf(YELLOW "GREENBERG'S RELATION\n" RESET);
            speed_relation = greenberg;
            break;
        case 2:
            printf(YELLOW "UNDERWOOD'S RELATION\n" RESET);
            speed_relation = underwood;
            break;
        case 3:
            printf(YELLOW "PIPE'S RELATION\n" RESET);
            speed_relation = pipe;
            break;
        case 4:
            printf(YELLOW "DRAKE'S RELATION\n" RESET);
            speed_relation = drake;
            break;
        default:
            break;
    }
    //Print the Expression of Model
    printf(RED "\nModel Expression : %s\n\n" RESET,model_expression);

    discomfort_relation = my_discomfort_model;

    //Print the type of problem needs to be solved
    printf(GREEN "Problem Type : \t\t" RESET);
    switch (problem)
    {
        case 0:
            printf(YELLOW "TEST CASE\n" RESET);

            //Test Case
            double* right_boundary;
            double* top_boundary;
            double* left_boundary;
            double* bottom_boundary;

            right_boundary = (double*)calloc(100,sizeof(double));
            top_boundary = (double*)calloc(100,sizeof(double));
            bottom_boundary = (double*)calloc(100,sizeof(double));
            left_boundary = (double*)calloc(100,sizeof(double));
            for(int i = 0;i<100;i++){left_boundary[i] = 2;}

            

            //Solve the Problem
            test_case_solver(right_boundary,top_boundary,left_boundary,bottom_boundary,speed_relation,discomfort_relation);

            break;
        case 1:
            printf(YELLOW "STANDARD PROBLEM\n" RESET);
            break;
    }

    printf(RED BOLD "\nSucessfully Executed\n" RESET);

    return 0;

}