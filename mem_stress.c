#include <stdio.h>
#include <stdlib.h>
#include "memory_stress.h"
void run_memory_stress_test(void){
    const size_t block=1024*1024;
    void* ptrs[32]={0};
    for(int i=0;i<32;i++){
        ptrs[i]=malloc(block);
        if(ptrs[i]==NULL){
            printf("Allocation failed at %d",i);
            break;
        }
    }
    for(int i=0;i<32;i++){
    free(ptrs[i]);
    }
    printf("Memory stress completed");
}
