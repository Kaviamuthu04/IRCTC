#include <stdio.h>
#include "reservation.h"
#include "memory_stress.h"
int main(void){
    printf("IRCTC Tatkal Booking Memory Stress PoC");
    run_memory_stress_test();
    run_reservation_test();
    return 0;
    
}
