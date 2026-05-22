#include<math.h>
#include<stdio.h>

void swap(int*a,int*b){
    int temp;

    temp = a;
    a = b;
    b = temp;

    return;
}

int main(){

    int a = 2;
    int b = 3;

    swap(a,b);


    printf("a : %d | b : %d",a,b);
    
    return 0;
}